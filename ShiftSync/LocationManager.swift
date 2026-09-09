import Foundation
import UIKit
import CoreLocation
import MapKit
import UserNotifications
import Combine

class LocationManager: NSObject, ObservableObject {
    static let shared = LocationManager()

    private let clManager = CLLocationManager()
    private let regionID  = "ss_workplace_geofence"

    // Notification category & action identifiers
    private let categoryArrive   = "SS_ARRIVE"
    private let categoryDepart   = "SS_DEPART"
    private let categoryMissedDay = "SS_MISSED_DAY"
    private let actionClockIn    = "SS_CLOCK_IN"
    private let actionClockOut   = "SS_CLOCK_OUT"
    private let missedDayID      = "ss_daily_missed"
    private let lastArrivalKey   = "ss_last_arrival_ts"
    private let lastDepartureKey = "ss_last_departure_ts"

    enum PendingClockAction { case clockIn, clockOut, logDayOff }

    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var isMonitoring: Bool = false
    @Published var isGeocoding: Bool = false
    @Published var pendingClockAction: PendingClockAction? = nil

    private override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authStatus = clManager.authorizationStatus
        isMonitoring = clManager.monitoredRegions.contains { $0.identifier == regionID }
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()
    }

    // MARK: - Public API

    var needsSettingsForAlways: Bool {
        authStatus == .denied || authStatus == .restricted
    }

    func requestPermissions() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        switch clManager.authorizationStatus {
        case .notDetermined, .authorizedWhenInUse:
            clManager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// Geocode `address`, save coordinates, and activate the geofence.
    func saveLocation(address: String, completion: @escaping (Bool, String) -> Void) {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            completion(false, "Please enter an address first.")
            return
        }
        DispatchQueue.main.async { self.isGeocoding = true }

        Task { [weak self] in
            defer { DispatchQueue.main.async { self?.isGeocoding = false } }
            guard let request = MKGeocodingRequest(addressString: trimmed) else {
                DispatchQueue.main.async { completion(false, "Invalid address.") }
                return
            }
            do {
                let mapItems = try await request.mapItems
                guard let item = mapItems.first else {
                    DispatchQueue.main.async { completion(false, "Address not found. Try adding a city or country.") }
                    return
                }
                let coord = item.location.coordinate
                guard CLLocationCoordinate2DIsValid(coord) else {
                    DispatchQueue.main.async { completion(false, "Address not found. Try adding a city or country.") }
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    AppSettings.shared.workplaceLatitude  = coord.latitude
                    AppSettings.shared.workplaceLongitude = coord.longitude
                    self.startRegion(center: coord)
                    completion(true, "Location set! You'll be notified when you arrive or leave.")
                }
            } catch {
                DispatchQueue.main.async { completion(false, "Address not found. Try adding a city or country.") }
            }
        }
    }

    /// Re-attach geofence from saved coordinates (called at app launch).
    func restoreMonitoring() {
        let lat = AppSettings.shared.workplaceLatitude
        let lon = AppSettings.shared.workplaceLongitude
        guard lat != 0 || lon != 0 else { return }
        startRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }

    func stopMonitoring() {
        clManager.monitoredRegions
            .filter { $0.identifier == regionID }
            .forEach { clManager.stopMonitoring(for: $0) }
        DispatchQueue.main.async { self.isMonitoring = false }
    }

    /// Fires a plain notification to verify notification permission is working.
    func sendTestNotification() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                guard granted else { return }
                // Small delay so the banner appears above the app
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.deliver(
                        title: "Notifications are working ✓",
                        body: "ShiftSync can send you arrival and departure alerts.",
                        id: "test_\(Int(Date().timeIntervalSince1970))",
                        delaySeconds: 1
                    )
                }
            }
    }

    /// Marks "today" as already worked, so the missed-day reminder won't fire or prompt.
    /// Called for both geofence-detected arrivals and manual clock in/out — a manual
    /// clock action is just as valid a signal that the user worked today.
    func markWorkedToday() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastArrivalKey)
    }

    /// Simulates arriving — fires the real arrival notification with the Clock In button.
    func simulateArrival() {
        AlertLog.shared.addArrival()
        deliver(
            title: "You've arrived at work!",
            body: "Tap Clock In to start your shift.",
            id: "sim_arrive_\(Int(Date().timeIntervalSince1970))",
            category: categoryArrive
        )
    }

    // MARK: - Private

    private func registerNotificationCategories() {
        let clockIn = UNNotificationAction(identifier: actionClockIn,  title: "Clock In",  options: [])
        let clockOut = UNNotificationAction(identifier: actionClockOut, title: "Clock Out", options: [])
        let arrive  = UNNotificationCategory(identifier: categoryArrive,   actions: [clockIn],  intentIdentifiers: [], options: .customDismissAction)
        let depart  = UNNotificationCategory(identifier: categoryDepart,   actions: [clockOut], intentIdentifiers: [], options: .customDismissAction)
        let missed  = UNNotificationCategory(identifier: categoryMissedDay, actions: [],        intentIdentifiers: [], options: .customDismissAction)
        UNUserNotificationCenter.current().setNotificationCategories([arrive, depart, missed])
    }

    // MARK: - Daily absence check

    /// Schedule a repeating 6 PM notification, once per selected work day of the week, so
    /// it only ever fires on days the user is actually scheduled to work. Safe to call at
    /// any time of day from anywhere (app launch, settings changes, geofence events) —
    /// if the user already worked today, today's occurrence is skipped and replaced with
    /// a one-shot for the next applicable work day, instead of blindly re-arming a 6 PM
    /// trigger that would still fire later today.
    func scheduleDailyAbsenceCheck() {
        cancelDailyAbsenceCheck()
        guard AppSettings.shared.locationAlertsEnabled,
              AppSettings.shared.hasWorkplaceCoordinates,
              !AppSettings.shared.workDays.isEmpty else { return }

        let workedToday  = hasWorkedToday()
        let todayWeekday = Calendar.current.component(.weekday, from: Date())

        for weekday in AppSettings.shared.workDays {
            if workedToday && weekday == todayWeekday { continue }
            var comps = DateComponents()
            comps.weekday = weekday
            comps.hour = 18; comps.minute = 0
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: "\(missedDayID)_\(weekday)", content: missedDayContent(),
                                      trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
            )
        }

        if workedToday { scheduleNextMissedDayOneShot() }
    }

    func cancelDailyAbsenceCheck() {
        let ids = [missedDayID] + (1...7).map { "\(missedDayID)_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// True if there's any sign the user worked today — either the live clock in/out
    /// flow touched lastArrivalKey, or a shift entry (including one added retroactively
    /// via Manual Entry, or a vacation/sick day) already exists for today.
    private func hasWorkedToday() -> Bool {
        if ShiftStore.shared.hasShifts(on: Date()) { return true }
        let ts = UserDefaults.standard.double(forKey: lastArrivalKey)
        return ts > 0 && Calendar.current.isDateInToday(Date(timeIntervalSince1970: ts))
    }

    private func missedDayContent() -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Didn't make it to work today?"
        content.body  = "Tap to log a sick day, vacation, or formation day."
        content.sound = .default
        content.categoryIdentifier = categoryMissedDay
        return content
    }

    /// One-shot reminder for the next selected work day after today, since today's
    /// recurring occurrence was intentionally skipped in scheduleDailyAbsenceCheck().
    private func scheduleNextMissedDayOneShot() {
        let cal = Calendar.current
        var day = Date()
        for _ in 0..<7 {
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { return }
            day = next
            if AppSettings.shared.workDays.contains(cal.component(.weekday, from: day)) { break }
        }
        guard let nextWorkDayAt6 = cal.date(bySettingHour: 18, minute: 0, second: 0, of: day) else { return }
        let interval = max(60, nextWorkDayAt6.timeIntervalSinceNow)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: missedDayID, content: missedDayContent(),
                                  trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
        )
    }

    private func startRegion(center: CLLocationCoordinate2D) {
        guard clManager.authorizationStatus == .authorizedAlways else {
            DispatchQueue.main.async { self.isMonitoring = false }
            return
        }
        clManager.monitoredRegions
            .filter { $0.identifier == regionID }
            .forEach { clManager.stopMonitoring(for: $0) }

        let region = CLCircularRegion(center: center, radius: AppSettings.shared.geofenceRadius, identifier: regionID)
        region.notifyOnEntry = true
        region.notifyOnExit  = true
        clManager.startMonitoring(for: region)
        DispatchQueue.main.async { self.isMonitoring = true }

        // iOS only fires didEnterRegion when crossing INTO the region from outside.
        // If the user enables alerts / sets their workplace while already at the
        // office, no arrival event ever fires. Ask for the current state now so we
        // can still prompt a clock-in when they're already inside the geofence.
        clManager.requestState(for: region)
    }

    /// Fires the arrival prompt + notification, guarding against duplicates.
    /// Shared by both the live entry event and the initial state check.
    private func handleArrival() {
        // Don't notify if already clocked in
        if ShiftStore.shared.activeShiftStart != nil { return }

        // Cooldown: suppress duplicate arrival alerts within 30 minutes (GPS jitter)
        let lastArrival = UserDefaults.standard.double(forKey: lastArrivalKey)
        if lastArrival > 0, Date().timeIntervalSince1970 - lastArrival < 1800 { return }

        AlertLog.shared.addArrival()
        markWorkedToday()
        cancelDailyAbsenceCheck()
        deliver(
            title: "You've arrived at work!",
            body: "Tap to clock in, or use the Clock In button.",
            id: "arrive_\(Int(Date().timeIntervalSince1970))",
            category: categoryArrive
        )
    }

    /// Fires the departure prompt + notification, guarding against duplicates the same
    /// way handleArrival() does — GPS jitter right at the geofence boundary can cause
    /// didExitRegion to fire more than once for the same real-world exit.
    private func handleDeparture() {
        // Nothing to clock out of if not currently clocked in — without this, clocking
        // out manually (e.g. from the Home button) and then walking out the door moments
        // later still fires a redundant "time to clock out" notification.
        guard ShiftStore.shared.activeShiftStart != nil else { return }

        let lastDeparture = UserDefaults.standard.double(forKey: lastDepartureKey)
        if lastDeparture > 0, Date().timeIntervalSince1970 - lastDeparture < 1800 { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastDepartureKey)

        AlertLog.shared.addDeparture()
        markWorkedToday()
        scheduleDailyAbsenceCheck()
        deliver(
            title: "You've left work!",
            body: "Tap to clock out, or use the Clock Out button.",
            id: "depart_\(Int(Date().timeIntervalSince1970))",
            category: categoryDepart
        )
    }

    private func deliver(title: String, body: String, id: String,
                         category: String? = nil, delaySeconds: TimeInterval = 0) {
        let content            = UNMutableNotificationContent()
        content.title          = title
        content.body           = body
        content.sound          = .default
        if let category { content.categoryIdentifier = category }
        let trigger = delaySeconds > 0
            ? UNTimeIntervalNotificationTrigger(timeInterval: delaySeconds, repeats: false)
            : nil
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "ss_\(id)", content: content, trigger: trigger)
        )
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { self.authStatus = manager.authorizationStatus }
        switch manager.authorizationStatus {
        case .authorizedAlways:
            if AppSettings.shared.locationAlertsEnabled,
               AppSettings.shared.hasWorkplaceCoordinates {
                restoreMonitoring()
            }
        case .authorizedWhenInUse:
            // Second call shows the "Always Allow" upgrade prompt on iOS 13+
            if AppSettings.shared.locationAlertsEnabled {
                manager.requestAlwaysAuthorization()
            }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == regionID else { return }
        handleArrival()
    }

    /// Called in response to `requestState(for:)` right after monitoring starts.
    /// Lets us prompt a clock-in when the user is already inside the geofence
    /// (e.g. they set their workplace or enabled alerts while at the office).
    func locationManager(_ manager: CLLocationManager,
                         didDetermineState state: CLRegionState,
                         for region: CLRegion) {
        guard region.identifier == regionID, state == .inside else { return }
        handleArrival()
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == regionID else { return }
        handleDeparture()
    }

    func locationManager(_ manager: CLLocationManager,
                         monitoringDidFailFor region: CLRegion?,
                         withError error: Error) {
        DispatchQueue.main.async { self.isMonitoring = false }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension LocationManager: UNUserNotificationCenterDelegate {
    // Show banner even when app is in foreground (suppress missed-day if user was at work today)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if notification.request.content.categoryIdentifier == categoryMissedDay, hasWorkedToday() {
            completionHandler([]) // user was at work today — hide it
            return
        }
        completionHandler([.banner, .sound])
    }

    // Handle action button taps AND banner taps — works even when app is closed
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let category = response.notification.request.content.categoryIdentifier
        DispatchQueue.main.async {
            switch response.actionIdentifier {
            case self.actionClockIn:
                // Action button tapped — clock in immediately
                ShiftStore.shared.clockIn()
            case self.actionClockOut:
                // Action button tapped — clock out immediately
                ShiftStore.shared.clockOut()
            case UNNotificationDefaultActionIdentifier:
                // Banner tapped — ask the user in-app
                if category == self.categoryArrive {
                    self.pendingClockAction = .clockIn
                } else if category == self.categoryDepart {
                    self.pendingClockAction = .clockOut
                } else if category == self.categoryMissedDay {
                    // Only prompt if user wasn't at work today
                    if !self.hasWorkedToday() {
                        self.pendingClockAction = .logDayOff
                    }
                }
            default:
                break
            }
        }
        completionHandler()
    }
}
