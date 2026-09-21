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
- **Work From Home Reminders** — No office to detect? Set fixed Clock In / Clock Out times and get reminded on your Home days instead of relying on geofencing
- **Per-Day Work Schedule** — Assign each weekday to Office (blue, geofence-based), Home (green, Work From Home reminders), or Off with a tap — the two notification systems never fire on the same day
- **Apple Watch App** — Clock in/out from your wrist with instant on-watch confirmation notifications, plus built-in notification permission checker and test button
- **Clock In/Out Notifications** — Every clock in/out fires an instant local notification ("Clocked In ✓" / "Clocked Out ✓"). watchOS mirrors these to a paired Apple Watch automatically — no Watch app installation required
- **Notifications** — Missed shift prompts (with quick day-type logging) and Work From Home clock in/out reminders, both with a configurable time and self-aware of days you've already worked so they don't fire needlessly
- **Dark Mode & Time Format** — Full dark/light/system theme support, plus an independent 12-hour/24-hour toggle for how the app displays shift times
- **In-App Text Size** — Resize ShiftSync's own text independent of the device's system-wide Dynamic Type setting (Profile → Appearance)
- **App Lock** — Optional Face ID / Touch ID / device passcode gate on launch and on returning from the background (Profile → Security & Privacy), off by default
- **App Switcher Privacy Masking** — Shift and earnings data is blurred the instant the app leaves the foreground, so it can't be captured in an app-switcher screenshot
- **Backup & Restore** — Export all shift records to a JSON file and re-import them on another device (Profile → Security & Privacy)
- **In-App Guide** — "How to Use ShiftSync" walkthrough in Profile → Help covering every feature

## Recent Improvements

- **App Lock, app-switcher masking, and export cleanup** — Added an opt-in Face ID/Touch ID/passcode gate (`AppLockManager`), a blur mask that engages the instant the app isn't foreground/active, and cleanup of temp CSV/PDF/JSON export files once the share sheet finishes instead of leaving them in `tmp/`.
- **Relicensed under GPL-3.0** — Replaced the MIT license with the GNU GPLv3.
- **Appearance now requires an explicit Save** — Theme, Time Format, and Text Size are staged locally and only committed to settings when you tap Save Changes, instead of applying the instant you tap an option.
- **In-app Text Size control** — A dedicated Bigger/Smaller control in Appearance, independent of the device's own accessibility text size, implemented via a `Font.ss()` helper that reads the chosen size directly instead of relying on SwiftUI's environment (which doesn't bridge to `UIFontMetrics`).
- **App-wide Dynamic Type support** — Every text element now scales with the system (or in-app) text size setting via `UIFontMetrics`, including fixes for icon glyphs that shouldn't scale and small fixed-width badges that used to wrap mid-character at large accessibility sizes.
- **Unit test suite** — Added a Swift Testing suite (`ShiftSyncTests`) covering pay calculation, overtime splitting, and settings' pure-function logic. In the process, found and fixed a serious bug where the test suite's cleanup calls were sharing (and wiping) the real app's `UserDefaults` on whatever simulator/device hosted the tests — `ShiftStore` now takes an injectable `UserDefaults`, and tests always point at an isolated suite.
- **New brand icon** — Replaced the literal analog-clock app icon with the official brand mark (a blue 270° "sync arrow" ring + center clock hand on white), rendered at full 1024×1024 resolution from the brand identity spec, for both the iPhone and Watch app.
- **Real bundle identifier** — Fixed a placeholder `com0.ShiftSync` bundle ID (and the Watch app's matching `WKCompanionAppBundleIdentifier`) left over from project creation, ahead of first App Store submission.
- **Pay Rate redesigned as 3 columns** — Salary & Currency's Payment Type / Hourly Rate / Work Day Hours moved from 3 stacked rows to 3 side-by-side columns, with consistent font sizing across all three.
- **App Store submission prep** — Drafted listing copy (description, keywords, subtitle) and a full screenshot set in `APP_STORE_SUBMISSION.md` / `AppStoreScreenshots/`, ready for App Store Connect.
- **Per-day Office/Home Work Schedule** — Replaced the single shared "Work Days" set with independent per-day assignment, so geofence-based Office alerts and Work From Home reminders can run on different days without double-firing.
- **Work From Home reminders** — New scheduled Clock In/Out notifications for users without a workplace to geofence, with configurable times and the same "already worked today" awareness as the missed-day check.
- **Notification reliability fixes** — Fixed a duplicate "clock out" notification (missing cooldown + missing "already clocked out" guard) and a false-positive "didn't make it to work today" alert that could fire even after a shift was logged.
- **Unified time formatting** — Added a 12-hour/24-hour toggle in Appearance so the app's own displayed times (Home, Calendar, Export) match your preference, independent of the device's native picker format.
- **Reliable custom tab bar** — Rebuilt using `.safeAreaInset(edge: .bottom)` so every tab button reliably receives taps. The previous `ZStack` overlay let the underlying `ScrollView` win the hit-test race in the overlapping region, causing tabs (other than Home / the +) to occasionally not respond.
- **"Already at work" arrival detection** — `LocationManager` now calls `requestState(for:)` right after starting to monitor and handles `didDetermineState`, so the arrival prompt fires even when you enable location alerts (or set your workplace) while already inside the geofence.
- **Watch clock-in/out feedback** — Watch clock actions now use `sendMessage(..., replyHandler:, errorHandler:)` and fire a local notification on the watch confirming success ("Clocked In ✓") or a clear failure reason if the iPhone can't be reached. The phone implements the reply-based `didReceiveMessage` variant so replies never time out.
- **`WCErrorCodeWatchAppNotInstalled` handling** — `WatchSessionManager` publishes `isWatchAppInstalled` and gates every `updateApplicationContext` / `sendMessage` / `transferUserInfo` call behind it, eliminating repeated console error spam when the Watch app isn't installed and surfacing an actionable message in Settings instead.
- **iOS-only target hygiene** — The main app target was ported off the multiplatform template (`SDKROOT = auto` → `iphoneos`), and leftover macOS-only sandbox/entitlement keys (`ENABLE_APP_SANDBOX`, `ENABLE_USER_SELECTED_FILES`, `REGISTER_APP_GROUPS`, `MACOSX_DEPLOYMENT_TARGET`, `XROS_DEPLOYMENT_TARGET`, cross-platform `LD_RUNPATH_SEARCH_PATHS`) were removed. These were the root cause of the *"ShiftSync Watch app can't be installed at this time"* error, because iOS provisioning rejects apps carrying macOS Sandbox entitlements and Watch companions can only pair with a genuine iPhone-only host.
- **Simplified Watch onboarding in Settings** — Removed the Apple Watch pairing/install status section from Settings → Notifications, since Xcode's device support for brand-new Watch hardware can lag behind release and made that UI more confusing than helpful. Clock in/out confirmations now reach the Watch via standard notification mirroring instead, which works regardless of whether the dedicated Watch app is installed.

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
| Arrival & Departure Alerts | Toggle for geofence-based Office notifications |
| Work From Home | Toggle + Clock In/Out reminder times for days without a workplace to geofence |
| Work Schedule | Per-day Office / Home / Off assignment, driving which notification system fires on each weekday |
| Appearance | Theme (Dark/Light/System), 12-hour/24-hour time format, and in-app Text Size — all staged, applied via Save Changes |
| App Lock | Optional Face ID / Touch ID / passcode gate on launch and foreground (Security & Privacy) |
| Legal | Terms of Use and Privacy Policy, viewable in-app |
| Data Backup | Export/Import shift records as JSON (Security & Privacy) |
| How to Use | In-app feature walkthrough (Profile → Help) |

## Built With

- SwiftUI
- Swift Testing (unit tests)
- WatchConnectivity (iPhone ↔ Watch sync)
- CoreLocation (geofencing)
- LocalAuthentication (App Lock)
- UserDefaults (persistence)

## Privacy

ShiftSync collects no data and has no backend — everything is stored locally on-device via `UserDefaults`, which is included in standard iOS backups (iCloud or Finder/computer). See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for the full policy and [APP_STORE_SUBMISSION.md](APP_STORE_SUBMISSION.md) for submission checklist details.

## Roadmap

- **Live Activities & Dynamic Island** — real-time shift duration and live earnings on the Lock Screen while clocked in. Requires a Widget Extension target + App Group to share state with the main app.
- **Home Screen Widgets** — one-tap clock in/out and a weekly earnings summary. Same App Group/extension prerequisite as above.
- Email sign-in (currently disabled — placeholder shown on the login screen)

## License

GPL-3.0
