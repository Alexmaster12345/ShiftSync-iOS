import SwiftUI

struct ManualEntryView: View {
    @ObservedObject var store: ShiftStore
    @Binding var isPresented: Bool

    @State private var displayMonth: Int
    @State private var displayYear: Int
    @State private var selectedDay: Int
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var breakMinutes = 30
    @State private var shiftType: ShiftType
    @State private var vacationStartDate: Date
    @State private var vacationEndDate: Date
    @State private var reason = ""

    private static let monthNames = [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]

    init(store: ShiftStore, isPresented: Binding<Bool>, initialShiftType: ShiftType = .regular) {
        self.store = store
        _isPresented = isPresented
        _shiftType = State(initialValue: initialShiftType)
        let now = Date()
        let cal = Calendar.current
        _displayMonth = State(initialValue: cal.component(.month, from: now) - 1)
        _displayYear  = State(initialValue: cal.component(.year,  from: now))
        _selectedDay  = State(initialValue: cal.component(.day,   from: now))
        _vacationStartDate = State(initialValue: cal.startOfDay(for: now))
        _vacationEndDate   = State(initialValue: cal.startOfDay(for: now))
        var startComps = cal.dateComponents([.year, .month, .day], from: now)
        startComps.hour = 9; startComps.minute = 0
        var endComps = startComps; endComps.hour = 17
        _startTime = State(initialValue: cal.date(from: startComps) ?? now)
        _endTime   = State(initialValue: cal.date(from: endComps)   ?? now)
    }

    // MARK: - Calendar grid (Mon-anchored)
    private var calGrid: [Int?] {
        var comps = DateComponents()
        comps.year = displayYear; comps.month = displayMonth + 1; comps.day = 1
        guard let first = Calendar.current.date(from: comps) else { return [] }
        let firstDow = (Calendar.current.component(.weekday, from: first) - 2 + 7) % 7
        let days = Calendar.current.range(of: .day, in: .month, for: first)?.count ?? 30
        var cells: [Int?] = Array(repeating: nil, count: firstDow)
        cells += (1...days).map { Optional($0) }
        return cells
    }

    private var isDayType: Bool { shiftType.isDayType }

    private var vacationDayCount: Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: vacationStartDate)
        let end   = cal.startOfDay(for: vacationEndDate)
        let days  = cal.dateComponents([.day], from: start, to: end).day ?? 0
        return max(1, days + 1)
    }

    private var durationMinutes: Int {
        if isDayType { return vacationDayCount * Int(AppSettings.shared.workDayHours * 60) }
        let diff = endTime.timeIntervalSince(startTime)
        return diff > 0 ? Int(diff / 60) : 0
    }

    private var shiftStartDate: Date? {
        if isDayType { return Calendar.current.startOfDay(for: vacationStartDate) }
        var comps = DateComponents()
        comps.year = displayYear; comps.month = displayMonth + 1; comps.day = selectedDay
        let tp = Calendar.current.dateComponents([.hour, .minute], from: startTime)
        comps.hour = tp.hour; comps.minute = tp.minute
        return Calendar.current.date(from: comps)
    }

    private var canSave: Bool {
        isDayType ? vacationDayCount > 0 : durationMinutes > 0
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    calendarSection
                    if isDayType {
                        vacationDaysSection
                    } else {
                        timeSection
                        detailsSection
                    }
                    reasonSection

                    Button(action: saveEntry) {
                        Text("Save Entry")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(canSave ? Color.shiftBlue : Color.ssTextMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSave)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color.darkBg.ignoresSafeArea())
            .navigationTitle("Add Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }.foregroundColor(.shiftBlue)
                }
            }
        }
    }

    // MARK: - Calendar Section
    private var calendarSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: {
                    if displayMonth == 0 { displayMonth = 11; displayYear -= 1 } else { displayMonth -= 1 }
                }) { Image(systemName: "chevron.left").foregroundColor(.shiftBlue) }
                Spacer()
                Text("\(Self.monthNames[displayMonth]) \(displayYear)")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.ssTextPrimary)
                Spacer()
                Button(action: {
                    if displayMonth == 11 { displayMonth = 0; displayYear += 1 } else { displayMonth += 1 }
                }) { Image(systemName: "chevron.right").foregroundColor(.shiftBlue) }
            }
            .padding(.horizontal, 4)

            HStack(spacing: 0) {
                ForEach(Array(["M","T","W","T","F","S","S"].enumerated()), id: \.offset) { _, h in
                    Text(h).font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.ssTextSecondary).frame(maxWidth: .infinity)
                }
            }

            let today = (
                day:   Calendar.current.component(.day,   from: Date()),
                month: Calendar.current.component(.month, from: Date()) - 1,
                year:  Calendar.current.component(.year,  from: Date())
            )
            let rows = (calGrid.count + 6) / 7
            VStack(spacing: 2) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { col in
                            let idx = row * 7 + col
                            let day = calGrid.indices.contains(idx) ? calGrid[idx] : nil
                            CalendarDayCell(
                                day: day,
                                isToday: day == today.day && displayMonth == today.month && displayYear == today.year,
                                isSelected: isDayType ? false : day == selectedDay,
                                hasShift: false,
                                isInRange: dayIsInRange(day),
                                isRangeEdge: dayIsRangeEdge(day)
                            )
                            .onTapGesture {
                                guard let d = day else { return }
                                if isDayType {
                                    handleVacationTap(day: d)
                                } else {
                                    selectedDay = d
                                }
                            }
                        }
                    }
                }
            }

            // Day-type range summary — one compact line
            if isDayType {
                let rangeAccent: Color = shiftType == .sick ? .redAccent : shiftType == .formation ? .orangeAccent : shiftType == .companyFunDay ? .greenAccent : shiftType == .holiday ? .shiftBlue : .tealAccent
                let rangeIcon: String  = shiftType == .sick ? "cross.fill" : shiftType == .formation ? "graduationcap.fill" : shiftType == .companyFunDay ? "party.popper.fill" : shiftType == .holiday ? "star.fill" : "sun.max.fill"
                Divider().background(Color.darkBg)
                HStack(spacing: 8) {
                    Image(systemName: rangeIcon)
                        .font(.system(size: 13))
                        .foregroundColor(rangeAccent)
                    Text(vacationRangeSummary)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(rangeAccent)
                    Spacer()
                    Text("\(vacationDayCount) day\(vacationDayCount == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.ssTextSecondary)
                }
                .padding(.top, 4)
            }

            // Shift type picker inside calendar card
            HStack {
                Image(systemName: "tag").foregroundColor(.shiftBlue).frame(width: 20)
                Text("Type").font(.system(size: 13, weight: .medium)).foregroundColor(.ssTextSecondary)
                Spacer()
                Picker("", selection: $shiftType) {
                    ForEach(ShiftType.allCases, id: \.self) { t in
                        Text(t.label).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .tint(.shiftBlue)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Vacation Helpers

    private func dateFor(day: Int) -> Date? {
        var comps = DateComponents()
        comps.year = displayYear; comps.month = displayMonth + 1; comps.day = day
        return Calendar.current.date(from: comps)
    }

    private func handleVacationTap(day: Int) {
        guard let tapped = dateFor(day: day) else { return }
        let cal = Calendar.current
        let t = cal.startOfDay(for: tapped)
        let s = cal.startOfDay(for: vacationStartDate)
        if t < s || t == s {
            // Reset: new start, collapse end to same day
            vacationStartDate = t
            vacationEndDate   = t
        } else {
            // Extend end to tapped date
            vacationEndDate = t
        }
    }

    private func dayIsRangeEdge(_ day: Int?) -> Bool {
        guard isDayType, let d = day else { return false }
        return vacationRangeState(for: d).isEdge
    }

    private func dayIsInRange(_ day: Int?) -> Bool {
        guard isDayType, let d = day else { return false }
        return vacationRangeState(for: d).inRange
    }

    private func vacationRangeState(for day: Int) -> (isEdge: Bool, inRange: Bool) {
        guard isDayType, let date = dateFor(day: day) else { return (false, false) }
        let cal = Calendar.current
        let d = cal.startOfDay(for: date)
        let s = cal.startOfDay(for: vacationStartDate)
        let e = cal.startOfDay(for: vacationEndDate)
        if d == s || d == e { return (true, false) }
        if d > s && d < e   { return (false, true) }
        return (false, false)
    }

    private var vacationRangeSummary: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let s = fmt.string(from: vacationStartDate)
        let e = fmt.string(from: vacationEndDate)
        return s == e ? s : "\(s)  →  \(e)"
    }

    // MARK: - Day-type Pay Summary
    private var vacationDaysSection: some View {
        let pay = Double(vacationDayCount) * AppSettings.shared.dailyRate * shiftType.multiplier
        let color: Color = shiftType == .sick ? .redAccent : shiftType == .formation ? .orangeAccent : shiftType == .companyFunDay ? .greenAccent : shiftType == .holiday ? .shiftBlue : .tealAccent
        return HStack(spacing: 10) {
            Image(systemName: "dollarsign.circle")
                .font(.system(size: 15))
                .foregroundColor(color)
            Text("Estimated pay")
                .font(.system(size: 14))
                .foregroundColor(.ssTextSecondary)
            Spacer()
            Text(formatCurrency(pay))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(color)
        }
        .padding(16)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Time Section
    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SHIFT HOURS")
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Start").font(.system(size: 12, weight: .semibold)).foregroundColor(.ssTextSecondary)
                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact).labelsHidden().tint(.shiftBlue)
                        .onChange(of: startTime) {
                            if endTime <= startTime { endTime = startTime.addingTimeInterval(3600) }
                        }
                }
                Image(systemName: "arrow.right").foregroundColor(.ssTextMuted).font(.system(size: 14))
                VStack(alignment: .leading, spacing: 6) {
                    Text("End").font(.system(size: 12, weight: .semibold)).foregroundColor(.ssTextSecondary)
                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact).labelsHidden().tint(.shiftBlue)
                }
                Spacer()
            }
            if durationMinutes > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock").font(.system(size: 12)).foregroundColor(.shiftBlue)
                    Text("Duration: \(formatDuration(durationMinutes))")
                        .font(.system(size: 13, weight: .medium)).foregroundColor(.shiftBlue)
                }
            }
        }
        .padding(16)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Details Section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("DETAILS").padding(.bottom, 12)
            HStack {
                Image(systemName: "cup.and.saucer").foregroundColor(.orangeAccent).frame(width: 24)
                Text("Unpaid Break").font(.system(size: 14, weight: .medium)).foregroundColor(.ssTextPrimary)
                Spacer()
                HStack(spacing: 12) {
                    Button(action: { if breakMinutes >= 15 { breakMinutes -= 15 } }) {
                        Image(systemName: "minus.circle.fill").font(.system(size: 22)).foregroundColor(.shiftBlue)
                    }
                    Text("\(breakMinutes) min")
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.ssTextPrimary)
                        .frame(width: 58, alignment: .center)
                    Button(action: { breakMinutes += 15 }) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(.shiftBlue)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Reason Section
    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("NOTES (OPTIONAL)")
            TextField(isDayType ? "e.g. Annual leave, doctor visit..." : "e.g. Forgot to clock in", text: $reason)
                .font(.system(size: 14)).foregroundColor(.ssTextPrimary)
                .padding(12).background(Color.darkBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.ssTextMuted.opacity(0.4), lineWidth: 1))
        }
        .padding(16)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .semibold)).foregroundColor(.ssTextSecondary).kerning(1)
    }

    // MARK: - Save
    private func saveEntry() {
        guard canSave else { return }

        if isDayType {
            // Save one entry per day so each day appears individually
            let cal = Calendar.current
            var current = cal.startOfDay(for: vacationStartDate)
            let end     = cal.startOfDay(for: vacationEndDate)
            while current <= end {
                let entry = ShiftEntry(
                    shiftType: shiftType,
                    startedAt: current,
                    durationMinutes: Int(AppSettings.shared.workDayHours * 60),
                    unpaidBreakMinutes: 0
                )
                store.addEntry(entry)
                guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
        } else {
            guard let date = shiftStartDate else { return }
            let entry = ShiftEntry(
                shiftType: shiftType,
                startedAt: date,
                durationMinutes: durationMinutes,
                unpaidBreakMinutes: breakMinutes
            )
            store.addEntry(entry)
        }

        isPresented = false
    }
}

// MARK: - Edit Shift View

struct EditShiftView: View {
    let entry: ShiftEntry
    @ObservedObject var store: ShiftStore
    @Binding var isPresented: Bool

    @State private var shiftDate: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var breakMinutes: Int
    @State private var shiftType: ShiftType
    @State private var vacationDays: Int

    init(entry: ShiftEntry, store: ShiftStore, isPresented: Binding<Bool>) {
        self.entry = entry
        self.store = store
        _isPresented = isPresented
        _shiftDate    = State(initialValue: entry.startedAt)
        _startTime    = State(initialValue: entry.startedAt)
        _endTime      = State(initialValue: entry.startedAt.addingTimeInterval(Double(entry.durationMinutes) * 60))
        _breakMinutes = State(initialValue: entry.unpaidBreakMinutes)
        _shiftType    = State(initialValue: entry.shiftType)
        _vacationDays = State(initialValue: max(1, entry.durationMinutes / 480))
    }

    private var isDayType: Bool { shiftType.isDayType }

    private var durationMinutes: Int {
        if isDayType { return vacationDays * 480 }
        let diff = endTime.timeIntervalSince(startTime)
        return diff > 0 ? Int(diff / 60) : 0
    }

    private var canSave: Bool { isDayType ? vacationDays > 0 : durationMinutes > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Date picker
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(Color.shiftBlue.opacity(0.15)).frame(width: 34, height: 34)
                            Image(systemName: "calendar").font(.system(size: 14)).foregroundColor(.shiftBlue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DATE").font(.system(size: 10, weight: .semibold)).foregroundColor(.ssTextMuted).kerning(1)
                            DatePicker("", selection: $shiftDate, displayedComponents: .date)
                                .datePickerStyle(.compact).labelsHidden().tint(.shiftBlue)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(Color.darkCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Shift type
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.shiftBlue.opacity(0.15)).frame(width: 34, height: 34)
                                Image(systemName: "tag").font(.system(size: 14)).foregroundColor(.shiftBlue)
                            }
                            Text("Shift Type").font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                            Spacer()
                            Picker("", selection: $shiftType) {
                                ForEach(ShiftType.allCases, id: \.self) { t in Text(t.label).tag(t) }
                            }
                            .pickerStyle(.menu).tint(.shiftBlue)
                        }
                        .padding(14)
                    }
                    .background(Color.darkCard)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    if isDayType {
                        // Vacation days
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.tealAccent.opacity(0.15)).frame(width: 34, height: 34)
                                Image(systemName: "sun.max.fill").font(.system(size: 14)).foregroundColor(.tealAccent)
                            }
                            Text("Days").font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                            Spacer()
                            HStack(spacing: 16) {
                                Button(action: { if vacationDays > 1 { vacationDays -= 1 } }) {
                                    Image(systemName: "minus.circle.fill").font(.system(size: 24))
                                        .foregroundColor(vacationDays > 1 ? .shiftBlue : .ssTextMuted)
                                }
                                Text("\(vacationDays)").font(.system(size: 18, weight: .bold)).foregroundColor(.ssTextPrimary).frame(width: 28, alignment: .center)
                                Button(action: { vacationDays += 1 }) {
                                    Image(systemName: "plus.circle.fill").font(.system(size: 24)).foregroundColor(.shiftBlue)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.darkCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        // Start / end time
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SHIFT HOURS").font(.system(size: 11, weight: .semibold)).foregroundColor(.ssTextSecondary).kerning(1)
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Start").font(.system(size: 12, weight: .semibold)).foregroundColor(.ssTextSecondary)
                                    DatePicker("", selection: $startTime, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact).labelsHidden().tint(.shiftBlue)
                                        .onChange(of: startTime) {
                                            if endTime <= startTime { endTime = startTime.addingTimeInterval(3600) }
                                        }
                                }
                                Image(systemName: "arrow.right").foregroundColor(.ssTextMuted).font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("End").font(.system(size: 12, weight: .semibold)).foregroundColor(.ssTextSecondary)
                                    DatePicker("", selection: $endTime, displayedComponents: .hourAndMinute)
                                        .datePickerStyle(.compact).labelsHidden().tint(.shiftBlue)
                                }
                                Spacer()
                            }
                            if durationMinutes > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "clock").font(.system(size: 12)).foregroundColor(.shiftBlue)
                                    Text("Duration: \(formatDuration(durationMinutes))").font(.system(size: 13, weight: .medium)).foregroundColor(.shiftBlue)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.darkCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                        // Break
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.orangeAccent.opacity(0.15)).frame(width: 34, height: 34)
                                Image(systemName: "cup.and.saucer").font(.system(size: 14)).foregroundColor(.orangeAccent)
                            }
                            Text("Unpaid Break").font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                            Spacer()
                            HStack(spacing: 12) {
                                Button(action: { if breakMinutes >= 15 { breakMinutes -= 15 } }) {
                                    Image(systemName: "minus.circle.fill").font(.system(size: 24))
                                        .foregroundColor(breakMinutes >= 15 ? .shiftBlue : .ssTextMuted)
                                }
                                Text("\(breakMinutes) min").font(.system(size: 14, weight: .semibold)).foregroundColor(.ssTextPrimary).frame(width: 60, alignment: .center)
                                Button(action: { breakMinutes += 15 }) {
                                    Image(systemName: "plus.circle.fill").font(.system(size: 24)).foregroundColor(.shiftBlue)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.darkCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: saveChanges) {
                        Text("Save Changes")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(canSave ? Color.shiftBlue : Color.ssTextMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSave)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }
            .background(Color.darkBg.ignoresSafeArea())
            .navigationTitle("Edit Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }.foregroundColor(.shiftBlue)
                }
            }
        }
    }

    private func saveChanges() {
        guard canSave else { return }
        let cal = Calendar.current
        let newStart: Date
        if isDayType {
            newStart = cal.startOfDay(for: shiftDate)
        } else {
            var comps = cal.dateComponents([.year, .month, .day], from: shiftDate)
            let timeComps = cal.dateComponents([.hour, .minute], from: startTime)
            comps.hour = timeComps.hour; comps.minute = timeComps.minute
            newStart = cal.date(from: comps) ?? shiftDate
        }
        // Use init to recalculate estimatedPay with current settings and types
        let updated = ShiftEntry(
            id: entry.id,
            shiftType: shiftType,
            startedAt: newStart,
            durationMinutes: durationMinutes,
            unpaidBreakMinutes: isDayType ? 0 : breakMinutes
        )
        store.updateEntry(updated)
        isPresented = false
    }
}

#Preview {
    ManualEntryView(store: ShiftStore(), isPresented: .constant(true))
}
