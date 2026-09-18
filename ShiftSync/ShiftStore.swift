import Foundation
import Combine
import UserNotifications

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
    // When set, locks this entry's pay to a fixed amount instead of recomputing live from
    // current settings — used when the user chooses to apply a new Overtime Rules change
    // only to future shifts, so past entries keep the pay they had at that time.
    var payOverride: Double?

    init(id: UUID = UUID(), shiftType: ShiftType, startedAt: Date, durationMinutes: Int, unpaidBreakMinutes: Int, payOverride: Double? = nil) {
        self.id = id
        self.shiftType = shiftType
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
        self.unpaidBreakMinutes = unpaidBreakMinutes
        self.payOverride = payOverride
    }

    // Number of days a day-type entry (vacation/sick/etc.) represents. Normally 1, since
    // shifts are created one entry per day, but EditShiftView can bundle multiple days'
    // worth of duration into a single entry via its day-count stepper.
    var dayCount: Int {
        guard shiftType.isDayType else { return 0 }
        let minsPerDay = AppSettings.shared.workDayHours * 60
        return max(1, Int(round(Double(durationMinutes) / minsPerDay)))
    }

    // Computed live from current settings so rate changes apply instantly — unless
    // payOverride locks it to a fixed amount (see payOverride's doc comment above).
    var estimatedPay: Double {
        if let payOverride { return payOverride }
        let settings = AppSettings.shared
        if shiftType.isDayType {
            return Double(dayCount) * settings.dailyRate * shiftType.multiplier
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

    // MARK: Backup / Restore

    private struct Backup: Codable {
        var entries: [ShiftEntry]
        var activeShiftStart: Date?
    }

    /// Encodes all shift entries (and any in-progress shift) as JSON, so users can
    /// back up or transfer their records when switching devices without relying on
    /// a full system backup.
    func exportBackupData() -> Data? {
        try? JSONEncoder().encode(Backup(entries: entries, activeShiftStart: activeShiftStart))
    }

    /// Decodes a backup file just enough to report its shift count, without applying it —
    /// lets the UI confirm before overwriting current data.
    func peekBackupEntryCount(_ data: Data) -> Int? {
        try? JSONDecoder().decode(Backup.self, from: data).entries.count
    }

    @discardableResult
    func importBackupData(_ data: Data) -> Bool {
        guard let backup = try? JSONDecoder().decode(Backup.self, from: data) else { return false }
        entries = backup.entries
        activeShiftStart = backup.activeShiftStart
        saveEntries()
        if let start = backup.activeShiftStart {
            UserDefaults.standard.set(start.timeIntervalSince1970, forKey: activeKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeKey)
        }
        WatchSessionManager.shared.sendStateUpdate()
        return true
    }

    // MARK: Clock In / Out
    func clockIn() {
        let now = Date()
        activeShiftStart = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: activeKey)
        WatchSessionManager.shared.sendStateUpdate()
        // Mark today as worked and cancel "didn't make it to work?" alerts — a manual
        // clock-in is just as valid a signal as a geofence arrival that they're at work.
        LocationManager.shared.markWorkedToday()
        LocationManager.shared.cancelDailyAbsenceCheck()
        LocationManager.shared.scheduleWorkFromHomeReminders()
        fireClockNotification(title: "Clocked In ✓", body: "Your shift has started.")
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
                LocationManager.shared.markWorkedToday()
                LocationManager.shared.scheduleDailyAbsenceCheck()
                LocationManager.shared.scheduleWorkFromHomeReminders()
                fireClockNotification(title: "Clocked Out ✓", body: "Your shift has ended. Nice work!")
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
        LocationManager.shared.markWorkedToday()
        LocationManager.shared.scheduleDailyAbsenceCheck()
        LocationManager.shared.scheduleWorkFromHomeReminders()
        fireClockNotification(title: "Clocked Out ✓", body: "Your shift has ended. Nice work!")
    }

    // MARK: Overtime Rules Change

    /// Locks every existing entry's pay to its current computed value, so a later change to
    /// Overtime Rules (multiplier, threshold, or the toggle itself) only affects shifts logged
    /// from this point forward. Called when the user picks "Only Future Shifts" in the
    /// Overtime Rules apply-change prompt.
    func freezePayForExistingEntries() {
        for i in entries.indices where entries[i].payOverride == nil {
            entries[i].payOverride = entries[i].estimatedPay
        }
        saveEntries()
    }

    /// Re-derives the regular/overtime split for every existing plain "Regular" entry using
    /// the *current* Overtime Rules settings, and clears any previous pay lock so all entries
    /// resume live-computing pay from current settings. Called when the user picks "Apply to
    /// All Shifts" in the Overtime Rules apply-change prompt. Mirrors the same split clockOut()
    /// performs on a live shift, just applied retroactively to already-logged entries.
    func reapplyOvertimeRulesToExistingEntries() {
        let settings = AppSettings.shared
        let thresholdMins = Int(settings.dailyOvertimeHours * 60)
        var result: [ShiftEntry] = []
        for entry in entries {
            var e = entry
            e.payOverride = nil
            guard settings.overtimeEnabled, e.shiftType == .regular, e.durationMinutes > thresholdMins else {
                result.append(e)
                continue
            }
            let regularEntry = ShiftEntry(shiftType: .regular, startedAt: e.startedAt,
                                          durationMinutes: thresholdMins, unpaidBreakMinutes: 0)
            let otStart = e.startedAt.addingTimeInterval(Double(thresholdMins) * 60)
            let otEntry = ShiftEntry(shiftType: .overtime, startedAt: otStart,
                                     durationMinutes: e.durationMinutes - thresholdMins, unpaidBreakMinutes: 0)
            result.append(regularEntry)
            result.append(otEntry)
        }
        entries = result
        saveEntries()
    }

    // MARK: Notifications

    /// Fires a local notification confirming the clock in/out action. iOS mirrors this
    /// to a paired Apple Watch automatically — no Watch app installation required.
    private func fireClockNotification(title: String, body: String) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body  = body
            content.sound = .default
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "ss_clock_\(Int(Date().timeIntervalSince1970))",
                                      content: content, trigger: nil)
            )
        }
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
            .reduce(0) { $0 + $1.dayCount }
    }
}
