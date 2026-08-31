import Foundation
import Combine
import SwiftUI

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

    // Personal info
    @Published var email: String = ""      { didSet { persist() } }
    @Published var jobTitle: String = ""   { didSet { persist() } }
    @Published var branch: String = ""     { didSet { persist() } }

    // Appearance
    @Published var appTheme: AppTheme = .light { didSet { persist() } }

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
            overtimeMultiplier: overtimeMultiplier
        )
        UserDefaults.standard.set(try? JSONEncoder().encode(s), forKey: key)
    }

    var effectiveHourlyRate: Double {
        paymentType == .hourly ? hourlyRate : monthlySalary / 160.0
    }
    var dailyRate: Double { effectiveHourlyRate * workDayHours }
    var rateLabel: String { paymentType == .hourly ? "Hourly Rate" : "Monthly Salary" }
    var hasWorkplaceCoordinates: Bool { workplaceLatitude != 0 || workplaceLongitude != 0 }
}
