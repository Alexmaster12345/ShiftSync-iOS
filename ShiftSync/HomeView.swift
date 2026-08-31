import SwiftUI
import Combine

struct HomeView: View {
    let userName: String
    @ObservedObject var store: ShiftStore

    @State private var now = Date()
    @State private var showManualEntry = false
    @State private var showVacationEntry = false
    @State private var dayOffShiftType: ShiftType = .vacation
    @State private var showNotifications = false
    @State private var entryToEdit: ShiftEntry? = nil
    @State private var entryToDelete: ShiftEntry? = nil
    @State private var actionEntry: ShiftEntry? = nil
    @ObservedObject private var alertLog = AlertLog.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var locationManager = LocationManager.shared

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Computed

    private var isClocked: Bool { store.activeShiftStart != nil }

    private var elapsedSeconds: Int {
        guard let start = store.activeShiftStart else { return 0 }
        return max(0, Int(now.timeIntervalSince(start)))
    }

    private var startTimeLabel: String {
        guard let start = store.activeShiftStart else { return "--:--" }
        let fmt = DateFormatter()
        fmt.dateFormat = "hh:mm a"
        return fmt.string(from: start)
    }

    private var activeEarnings: Double {
        guard store.activeShiftStart != nil else { return 0 }
        return Double(elapsedSeconds) / 3600.0 * settings.effectiveHourlyRate
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var monthlyShiftCount: Int {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        guard let start = cal.date(from: comps),
              let end   = cal.date(byAdding: .month, value: 1, to: start) else { return 0 }
        return store.entries.filter { $0.startedAt >= start && $0.startedAt < end }.count
    }

    private var previousWeekMinutes: Int {
        let cal = Calendar.current
        guard let thisStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())),
              let prevStart = cal.date(byAdding: .weekOfYear, value: -1, to: thisStart) else { return 0 }
        return store.entries
            .filter { !$0.shiftType.isDayType && $0.startedAt >= prevStart && $0.startedAt < thisStart }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    private var weekComparison: (text: String, isPositive: Bool) {
        let diff = store.weeklyMinutes - previousWeekMinutes
        let h = String(format: "%.1f", Double(abs(diff)) / 60.0)
        if diff > 0 { return ("↑ \(h)h more than last week", true) }
        if diff < 0 { return ("↓ \(h)h less than last week", false) }
        return ("Same as last week", true)
    }

    // MARK: - Body

    private var bottomScrollPadding: CGFloat {
        let safeBottom = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first?.safeAreaInsets.bottom ?? 0
        return 82 + safeBottom
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar.padding(.top, 12)
                Spacer().frame(height: 20)
                activeShiftCard
                Spacer().frame(height: 14)
                statsRow
                Spacer().frame(height: 20)
                recentActivitySection
                Spacer().frame(height: bottomScrollPadding)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .onReceive(ticker) { now = $0 }
        .alert(
            locationManager.pendingClockAction == .clockIn ? "You've arrived at work!" : "You've left work!",
            isPresented: Binding(
                get: { locationManager.pendingClockAction == .clockIn || locationManager.pendingClockAction == .clockOut },
                set: { if !$0 { locationManager.pendingClockAction = nil } }
            )
        ) {
            Button(locationManager.pendingClockAction == .clockIn ? "Clock In" : "Clock Out") {
                if locationManager.pendingClockAction == .clockIn { store.clockIn() }
                else { store.clockOut() }
                locationManager.pendingClockAction = nil
            }
            Button("Not Now", role: .cancel) { locationManager.pendingClockAction = nil }
        } message: {
            Text(locationManager.pendingClockAction == .clockIn
                 ? "Do you want to clock in now?"
                 : "Do you want to clock out now?")
        }
        .alert("Didn't make it to work today?",
            isPresented: Binding(
                get: { locationManager.pendingClockAction == .logDayOff },
                set: { if !$0 { locationManager.pendingClockAction = nil } }
            )
        ) {
            Button("Sick Day") {
                dayOffShiftType = .sick
                locationManager.pendingClockAction = nil
                showVacationEntry = true
            }
            Button("Vacation Day") {
                dayOffShiftType = .vacation
                locationManager.pendingClockAction = nil
                showVacationEntry = true
            }
            Button("Formation Day") {
                dayOffShiftType = .formation
                locationManager.pendingClockAction = nil
                showVacationEntry = true
            }
            Button("Not Now", role: .cancel) { locationManager.pendingClockAction = nil }
        } message: {
            Text("Log today's absence so your records stay up to date.")
        }
        .sheet(isPresented: $showManualEntry) {
            ManualEntryView(store: store, isPresented: $showManualEntry)
        }
        .sheet(isPresented: $showVacationEntry) {
            ManualEntryView(store: store, isPresented: $showVacationEntry, initialShiftType: dayOffShiftType)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView(isPresented: $showNotifications)
        }
        .sheet(item: $entryToEdit) { entry in
            EditShiftView(entry: entry, store: store, isPresented: Binding(
                get: { entryToEdit != nil },
                set: { if !$0 { entryToEdit = nil } }
            ))
        }
        .confirmationDialog("Delete Shift?", isPresented: Binding(
            get: { entryToDelete != nil }, set: { if !$0 { entryToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let e = entryToDelete { store.deleteEntry(id: e.id) }
                entryToDelete = nil
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        } message: {
            Text("This shift will be permanently removed.")
        }
        .confirmationDialog(actionEntry.map { shiftOptionsTitle(for: $0) } ?? "Shift Options", isPresented: Binding(
            get: { actionEntry != nil }, set: { if !$0 { actionEntry = nil } }
        ), titleVisibility: .visible) {
            Button("Edit Shift") { entryToEdit = actionEntry; actionEntry = nil }
            Button("Delete Shift", role: .destructive) { entryToDelete = actionEntry; actionEntry = nil }
            Button("Add New Hours") { actionEntry = nil; showManualEntry = true }
            Button("Cancel", role: .cancel) { actionEntry = nil }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("ShiftSync")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.ssTextPrimary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text("\(greeting), \(userName)")
                    .font(.system(size: 14))
                    .foregroundColor(.ssTextSecondary)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 10) {
                Button(action: { showNotifications = true }) {
                    ZStack(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.darkCard)
                            .frame(width: 40, height: 40)
                            .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
                            .overlay(
                                Image(systemName: alertLog.unreadCount > 0 ? "bell.badge.fill" : "bell")
                                    .font(.system(size: 16))
                                    .foregroundColor(.ssTextPrimary)
                            )
                        if alertLog.unreadCount > 0 {
                            Circle().fill(Color.redAccent).frame(width: 10, height: 10)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .buttonStyle(.plain)

                Circle()
                    .fill(LinearGradient(colors: [.shiftBlue, .shiftBlueDark],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 40, height: 40)
                    .shadow(color: Color.shiftBlue.opacity(0.25), radius: 4, y: 2)
                    .overlay(
                        Text(String(userName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    )
            }
        }
    }

    // MARK: - Active Shift Card

    private var activeShiftCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("ACTIVE SHIFT")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.72))
                    .kerning(1.5)
                Spacer()
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "stopwatch.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            Spacer().frame(height: 6)

            Text(isClocked ? formatElapsedHMS(elapsedSeconds) : "00:00:00")
                .font(.system(size: 28, weight: .black, design: .monospaced))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .foregroundColor(.white)
                .padding(.horizontal, 16)

            Spacer().frame(height: 10)

            HStack(spacing: 10) {
                infoBox(label: "Started at", value: isClocked ? startTimeLabel : "--:--")
                infoBox(label: "Estimated Pay",
                        value: isClocked ? formatCurrency(activeEarnings) : formatCurrency(0))
            }
            .padding(.horizontal, 16)

            Spacer().frame(height: 10)

            Button(action: { isClocked ? store.clockOut() : store.clockIn() }) {
                Text(isClocked ? "Clock Out" : "Clock In")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.shiftBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

        }
        .background(
            LinearGradient(
                colors: [Color.shiftBlue, Color.shiftBlueDark],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.shiftBlue.opacity(0.4), radius: 16, x: 0, y: 8)
    }

    private func infoBox(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.68))
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 12) {
            weekStatCard
            monthStatCard
        }
    }

    private var weekStatCard: some View {
        let cmp = weekComparison
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.greenAccent.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.greenAccent)
                }
                Text("This Week")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.ssTextSecondary)
            }
            Text(store.weeklyMinutes > 0 ? formatDuration(store.weeklyMinutes) : "0h")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(.ssTextPrimary)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(cmp.text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(cmp.isPositive ? .greenAccent : .redAccent)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
    }

    private var monthStatCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.shiftBlue.opacity(0.12))
                        .frame(width: 30, height: 30)
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 13))
                        .foregroundColor(.shiftBlue)
                }
                Text("This Month")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.ssTextSecondary)
            }
            Text(store.monthlyMinutes > 0 ? formatDuration(store.monthlyMinutes) : "0h")
                .font(.system(size: 16, weight: .black))
                .foregroundColor(.ssTextPrimary)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text("\(monthlyShiftCount) shifts total")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.ssTextMuted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
    }

    // MARK: - Recent Activity

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECENT ACTIVITY")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.ssTextSecondary)
                    .kerning(1)
                Spacer()
                Button("View All") { showManualEntry = true }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.shiftBlue)
            }

            let cal = Calendar.current
            let recent = Array(store.entries.sorted { a, b in
                // Vacation entries sort at 23:59:59 of their day so they appear above
                // same-day regular entries (which have midnight startedAt) in the list
                let aDate = a.shiftType.isDayType
                    ? cal.startOfDay(for: a.startedAt).addingTimeInterval(86399)
                    : a.startedAt
                let bDate = b.shiftType.isDayType
                    ? cal.startOfDay(for: b.startedAt).addingTimeInterval(86399)
                    : b.startedAt
                return aDate > bDate
            }.prefix(10))

            if recent.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.questionmark")
                        .font(.system(size: 34))
                        .foregroundColor(.ssTextMuted)
                    Text("No shifts logged yet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.ssTextMuted)
                    Button("Log your first shift") { showManualEntry = true }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.shiftBlue)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 8) {
                    ForEach(recent) { entry in
                        recentRow(entry)
                    }
                }
            }
        }
    }

    private func recentRow(_ entry: ShiftEntry) -> some View {
        let timeFmt  = DateFormatter()
        timeFmt.dateFormat = "hh:mm a"
        let endDate  = entry.startedAt.addingTimeInterval(Double(entry.durationMinutes) * 60)
        let isOT     = entry.shiftType == .overtime
        let accent   = dayAccent(for: entry.shiftType)
        let titleTxt = entry.shiftType.activityTitle ?? relativeDate(for: entry.startedAt)
        let infoTxt  = entry.shiftType.isDayType
            ? daySubtitle(for: entry.shiftType)
            : "\(timeFmt.string(from: entry.startedAt)) – \(timeFmt.string(from: endDate))"

        // Compute duration label and pay using observed settings so the row
        // re-renders immediately when workDayHours or rate changes.
        let durationTxt: String
        let pay: Double
        if entry.shiftType.isDayType {
            let minsPerDay = settings.workDayHours * 60
            let days = max(1, Int(round(Double(entry.durationMinutes) / minsPerDay)))
            let totalH = settings.workDayHours * Double(days)
            durationTxt = totalH == totalH.rounded() ? "\(Int(totalH))h" : String(format: "%.1fh", totalH)
            pay = Double(days) * settings.dailyRate * entry.shiftType.multiplier
        } else {
            durationTxt = formatDuration(entry.durationMinutes)
            let workMins = max(0, entry.durationMinutes - entry.unpaidBreakMinutes)
            pay = (Double(workMins) / 60.0) * settings.effectiveHourlyRate * entry.shiftType.multiplier
        }

        return HStack(spacing: 10) {
            // Icon — compact circle
            ZStack {
                Circle().fill(accent.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: shiftIcon(for: entry))
                    .font(.system(size: 14))
                    .foregroundColor(accent)
            }

            // Title · time on the same line
            HStack(spacing: 4) {
                Text(titleTxt)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.ssTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("·")
                    .font(.system(size: 12))
                    .foregroundColor(.ssTextMuted)
                Text(infoTxt)
                    .font(.system(size: 12))
                    .foregroundColor(.ssTextSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 4)

            // Duration + overtime badge + pay
            VStack(alignment: .trailing, spacing: 2) {
                Text(durationTxt)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.ssTextPrimary)
                if isOT {
                    Text(String(format: "%.2g×", settings.overtimeMultiplier))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orangeAccent)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.orangeAccent.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text(formatCurrency(pay))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isOT ? .orangeAccent : (entry.shiftType.isDayType ? accent : .greenAccent))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { actionEntry = entry }
    }

    // MARK: - Helpers

    private func dayAccent(for type: ShiftType) -> Color {
        switch type {
        case .vacation:      return .tealAccent
        case .sick:          return .redAccent
        case .formation:     return .orangeAccent
        case .overtime:      return .orangeAccent
        case .companyFunDay: return .greenAccent
        case .holiday:       return .shiftBlue
        default:             return .shiftBlue
        }
    }

    private func dayTitle(for type: ShiftType) -> String {
        switch type {
        case .vacation:      return "Vacation Day"
        case .sick:          return "Sick Day"
        case .formation:     return "Formation Day"
        case .companyFunDay: return "Company Fun Day"
        default:             return type.label
        }
    }

    private func daySubtitle(for type: ShiftType) -> String {
        switch type {
        case .vacation:      return "Paid Time Off"
        case .sick:          return "Medical Leave"
        case .formation:     return "Professional Development"
        case .companyFunDay: return "Company Event"
        case .holiday:       return "Public Holiday · 2×"
        default:             return ""
        }
    }

    private func shiftIcon(for entry: ShiftEntry) -> String {
        switch entry.shiftType {
        case .vacation:      return "sun.max.fill"
        case .sick:          return "cross.fill"
        case .formation:     return "graduationcap.fill"
        case .overtime:      return "bolt.fill"
        case .companyFunDay: return "party.popper.fill"
        case .holiday:       return "star.fill"
        default: break
        }
        let h = Calendar.current.component(.hour, from: entry.startedAt)
        switch h {
        case 5..<9:   return "sun.rise.fill"
        case 9..<17:  return "sun.max.fill"
        case 17..<21: return "moon.stars.fill"
        default:      return "moon.fill"
        }
    }

    private func shiftOptionsTitle(for entry: ShiftEntry) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE MMM d"
        return "\(entry.shiftType.label) \(fmt.string(from: entry.startedAt))"
    }

    private func shiftOptionsSummary(for entry: ShiftEntry) -> String {
        if entry.shiftType.isDayType { return "Full Day" }
        let fmt = DateFormatter()
        fmt.dateFormat = "hh:mm a"
        let end = entry.startedAt.addingTimeInterval(Double(entry.durationMinutes) * 60)
        return "\(fmt.string(from: entry.startedAt)) – \(fmt.string(from: end))  ·  \(formatDuration(entry.durationMinutes))"
    }

    private func relativeDate(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }
}

#Preview {
    NavigationStack {
        HomeView(userName: "Alex", store: ShiftStore())
    }
}
