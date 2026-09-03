import Foundation
import Combine

// MARK: - Models
enum ShiftType: String, Codable, CaseIterable {
    case regular      = "Regular"
    case overtime     = "Overtime"
    case holiday      = "Holiday"
    case vacation     = "Vacation"
    case sick         = "Sick"
    case formation    = "Formation"
    case companyFunDay = "Company Fun Day"

    var label: String { rawValue }

    var multiplier: Double {
        switch self {
        case .regular, .vacation, .sick, .formation, .companyFunDay: return 1.0
        case .overtime: return AppSettings.shared.overtimeMultiplier
        case .holiday:  return 2.0
        }
    }

    var isVacation: Bool { self == .vacation }
    var isDayType: Bool  { self == .vacation || self == .sick || self == .formation || self == .holiday || self == .companyFunDay }

    // Label shown in activity row title (overrides the date for named shift types)
    var activityTitle: String? {
        switch self {
        case .vacation:      return "Vacation Day"
        case .sick:          return "Sick Day"
        case .formation:     return "Formation Day"
        case .companyFunDay: return "Company Fun Day"
        case .overtime:      return "Overtime"
        case .holiday:       return "Holiday"
        default:             return nil
        }
    }
}

struct ShiftEntry: Codable, Identifiable {
    var id: UUID
    var shiftType: ShiftType
    var startedAt: Date
    var durationMinutes: Int
    var unpaidBreakMinutes: Int

    init(id: UUID = UUID(), shiftType: ShiftType, startedAt: Date, durationMinutes: Int, unpaidBreakMinutes: Int) {
        self.id = id
        self.shiftType = shiftType
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
        self.unpaidBreakMinutes = unpaidBreakMinutes
    }

    // Always computed from current settings so rate changes apply instantly
    var estimatedPay: Double {
        let settings = AppSettings.shared
        if shiftType.isDayType {
            let minsPerDay = settings.workDayHours * 60
            let days = max(1, Int(round(Double(durationMinutes) / minsPerDay)))
            return Double(days) * settings.dailyRate * shiftType.multiplier
        }
        let workMins = max(0, durationMinutes - unpaidBreakMinutes)
        return (Double(workMins) / 60.0) * settings.effectiveHourlyRate * shiftType.multiplier
    }
}

// MARK: - Store
class ShiftStore: ObservableObject {
    static let shared = ShiftStore()

    @Published var entries: [ShiftEntry] = []
    @Published var activeShiftStart: Date? = nil

    private let entriesKey = "ss_shift_entries_v1"
    private let activeKey  = "ss_active_shift_start"

    init() {
        loadEntries()
        loadActive()
    }

    // MARK: Persistence
    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([ShiftEntry].self, from: data) else { return }
        entries = decoded
    }

    private func loadActive() {
        guard let ts = UserDefaults.standard.object(forKey: activeKey) as? Double else { return }
        activeShiftStart = Date(timeIntervalSince1970: ts)
    }

    func saveEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: entriesKey)
    }

    // MARK: Clock In / Out
    func clockIn() {
        let now = Date()
        activeShiftStart = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: activeKey)
        WatchSessionManager.shared.sendStateUpdate()
        // Cancel "didn't make it to work?" alert — user is clearly working today
        LocationManager.shared.cancelDailyAbsenceCheck()
    }

    func clockOut() {
        guard let start = activeShiftStart else { return }
        let mins = max(1, Int(Date().timeIntervalSince(start) / 60))
        let settings = AppSettings.shared

        if settings.overtimeEnabled {
            let thresholdMins = Int(settings.dailyOvertimeHours * 60)
            if mins > thresholdMins {
                let regularEntry = ShiftEntry(shiftType: .regular, startedAt: start,
                                             durationMinutes: thresholdMins, unpaidBreakMinutes: 0)
                let otStart = start.addingTimeInterval(Double(thresholdMins) * 60)
                let otEntry  = ShiftEntry(shiftType: .overtime, startedAt: otStart,
                                         durationMinutes: mins - thresholdMins, unpaidBreakMinutes: 0)
                entries.append(contentsOf: [regularEntry, otEntry])
                saveEntries()
                activeShiftStart = nil
                UserDefaults.standard.removeObject(forKey: activeKey)
                WatchSessionManager.shared.sendStateUpdate()
                LocationManager.shared.rescheduleDailyAbsenceCheckFromTomorrow()
                return
            }
        }

        let entry = ShiftEntry(shiftType: .regular, startedAt: start,
                               durationMinutes: mins, unpaidBreakMinutes: 0)
        entries.append(entry)
        saveEntries()
        activeShiftStart = nil
        UserDefaults.standard.removeObject(forKey: activeKey)
        WatchSessionManager.shared.sendStateUpdate()
        LocationManager.shared.rescheduleDailyAbsenceCheckFromTomorrow()
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        saveEntries()
    }

    func updateEntry(_ updated: ShiftEntry) {
        if let idx = entries.firstIndex(where: { $0.id == updated.id }) {
            entries[idx] = updated
            saveEntries()
        }
    }

    func clearAll() {
        entries = []
        activeShiftStart = nil
        UserDefaults.standard.removeObject(forKey: entriesKey)
        UserDefaults.standard.removeObject(forKey: activeKey)
    }

    // MARK: Manual Entry
    func addEntry(_ entry: ShiftEntry) {
        entries.append(entry)
        saveEntries()
    }

    // MARK: Queries
    func entriesForDay(_ date: Date) -> [ShiftEntry] {
        entries.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: date) }
    }

    func hasShifts(on date: Date) -> Bool {
        entries.contains { Calendar.current.isDate($0.startedAt, inSameDayAs: date) }
    }

    var weeklyMinutes: Int {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())),
              let end   = cal.date(byAdding: .day, value: 7, to: start) else { return 0 }
        return entries
            .filter { !$0.shiftType.isDayType && $0.startedAt >= start && $0.startedAt < end }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    var monthlyMinutes: Int {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: Date())),
              let end   = cal.date(byAdding: .month, value: 1, to: start) else { return 0 }
        return entries
            .filter { !$0.shiftType.isDayType && $0.startedAt >= start && $0.startedAt < end }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    var weeklyEarnings: Double {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())),
              let end   = cal.date(byAdding: .day, value: 7, to: start) else { return 0 }
        return entries.filter { $0.startedAt >= start && $0.startedAt < end }
                      .reduce(0) { $0 + $1.estimatedPay }
    }

    // Vacation days used this calendar year
    var vacationDaysUsed: Int {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        guard let startOfYear = cal.date(from: DateComponents(year: year)),
              let endOfYear   = cal.date(byAdding: .year, value: 1, to: startOfYear) else { return 0 }
        return entries
            .filter { $0.shiftType == .vacation && $0.startedAt >= startOfYear && $0.startedAt < endOfYear }
            .reduce(0) { $0 + max(1, Int(round(Double($1.durationMinutes) / (AppSettings.shared.workDayHours * 60)))) }
    }
}
