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

    /// Schedule a repeating 6 PM notification for days the user isn't at the workplace.
    func scheduleDailyAbsenceCheck() {
        guard AppSettings.shared.locationAlertsEnabled,
              AppSettings.shared.hasWorkplaceCoordinates else { return }
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }
            guard !requests.contains(where: { $0.identifier == self.missedDayID }) else { return }
            var comps = DateComponents()
            comps.hour = 18; comps.minute = 0
            let content            = UNMutableNotificationContent()
            content.title          = "Didn't make it to work today?"
            content.body           = "Tap to log a sick day, vacation, or formation day."
            content.sound          = .default
            content.categoryIdentifier = self.categoryMissedDay
            UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: self.missedDayID, content: content,
                                      trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
            )
        }
    }

    func cancelDailyAbsenceCheck() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [missedDayID])
    }

    private func startRegion(center: CLLocationCoordinate2D) {
        guard clManager.authorizationStatus == .authorizedAlways else {
            DispatchQueue.main.async { self.isMonitoring = false }
            return
        }
        clManager.monitoredRegions
            .filter { $0.identifier == regionID }
            .forEach { clManager.stopMonitoring(for: $0) }

        let region = CLCircularRegion(center: center, radius: 75, identifier: regionID)
        region.notifyOnEntry = true
        region.notifyOnExit  = true
        clManager.startMonitoring(for: region)
        DispatchQueue.main.async { self.isMonitoring = true }
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
        AlertLog.shared.addArrival()
        // Record today as a worked day and suppress the absence notification
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastArrivalKey)
        cancelDailyAbsenceCheck()
        deliver(
            title: "You've arrived at work!",
            body: "Tap to clock in, or use the Clock In button.",
            id: "arrive_\(Int(Date().timeIntervalSince1970))",
            category: categoryArrive
        )
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == regionID else { return }
        AlertLog.shared.addDeparture()
        // Re-enable the daily absence check for future days
        scheduleDailyAbsenceCheck()
        deliver(
            title: "You've left work!",
            body: "Tap to clock out, or use the Clock Out button.",
            id: "depart_\(Int(Date().timeIntervalSince1970))",
            category: categoryDepart
        )
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
        if notification.request.content.categoryIdentifier == categoryMissedDay {
            let ts = UserDefaults.standard.double(forKey: lastArrivalKey)
            if ts > 0 && Calendar.current.isDateInToday(Date(timeIntervalSince1970: ts)) {
                completionHandler([]) // user was at work today — hide it
                return
            }
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
                    let ts = UserDefaults.standard.double(forKey: self.lastArrivalKey)
                    if ts == 0 || !Calendar.current.isDateInToday(Date(timeIntervalSince1970: ts)) {
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
