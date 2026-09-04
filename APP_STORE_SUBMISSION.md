# App Store Submission Checklist

Tracks the items needed to submit ShiftSync 1.0. Items marked `[x]` are done in the codebase; items marked `[ ]` require action in App Store Connect / hosting, which can't be automated from the repo.

## 1. Privacy & App Store Declarations

- [x] `NSLocationWhenInUseUsageDescription` / `NSLocationAlwaysAndWhenInUseUsageDescription` / `NSLocationAlwaysUsageDescription` — updated to explicitly state location is used strictly for shift reminders and stays on-device.
- [x] Privacy Manifest (`ShiftSync/PrivacyInfo.xcprivacy`) added, declaring no tracking, no collected data types, and `NSPrivacyAccessedAPICategoryUserDefaults` (reason `CA92.1` — app's own on-device preferences).
- [ ] **App Store Connect → App Privacy**: manually declare **"No, we do not collect data"** for this app. This isn't set from Xcode — it's a form in App Store Connect under your app's "App Privacy" section.

## 2. Local Data Backup & Persistence

- [x] Confirmed: all app data lives in `UserDefaults.standard`, which is included in standard iOS device backups (iCloud or Finder/computer) by default — no exclusion flags are set anywhere in the code, so nothing needs to change here.
- [ ] **Future roadmap (not implemented)**: a manual Export/Restore feature (e.g. JSON export you can re-import on a new device) would help users who don't restore from backup when switching phones. Noted in README's roadmap — flag if you want this built before submission or after.

## 3. First-Time Submission Requirements

- [x] Drafted `PRIVACY_POLICY.md` at the repo root — ready to host as a static page (e.g. GitHub Pages) and link from App Store Connect. **Action needed:** replace the placeholder contact email inside it, then publish it and paste the URL into App Store Connect → App Information → Privacy Policy URL.
- [ ] **App Review Notes** — paste this into App Store Connect → App Review Information → Notes when submitting:

  > ShiftSync runs entirely offline. There is no backend server, no account creation or sign-in, and no data collection of any kind — all shift, pay, and settings data is stored locally on the device via UserDefaults. The optional workplace location feature (used only for arrival/departure shift reminders) processes location entirely on-device and never transmits it anywhere. No demo login or test credentials are required to review the app — tap "Continue as Guest" on first launch.

## 4. Versioning & Source Control

- [ ] Commit all QA fixes (pending in working tree as of this checklist).
- [ ] Tag the release candidate, e.g. `v1.0.0-rc1`, before creating the Xcode Archive.
- [ ] Push the commit and tag to `origin` (ask before doing this if working with an assistant — it's a remote-visible action).
