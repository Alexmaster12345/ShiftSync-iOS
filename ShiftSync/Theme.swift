import SwiftUI
import UIKit

// MARK: - Dynamic Type-aware fixed-size fonts
extension Font {
    /// Drop-in replacement for `.system(size:weight:design:)` that scales with a text size
    /// setting, via UIFontMetrics (the same mechanism UIKit uses to scale custom fonts).
    /// Renders at exactly the given point size under the default content size category —
    /// a behavior-preserving swap when nobody has changed any text size setting.
    ///
    /// By default (AppSettings.shared's "Default" text size step) this tracks the
    /// device's own live Settings > Accessibility > Text Size, same as UIFontMetrics.default
    /// always has. But ShiftSync also exposes its own in-app Text Size control (Profile >
    /// Appearance) so users can resize just this app's text — UIFontMetrics reads the
    /// *live* system trait collection and has no way to know about that SwiftUI-only
    /// setting, so when the user picks anything other than "Default" there we explicitly
    /// pass a UITraitCollection carrying the chosen size instead, overriding the system's.
    static func ss(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let uiWeight: UIFont.Weight = {
            switch weight {
            case .ultraLight: return .ultraLight
            case .thin:        return .thin
            case .light:       return .light
            case .medium:      return .medium
            case .semibold:    return .semibold
            case .bold:        return .bold
            case .heavy:       return .heavy
            case .black:       return .black
            default:           return .regular
            }
        }()
        var uiFont = UIFont.systemFont(ofSize: size, weight: uiWeight)
        if design != .default,
           let descriptor = uiFont.fontDescriptor.withDesign(uiFont.fontDescriptor.uiDesign(for: design)) {
            uiFont = UIFont(descriptor: descriptor, size: size)
        }
        let settings = AppSettings.shared
        if settings.isUsingSystemDefaultTextSize {
            return Font(UIFontMetrics.default.scaledFont(for: uiFont))
        }
        let trait = UITraitCollection(preferredContentSizeCategory: settings.uiContentSizeCategory)
        return Font(UIFontMetrics.default.scaledFont(for: uiFont, compatibleWith: trait))
    }
}

private extension UIFontDescriptor {
    func uiDesign(for design: Font.Design) -> UIFontDescriptor.SystemDesign {
        switch design {
        case .monospaced: return .monospaced
        case .rounded:    return .rounded
        case .serif:      return .serif
        default:          return .default
        }
    }
}

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

// Single source of truth for how shift/activity times are displayed, so Home,
// Calendar, and Export all agree with each other (previously some screens
// hardcoded 12-hour "hh:mm a" and others hardcoded 24-hour "HH:mm").
// Note: this only controls text this app renders itself — native DatePicker
// wheels (Manual Entry, Reminder Time) always follow the device's own
// Region/Language 12h/24h setting; iOS doesn't expose a way for an app to
// override that independently.
private let timeFormatter24h: DateFormatter = { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }()
private let timeFormatter12h: DateFormatter = { let f = DateFormatter(); f.dateFormat = "hh:mm a"; return f }()

func formatTime(_ date: Date) -> String {
    (AppSettings.shared.use24HourClock ? timeFormatter24h : timeFormatter12h).string(from: date)
}
