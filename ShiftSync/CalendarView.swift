import SwiftUI

struct CalendarView: View {
    @ObservedObject var store: ShiftStore

    @State private var displayMonth: Int
    @State private var displayYear: Int
    @State private var selectedDay: Int
    @State private var entryToEdit: ShiftEntry? = nil
    @State private var entryToDelete: ShiftEntry? = nil
    @State private var actionEntry: ShiftEntry? = nil
    @State private var showManualEntry = false
    @State private var showVacationEntry = false

    private static let monthNames = [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]

    init(store: ShiftStore) {
        self.store = store
        let now = Date()
        _displayMonth = State(initialValue: Calendar.current.component(.month, from: now) - 1)
        _displayYear  = State(initialValue: Calendar.current.component(.year,  from: now))
        _selectedDay  = State(initialValue: Calendar.current.component(.day,   from: now))
    }

    // MARK: - Computed

    private var calGrid: [Int?] {
        var comps = DateComponents()
        comps.year  = displayYear
        comps.month = displayMonth + 1
        comps.day   = 1
        guard let firstDay = Calendar.current.date(from: comps) else { return [] }
        let firstDow    = Calendar.current.component(.weekday, from: firstDay) - 1
        let daysInMonth = Calendar.current.range(of: .day, in: .month, for: firstDay)?.count ?? 30
        var cells: [Int?] = Array(repeating: nil, count: firstDow)
        cells += (1...daysInMonth).map { Optional($0) }
        return cells
    }

    private var todayComponents: (day: Int, month: Int, year: Int) {
        let now = Date()
        return (
            Calendar.current.component(.day,   from: now),
            Calendar.current.component(.month, from: now) - 1,
            Calendar.current.component(.year,  from: now)
        )
    }

    private func date(for day: Int) -> Date? {
        var comps = DateComponents()
        comps.year  = displayYear
        comps.month = displayMonth + 1
        comps.day   = day
        return Calendar.current.date(from: comps)
    }

    // All shifts for the currently displayed month, newest first
    private var monthShifts: [ShiftEntry] {
        store.entries
            .filter {
                let c = Calendar.current.dateComponents([.year, .month], from: $0.startedAt)
                return c.year == displayYear && c.month == displayMonth + 1
            }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var totalMonthHoursLabel: String {
        let mins = monthShifts.reduce(0) { $0 + $1.durationMinutes }
        return String(format: "%.1fH", Double(mins) / 60.0)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Schedule")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.ssTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                // Calendar card
                VStack(spacing: 12) {
                    monthNav
                    dayHeaders
                    calendarGrid
                }
                .padding(16)
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)

                Spacer().frame(height: 24)

                // Section header
                HStack {
                    Text("SHIFTS FOR \(Self.monthNames[displayMonth].uppercased())")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.ssTextPrimary)
                    Spacer()
                    if !monthShifts.isEmpty {
                        Text("\(monthShifts.count) SHIFT\(monthShifts.count == 1 ? "" : "S") • \(totalMonthHoursLabel)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.ssTextSecondary)
                    }
                }

                Spacer().frame(height: 12)

                if monthShifts.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 34))
                            .foregroundColor(.ssTextMuted)
                        Text("No shifts this month")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.ssTextMuted)
                        Button("Add a Shift") { showManualEntry = true }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.shiftBlue)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                    .background(Color.darkCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(spacing: 10) {
                        ForEach(monthShifts) { entry in
                            ScheduleShiftRow(entry: entry, onTap: { actionEntry = entry })
                        }
                    }
                }

                Spacer().frame(height: 120)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(item: $entryToEdit) { entry in
            EditShiftView(entry: entry, store: store, isPresented: Binding(
                get: { entryToEdit != nil },
                set: { if !$0 { entryToEdit = nil } }
            ))
        }
        .sheet(isPresented: $showManualEntry) {
            ManualEntryView(store: store, isPresented: $showManualEntry)
        }
        .sheet(isPresented: $showVacationEntry) {
            ManualEntryView(store: store, isPresented: $showVacationEntry, initialShiftType: .vacation)
        }
        .confirmationDialog("Delete Shift?", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let e = entryToDelete { store.deleteEntry(id: e.id) }
                entryToDelete = nil
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        } message: {
            Text("This shift will be permanently removed.")
        }
        .confirmationDialog("Shift Options", isPresented: Binding(
            get: { actionEntry != nil },
            set: { if !$0 { actionEntry = nil } }
        ), titleVisibility: .visible) {
            Button("Edit Shift") { entryToEdit = actionEntry; actionEntry = nil }
            Button("Delete Shift", role: .destructive) { entryToDelete = actionEntry; actionEntry = nil }
            Button("Add New Hours") { actionEntry = nil; showManualEntry = true }
            Button("Log Vacation Day") { actionEntry = nil; showVacationEntry = true }
            Button("Cancel", role: .cancel) { actionEntry = nil }
        }
    }

    // MARK: - Sub-views

    private var monthNav: some View {
        HStack {
            Button(action: prevMonth) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .frame(width: 32, height: 32)
            }
            Spacer()
            Text("\(Self.monthNames[displayMonth]) \(String(displayYear))")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.ssTextPrimary)
            Spacer()
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal, 4)
    }

    private var dayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(Array(["S","M","T","W","T","F","S"].enumerated()), id: \.offset) { _, h in
                Text(h)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.ssTextMuted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var calendarGrid: some View {
        let today = todayComponents
        let rows = (calGrid.count + 6) / 7

        return VStack(spacing: 4) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row * 7 + col
                        let day = calGrid.indices.contains(idx) ? calGrid[idx] : nil
                        let isToday    = day == today.day && displayMonth == today.month && displayYear == today.year
                        let isSelected = day == selectedDay
                        let hasShift   = day.map { hasShifts(on: $0) } ?? false

                        CalendarDayCell(
                            day: day,
                            isToday: isToday,
                            isSelected: isSelected,
                            hasShift: hasShift
                        )
                        .onTapGesture { if let d = day { selectedDay = d } }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func hasShifts(on day: Int) -> Bool {
        guard let d = date(for: day) else { return false }
        return store.hasShifts(on: d)
    }

    private func prevMonth() {
        if displayMonth == 0 { displayMonth = 11; displayYear -= 1 } else { displayMonth -= 1 }
        // 0 matches no day in the grid, so switching months doesn't leave a stale
        // "selected" highlight on day 1 that looks like a false "today" indicator.
        selectedDay = 0
    }

    private func nextMonth() {
        if displayMonth == 11 { displayMonth = 0; displayYear += 1 } else { displayMonth += 1 }
        selectedDay = 0
    }
}

#Preview {
    NavigationStack {
        CalendarView(store: ShiftStore())
    }
}
