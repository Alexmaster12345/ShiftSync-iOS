import SwiftUI

// MARK: - Sub-screen Nav Header

func navHeader(title: String, dismiss: DismissAction) -> some View {
    ZStack {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.ssTextPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.darkCard)
                    .clipShape(Circle())
            }
            Spacer()
        }
        Text(title)
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.ssTextPrimary)
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 4)
}

// MARK: - Stats Card
struct StatsCard: View {
    let icon: String
    let label: String
    let value: String
    var progress: Double? = nil
    var sub: String? = nil
    var subColor: Color = .ssTextSecondary
    var accentColor: Color = .shiftBlue

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.ssTextSecondary)
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.ssTextSecondary)
                    .kerning(0.5)
                    .lineLimit(1)
            }
            Spacer().frame(height: 8)
            Text(value)
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.ssTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let p = progress {
                Spacer().frame(height: 8)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(UIColor.tertiarySystemFill)).frame(height: 4)
                        RoundedRectangle(cornerRadius: 2).fill(accentColor)
                            .frame(width: geo.size.width * CGFloat(min(1, p)), height: 4)
                    }
                }
                .frame(height: 4)
            }
            if let s = sub {
                Spacer().frame(height: 4)
                Text(s)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(subColor)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Worked Shift Row
struct WorkedShiftRow: View {
    let entry: ShiftEntry
    var onTap: (() -> Void)? = nil

    private let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "hh:mm a"
        return f
    }()

    private var timeRange: String {
        let start = timeFmt.string(from: entry.startedAt)
        let end   = timeFmt.string(from: entry.startedAt.addingTimeInterval(Double(entry.durationMinutes) * 60))
        return "\(start) – \(end)"
    }

    private var accentColor: Color {
        switch entry.shiftType {
        case .vacation:  return .tealAccent
        case .sick:      return .redAccent
        case .formation: return .orangeAccent
        default:         return .shiftBlue
        }
    }

    private var dayIcon: String {
        switch entry.shiftType {
        case .vacation:  return "sun.max.fill"
        case .sick:      return "cross.fill"
        case .formation: return "graduationcap.fill"
        default:         return "sun.max.fill"
        }
    }

    private var dayLabel: String {
        switch entry.shiftType {
        case .vacation:  return "Vacation Day"
        case .sick:      return "Sick Day"
        case .formation: return "Formation Day"
        default:         return entry.shiftType.label
        }
    }

    private var daySubtitle: String {
        switch entry.shiftType {
        case .vacation:  return "Paid Time Off"
        case .sick:      return "Medical Leave"
        case .formation: return "Professional Development"
        default:         return ""
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 4, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            Spacer().frame(width: 14)

            VStack(alignment: .leading, spacing: 3) {
                if entry.shiftType.isDayType {
                    HStack(spacing: 6) {
                        Image(systemName: dayIcon)
                            .font(.system(size: 13))
                            .foregroundColor(accentColor)
                        Text(dayLabel)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.ssTextPrimary)
                    }
                    Text(daySubtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.ssTextSecondary)
                } else {
                    Text(timeRange)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.ssTextPrimary)
                    Text("\(entry.shiftType.label)  •  \(formatDuration(entry.durationMinutes))")
                        .font(.system(size: 12))
                        .foregroundColor(.ssTextSecondary)
                    if entry.unpaidBreakMinutes > 0 {
                        Text("Break: \(entry.unpaidBreakMinutes) min")
                            .font(.system(size: 11))
                            .foregroundColor(.ssTextMuted)
                    }
                }
            }

            Spacer()

            Text(formatCurrency(entry.estimatedPay))
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(entry.shiftType.isDayType ? accentColor : .greenAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((entry.shiftType.isDayType ? accentColor : Color.greenAccent).opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let day: Int?
    let isToday: Bool
    let isSelected: Bool
    let hasShift: Bool
    var isOtherMonth: Bool = false
    var isInRange: Bool = false
    var isRangeEdge: Bool = false

    private var bgColor: Color {
        if isRangeEdge { return .tealAccent }
        if isSelected  { return .shiftBlue }
        if isInRange   { return Color.tealAccent.opacity(0.18) }
        if hasShift    { return Color.shiftBlue.opacity(0.12) }
        return .clear
    }

    private var textColor: Color {
        if isOtherMonth            { return Color(UIColor.tertiaryLabel) }
        if isRangeEdge || isSelected { return .white }
        if isInRange               { return .tealAccent }
        if hasShift || isToday     { return .shiftBlue }
        return .ssTextPrimary
    }

    private var fontWeight: Font.Weight {
        (isSelected || isRangeEdge || isInRange || hasShift || isToday) ? .bold : .regular
    }

    var body: some View {
        ZStack {
            Circle().fill(bgColor)
            if isToday && !isSelected && !hasShift {
                Circle().stroke(Color.shiftBlue, lineWidth: 1.5)
            }
            if let d = day {
                Text("\(d)")
                    .font(.system(size: 14, weight: fontWeight))
                    .foregroundColor(textColor)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Schedule Shift Row
struct ScheduleShiftRow: View {
    let entry: ShiftEntry
    var onTap: (() -> Void)? = nil

    private let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "hh:mm a"
        return f
    }()

    private var timeRange: String {
        let s = timeFmt.string(from: entry.startedAt)
        let e = timeFmt.string(from: entry.startedAt.addingTimeInterval(Double(entry.durationMinutes) * 60))
        return "\(s) - \(e)"
    }

    private var rowAccentColor: Color {
        switch entry.shiftType {
        case .vacation:  return .tealAccent
        case .sick:      return .redAccent
        case .formation: return .orangeAccent
        default:         return .shiftBlue
        }
    }

    private var shiftName: String {
        switch entry.shiftType {
        case .vacation:  return "Vacation Day"
        case .sick:      return "Sick Day"
        case .formation: return "Formation Day"
        default: break
        }
        let h = Calendar.current.component(.hour, from: entry.startedAt)
        switch h {
        case 5..<12:  return "Morning Shift"
        case 12..<17: return "Afternoon Shift"
        case 17..<21: return "Evening Shift"
        default:      return "Night Shift"
        }
    }

    private var dayLabel: String {
        "\(Calendar.current.component(.day, from: entry.startedAt))"
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: entry.startedAt).uppercased()
    }

    private var hoursLabel: String {
        if entry.shiftType.isDayType { return "1 day" }
        let h = Double(entry.durationMinutes) / 60.0
        return String(format: "%.1fh", h)
    }

    private var badgeLabel: String {
        switch entry.shiftType {
        case .vacation:  return "VACATION"
        case .sick:      return "SICK DAY"
        case .formation: return "FORMATION"
        default:         return "COMPLETED"
        }
    }

    private var subtitleText: String {
        switch entry.shiftType {
        case .vacation:  return "Paid Time Off"
        case .sick:      return "Medical Leave"
        case .formation: return "Professional Development"
        default:         return timeRange
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Date block
            VStack(spacing: 0) {
                Text(monthLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(rowAccentColor)
                    .kerning(0.5)
                Text(dayLabel)
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(rowAccentColor)
            }
            .frame(width: 42)

            // Shift info
            VStack(alignment: .leading, spacing: 3) {
                Text(shiftName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(entry.shiftType.isDayType ? rowAccentColor : .ssTextPrimary)
                Text(subtitleText)
                    .font(.system(size: 12))
                    .foregroundColor(.ssTextSecondary)
            }

            Spacer()

            // Right: hours + status
            VStack(alignment: .trailing, spacing: 4) {
                Text(hoursLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.ssTextPrimary)
                Text(badgeLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(entry.shiftType.isDayType ? rowAccentColor : .greenAccent)
                    .kerning(0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}
