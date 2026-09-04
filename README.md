# ShiftSync

A shift tracking app for iOS and Apple Watch built with SwiftUI.

<p align="center">
  <img src="screenshot.png" width="300" alt="ShiftSync Home Screen">
</p>

## Features

- **Clock In / Out** — Start and stop shifts with one tap, synced to Apple Watch
- **Manual Entry** — Log shifts manually with full date, time, and type selection
- **Shift Types** — Regular, Overtime, Holiday (2x pay), Vacation, Sick, Formation, Company Fun Day
- **Pay Calculation** — Live earnings based on your hourly rate and overtime multiplier
- **Overtime Rules** — Auto-splits shifts into regular + overtime when daily threshold is exceeded
- **Work Day Hours** — Configurable hours per day used for all day-off pay calculations
- **Activity Feed** — Recent shifts with duration, pay, and shift type badges
- **Calendar View** — Monthly calendar showing days with logged shifts
- **Export Reports** — Export shift data by period (weekly, monthly, custom)
- **Workplace Geofencing** — Location-based arrival/departure notifications, including a prompt when you're *already* inside the workplace zone at the time you enable alerts
- **Apple Watch App** — Clock in/out from your wrist with instant on-watch confirmation notifications, plus built-in notification permission checker and test button
- **Test Watch Notifications from iPhone** — Settings → Notifications → *Test Apple Watch Notification* relays a request to the watch (with a background-queued fallback via `transferUserInfo` when the watch isn't live-reachable)
- **Notifications** — Missed shift prompts with quick day-type logging
- **Dark Mode** — Full dark/light theme support

## Recent Improvements

- **Reliable custom tab bar** — Rebuilt using `.safeAreaInset(edge: .bottom)` so every tab button reliably receives taps. The previous `ZStack` overlay let the underlying `ScrollView` win the hit-test race in the overlapping region, causing tabs (other than Home / the +) to occasionally not respond.
- **"Already at work" arrival detection** — `LocationManager` now calls `requestState(for:)` right after starting to monitor and handles `didDetermineState`, so the arrival prompt fires even when you enable location alerts (or set your workplace) while already inside the geofence.
- **Watch clock-in/out feedback** — Watch clock actions now use `sendMessage(..., replyHandler:, errorHandler:)` and fire a local notification on the watch confirming success ("Clocked In ✓") or a clear failure reason if the iPhone can't be reached. The phone implements the reply-based `didReceiveMessage` variant so replies never time out.
- **`WCErrorCodeWatchAppNotInstalled` handling** — `WatchSessionManager` publishes `isWatchAppInstalled` and gates every `updateApplicationContext` / `sendMessage` / `transferUserInfo` call behind it, eliminating repeated console error spam when the Watch app isn't installed and surfacing an actionable message in Settings instead.
- **iOS-only target hygiene** — The main app target was ported off the multiplatform template (`SDKROOT = auto` → `iphoneos`), and leftover macOS-only sandbox/entitlement keys (`ENABLE_APP_SANDBOX`, `ENABLE_USER_SELECTED_FILES`, `REGISTER_APP_GROUPS`, `MACOSX_DEPLOYMENT_TARGET`, `XROS_DEPLOYMENT_TARGET`, cross-platform `LD_RUNPATH_SEARCH_PATHS`) were removed. These were the root cause of the *"ShiftSync Watch app can't be installed at this time"* error, because iOS provisioning rejects apps carrying macOS Sandbox entitlements and Watch companions can only pair with a genuine iPhone-only host.

## Screen Support

Optimized for all iPhone sizes:

| Device | Screen | Notes |
|---|---|---|
| iPhone SE (2nd/3rd gen) | 375 × 667 pt | Proportional spacing, no overflow |
| iPhone 16 / 15 | 390 × 844 pt | Default target |
| iPhone 16 Pro Max / 15 Pro Max | 430 × 932 pt | Full layout, adaptive padding |

- Login screen uses proportional spacing via `GeometryReader` — fits without scrolling on SE
- Active shift timer and row text use `minimumScaleFactor` to prevent clipping
- Bottom scroll padding is safe-area-aware across all devices

## Requirements

- iOS 26+
- watchOS 26+ (for Watch app)
- Xcode 26+

## Getting Started

1. Clone the repo:
   ```bash
   git clone git@github.com:Alexmaster12345/ShiftSync-iOS.git
   ```
2. Open `ShiftSync/ShiftSync.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build and run (`Cmd+R`)

## Settings

| Setting | Description |
|---|---|
| Salary & Currency | Hourly/monthly rate, currency, and work day hours in one screen |
| Payment Type | Hourly or monthly pay mode |
| Work Day Hours | Hours counted as one full day (affects day-off pay) |
| Overtime Rules | Toggle + daily threshold and multiplier (e.g. 1.5×) |
| Vacation Days | Annual allowance with used/remaining tracking |
| Workplace Location | Address used for geofence arrival/departure alerts |
| Notifications | iOS notification settings shortcut + Apple Watch test-notification relay |

## Built With

- SwiftUI
- WatchConnectivity (iPhone ↔ Watch sync)
- CoreLocation (geofencing)
- UserDefaults (persistence)

## License

MIT
