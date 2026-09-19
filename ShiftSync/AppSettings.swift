import Foundation
import Combine
import SwiftUI
import UIKit

// MARK: - App Theme
enum AppTheme: String, Codable, CaseIterable {
    case system = "System"
    case light  = "Light"
    case dark   = "Dark"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Currency
enum Currency: String, Codable, CaseIterable {
    case usd = "USD"
    case ils = "ILS"
    case eur = "EUR"

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .ils: return "₪"
        case .eur: return "€"
        }
    }
    var displayName: String {
        switch self {
        case .usd: return "$ Dollar"
        case .ils: return "₪ Shekel"
        case .eur: return "€ Euro"
        }
    }
}

// MARK: - Payment Type
enum PaymentType: String, Codable, CaseIterable {
    case hourly  = "Hourly"
    case monthly = "Monthly"
}

// MARK: - App Settings
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Pay
    @Published var currency: Currency = .usd          { didSet { persist() } }
    @Published var paymentType: PaymentType = .hourly  { didSet { persist() } }
    @Published var hourlyRate: Double = 24.0           { didSet { persist() } }
    @Published var monthlySalary: Double = 4000.0      { didSet { persist() } }
    @Published var workDayHours: Double = 8.0          { didSet { persist() } }
    @Published var vacationDaysPerYear: Int = 15       { didSet { persist() } }

    // Workplace location
    @Published var workplaceAddress: String = ""       { didSet { persist() } }
    @Published var workplaceLatitude: Double = 0       { didSet { persist() } }
    @Published var workplaceLongitude: Double = 0      { didSet { persist() } }
    @Published var locationAlertsEnabled: Bool = false { didSet { persist() } }
    // Calendar weekday numbers: 1 = Sunday ... 7 = Saturday. Each day is assigned to at
    // most one of these two sets (Office = geofence-based alerts, Home = Work From Home
    // scheduled reminders) — a day can also belong to neither. Defaults to Mon–Fri Office.
    @Published var officeDays: Set<Int> = [2, 3, 4, 5, 6] { didSet { persist() } }
    @Published var homeDays: Set<Int> = [] { didSet { persist() } }
    // Geofence radius in meters. Below ~30m, GPS accuracy makes region monitoring
    // unreliable — Apple recommends 100m+, but 75 is the pre-existing default here.
    @Published var geofenceRadius: Double = 75 { didSet { persist() } }
    // Time of day the "Didn't make it to work today?" reminder fires. Defaults to 6 PM.
    @Published var missedDayReminderHour: Int = 18   { didSet { persist() } }
    @Published var missedDayReminderMinute: Int = 0  { didSet { persist() } }
    // Work From Home: scheduled clock in/out reminders that fire at fixed times on
    // your Work Days, instead of relying on geofencing (which needs a workplace to
    // detect arriving/leaving from — no use when there's no office to geofence).
    @Published var workFromHomeEnabled: Bool = false  { didSet { persist() } }
    @Published var clockInReminderHour: Int = 9       { didSet { persist() } }
    @Published var clockInReminderMinute: Int = 0     { didSet { persist() } }
    @Published var clockOutReminderHour: Int = 17     { didSet { persist() } }
    @Published var clockOutReminderMinute: Int = 0    { didSet { persist() } }

    // Personal info
    @Published var email: String = ""      { didSet { persist() } }
    @Published var jobTitle: String = ""   { didSet { persist() } }
    @Published var branch: String = ""     { didSet { persist() } }

    // Appearance
    @Published var appTheme: AppTheme = .light { didSet { persist() } }
    // Controls how this app renders shift/activity times itself (Home, Calendar,
    // Export). Native DatePicker wheels always follow the device's own setting.
    @Published var use24HourClock: Bool = false { didSet { persist() } }
    // In-app text size, independent of the device's own Settings > Accessibility >
    // Display & Text Size setting — index into uiTextSizeSteps/uiTextSizeLabels below.
    // systemDefaultTextSizeIndex ("Default") means "just follow the device's own
    // accessibility text size setting" rather than forcing a fixed size — Font.ss(_:)
    // in Theme.swift only overrides the live system setting when this is NOT that index.
    @Published var uiTextSizeIndex: Int = AppSettings.systemDefaultTextSizeIndex { didSet { persist() } }

    static let systemDefaultTextSizeIndex = 3
    static let uiTextSizeSteps: [DynamicTypeSize] = [.xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge]
    static let uiTextSizeLabels: [String] = ["Extra Small", "Small", "Medium", "Default", "Large", "Extra Large", "XX-Large"]
    static let uiContentSizeCategorySteps: [UIContentSizeCategory] = [
        .extraSmall, .small, .medium, .large, .extraLarge, .extraExtraLarge, .extraExtraExtraLarge
    ]

    private var clampedTextSizeIndex: Int { min(max(uiTextSizeIndex, 0), Self.uiTextSizeSteps.count - 1) }
    var isUsingSystemDefaultTextSize: Bool { uiTextSizeIndex == Self.systemDefaultTextSizeIndex }
    var uiDynamicTypeSize: DynamicTypeSize { Self.uiTextSizeSteps[clampedTextSizeIndex] }
    var uiContentSizeCategory: UIContentSizeCategory { Self.uiContentSizeCategorySteps[clampedTextSizeIndex] }
    var uiTextSizeLabel: String { Self.uiTextSizeLabels[clampedTextSizeIndex] }

    // Overtime rules
    @Published var overtimeEnabled: Bool = false       { didSet { persist() } }
    @Published var dailyOvertimeHours: Double = 8.0    { didSet { persist() } }
    @Published var weeklyOvertimeHours: Double = 40.0  { didSet { persist() } }
    @Published var overtimeMultiplier: Double = 1.5    { didSet { persist() } }

    private let key = "ss_app_settings_v3"

    private struct Stored: Codable {
        var currency: Currency
        var paymentType: PaymentType
        var hourlyRate: Double
        var monthlySalary: Double
        var vacationDaysPerYear: Int
        var workplaceAddress: String
        var workplaceLatitude: Double
        var workplaceLongitude: Double
        var locationAlertsEnabled: Bool
        var email: String
        var jobTitle: String
        var branch: String
        var appTheme: AppTheme
        // Optional so old saved data decodes without failing
        var workDayHours: Double?
        var overtimeEnabled: Bool?
        var dailyOvertimeHours: Double?
        var weeklyOvertimeHours: Double?
        var overtimeMultiplier: Double?
        var workDays: [Int]?
        var officeDays: [Int]?
        var homeDays: [Int]?
        var geofenceRadius: Double?
        var missedDayReminderHour: Int?
        var missedDayReminderMinute: Int?
        var use24HourClock: Bool?
        var workFromHomeEnabled: Bool?
        var clockInReminderHour: Int?
        var clockInReminderMinute: Int?
        var clockOutReminderHour: Int?
        var clockOutReminderMinute: Int?
        var uiTextSizeIndex: Int?
    }

    init() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let s = try? JSONDecoder().decode(Stored.self, from: data) else { return }
        currency              = s.currency
        paymentType           = s.paymentType
        hourlyRate            = s.hourlyRate
        monthlySalary         = s.monthlySalary
        vacationDaysPerYear   = s.vacationDaysPerYear
        workplaceAddress      = s.workplaceAddress
        workplaceLatitude     = s.workplaceLatitude
        workplaceLongitude    = s.workplaceLongitude
        locationAlertsEnabled = s.locationAlertsEnabled
        email                 = s.email
        jobTitle              = s.jobTitle
        branch                = s.branch
        appTheme              = s.appTheme
        workDayHours          = s.workDayHours          ?? 8.0
        overtimeEnabled       = s.overtimeEnabled      ?? false
        dailyOvertimeHours    = s.dailyOvertimeHours   ?? 8.0
        weeklyOvertimeHours   = s.weeklyOvertimeHours  ?? 40.0
        overtimeMultiplier    = s.overtimeMultiplier   ?? 1.5
        if let off = s.officeDays, let home = s.homeDays {
            officeDays = Set(off)
            homeDays   = Set(home)
        } else {
            // Migrating from the old single shared workDays set: everything that was
            // selected before becomes Office (its prior real behavior), Home starts empty.
            officeDays = Set(s.workDays ?? [2, 3, 4, 5, 6])
            homeDays   = []
        }
        geofenceRadius        = s.geofenceRadius ?? 75
        missedDayReminderHour   = s.missedDayReminderHour   ?? 18
        missedDayReminderMinute = s.missedDayReminderMinute ?? 0
        use24HourClock          = s.use24HourClock ?? false
        workFromHomeEnabled     = s.workFromHomeEnabled ?? false
        clockInReminderHour     = s.clockInReminderHour     ?? 9
        clockInReminderMinute   = s.clockInReminderMinute   ?? 0
        clockOutReminderHour    = s.clockOutReminderHour    ?? 17
        clockOutReminderMinute  = s.clockOutReminderMinute  ?? 0
        uiTextSizeIndex         = s.uiTextSizeIndex ?? 3
    }

    private func persist() {
        let s = Stored(
            currency: currency, paymentType: paymentType,
            hourlyRate: hourlyRate, monthlySalary: monthlySalary,
            vacationDaysPerYear: vacationDaysPerYear,
            workplaceAddress: workplaceAddress,
            workplaceLatitude: workplaceLatitude,
            workplaceLongitude: workplaceLongitude,
            locationAlertsEnabled: locationAlertsEnabled,
            email: email, jobTitle: jobTitle, branch: branch,
            appTheme: appTheme,
            workDayHours: workDayHours,
            overtimeEnabled: overtimeEnabled,
            dailyOvertimeHours: dailyOvertimeHours,
            weeklyOvertimeHours: weeklyOvertimeHours,
            overtimeMultiplier: overtimeMultiplier,
            workDays: nil,
            officeDays: Array(officeDays),
            homeDays: Array(homeDays),
            geofenceRadius: geofenceRadius,
            missedDayReminderHour: missedDayReminderHour,
            missedDayReminderMinute: missedDayReminderMinute,
            use24HourClock: use24HourClock,
            workFromHomeEnabled: workFromHomeEnabled,
            clockInReminderHour: clockInReminderHour,
            clockInReminderMinute: clockInReminderMinute,
            clockOutReminderHour: clockOutReminderHour,
            clockOutReminderMinute: clockOutReminderMinute,
            uiTextSizeIndex: uiTextSizeIndex
        )
        UserDefaults.standard.set(try? JSONEncoder().encode(s), forKey: key)
    }

    var effectiveHourlyRate: Double {
        paymentType == .hourly ? hourlyRate : monthlySalary / 160.0
    }
    var dailyRate: Double { effectiveHourlyRate * workDayHours }
    var rateLabel: String { paymentType == .hourly ? "Hourly Rate" : "Monthly Salary" }
    var hasWorkplaceCoordinates: Bool { workplaceLatitude != 0 || workplaceLongitude != 0 }

    // Calendar weekday order: index 0 = weekday 1 (Sunday) ... index 6 = weekday 7 (Saturday)
    static let weekdaySymbolsShort = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    static func daysLabel(_ days: Set<Int>) -> String {
        if days.isEmpty { return "No days selected" }
        if days.count == 7 { return "Every day" }
        if days == [2, 3, 4, 5, 6] { return "Weekdays (Mon–Fri)" }
        return days.sorted().map { weekdaySymbolsShort[$0 - 1] }.joined(separator: ", ")
    }
    var officeDaysLabel: String { Self.daysLabel(officeDays) }
    var homeDaysLabel: String { Self.daysLabel(homeDays) }

    // Bindable Date wrapper around missedDayReminderHour/Minute for use with DatePicker —
    // only the time-of-day components matter, the date portion is ignored.
    var missedDayReminderTime: Date {
        get {
            Calendar.current.date(bySettingHour: missedDayReminderHour, minute: missedDayReminderMinute, second: 0, of: Date()) ?? Date()
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            missedDayReminderHour   = comps.hour ?? 18
            missedDayReminderMinute = comps.minute ?? 0
        }
    }

    var clockInReminderTime: Date {
        get {
            Calendar.current.date(bySettingHour: clockInReminderHour, minute: clockInReminderMinute, second: 0, of: Date()) ?? Date()
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            clockInReminderHour   = comps.hour ?? 9
            clockInReminderMinute = comps.minute ?? 0
        }
    }

    var clockOutReminderTime: Date {
        get {
            Calendar.current.date(bySettingHour: clockOutReminderHour, minute: clockOutReminderMinute, second: 0, of: Date()) ?? Date()
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            clockOutReminderHour   = comps.hour ?? 17
            clockOutReminderMinute = comps.minute ?? 0
        }
    }
}
