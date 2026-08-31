import SwiftUI

// MARK: - Color Palette
extension Color {
    // Accent / brand (static, not theme-dependent)
    static let shiftBlue      = Color(red: 59/255,  green: 130/255, blue: 246/255)
    static let shiftBlueDark  = Color(red: 37/255,  green: 99/255,  blue: 235/255)
    static let shiftBlueLight = Color(red: 45/255,  green: 74/255,  blue: 122/255)
    static let greenAccent    = Color(red: 16/255,  green: 185/255, blue: 129/255)
    static let orangeAccent   = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let redAccent      = Color(red: 239/255, green: 68/255,  blue: 68/255)
    static let tealAccent     = Color(red: 20/255,  green: 184/255, blue: 166/255)

    // Adaptive backgrounds — auto-switch between light and dark mode
    static let darkBg      = Color(UIColor.systemGroupedBackground)           // light gray in light, very dark in dark
    static let darkCard    = Color(UIColor.secondarySystemGroupedBackground)  // white in light, dark gray in dark
    static let darkSurface = Color(UIColor.systemBackground)

    // Adaptive text colors
    static let ssTextPrimary   = Color(UIColor.label)
    static let ssTextSecondary = Color(UIColor.secondaryLabel)
    static let ssTextMuted     = Color(UIColor.tertiaryLabel)
}

// MARK: - Formatters
func formatDuration(_ minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    if h > 0 && m > 0 { return "\(h)h \(m)m" }
    if h > 0 { return "\(h)h" }
    return "\(m)m"
}

func formatElapsedHMS(_ totalSeconds: Int) -> String {
    let h = totalSeconds / 3600
    let m = (totalSeconds % 3600) / 60
    let s = totalSeconds % 60
    return String(format: "%02d:%02d:%02d", h, m, s)
}

// Uses the active currency symbol from AppSettings
func formatCurrency(_ amount: Double) -> String {
    String(format: "%@%.2f", AppSettings.shared.currency.symbol, amount)
}
