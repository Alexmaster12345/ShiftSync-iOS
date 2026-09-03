import Foundation
import Combine
import WatchConnectivity
import UserNotifications

final class WatchShiftManager: NSObject, ObservableObject {
    static let shared = WatchShiftManager()

    @Published var isClockedIn: Bool = false
    @Published var shiftStartTime: Date? = nil
    @Published var earningsToday: Double = 0
    @Published var isReachable: Bool = false
    @Published var actionSent: Bool = false
    @Published var testSent: Bool = false
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
        refreshNotificationStatus()
    }

    func clockIn()  { send(action: "clockIn") }
    func clockOut() { send(action: "clockOut") }

    // MARK: - Notifications

    /// Ask for permission to show notifications directly on the watch.
    func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
                self?.refreshNotificationStatus()
            }
    }

    /// Re-reads the current watch notification authorization status from the system.
    /// Use this to check whether the user actually enabled notifications for the
    /// watch app (Settings app on the watch, or Watch app on the iPhone can turn it off).
    func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationStatus = settings.authorizationStatus
            }
        }
    }

    /// Fires a local notification on the watch to verify watch alerts work.
    func sendTestNotification() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                guard let self else { return }
                self.refreshNotificationStatus()
                guard granted else { return }
                let content   = UNMutableNotificationContent()
                content.title = "ShiftSync ⌚️"
                content.body  = "Watch notifications are working ✓"
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "watch_test_\(Int(Date().timeIntervalSince1970))",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                )
                UNUserNotificationCenter.current().add(request)
                DispatchQueue.main.async {
                    self.testSent = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.testSent = false }
                }
            }
    }

    private func send(action: String) {
        guard WCSession.default.isReachable else {
            fireClockNotification(success: false, action: action)
            return
        }
        actionSent = true
        WCSession.default.sendMessage(
            ["action": action],
            replyHandler: { [weak self] _ in
                self?.fireClockNotification(success: true, action: action)
            },
            errorHandler: { [weak self] _ in
                self?.fireClockNotification(success: false, action: action)
            }
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.actionSent = false }
    }

    /// Fires a local notification on the watch confirming the Clock In / Clock Out
    /// button press succeeded (or failed to reach the iPhone), so the user gets
    /// feedback directly on their wrist without needing to look at the phone.
    private func fireClockNotification(success: Bool, action: String) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                self?.refreshNotificationStatus()
                guard granted else { return }
                let content = UNMutableNotificationContent()
                if success {
                    switch action {
                    case "clockIn":
                        content.title = "Clocked In ✓"
                        content.body  = "Your shift has started."
                    case "clockOut":
                        content.title = "Clocked Out ✓"
                        content.body  = "Your shift has ended. Nice work!"
                    default:
                        content.title = "ShiftSync"
                        content.body  = "Action completed."
                    }
                } else {
                    content.title = action == "clockIn" ? "Clock In Failed" : "Clock Out Failed"
                    content.body  = "Couldn't reach your iPhone. Make sure it's nearby and try again."
                }
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "watch_clock_\(action)_\(Int(Date().timeIntervalSince1970))",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
                )
                UNUserNotificationCenter.current().add(request)
            }
    }

    // MARK: - Notification status helpers

    var notificationStatusLabel: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return "Notifications On ✓"
        case .denied:                               return "Notifications Off ✗"
        case .notDetermined:                        return "Not Set Up"
        @unknown default:                           return "Unknown"
        }
    }

    var notificationStatusMessage: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
            return "Notifications are enabled on this Apple Watch."
        case .denied:
            return "Notifications are turned off for ShiftSync on this watch.\n\nOpen the Settings app on your Apple Watch → Notifications → ShiftSync, and turn on Allow Notifications.\n\nYou can also manage this from the Watch app on your iPhone → My Watch → Notifications."
        case .notDetermined:
            return "Notification permission hasn't been decided yet. Tap Allow when prompted."
        @unknown default:
            return "Unable to determine notification status."
        }
    }
}

extension WatchShiftManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        let reachable = session.isReachable
        let ctx = session.receivedApplicationContext
        DispatchQueue.main.async { self.isReachable = reachable }
        if !ctx.isEmpty { apply(ctx) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        DispatchQueue.main.async { self.isReachable = reachable }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext ctx: [String: Any]) {
        apply(ctx)
    }

    // Handles requests sent from the phone (e.g. "trigger a test notification here").
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any],
                             replyHandler: @escaping ([String: Any]) -> Void) {
        switch message["action"] as? String {
        case "testNotification":
            DispatchQueue.main.async { self.sendTestNotification() }
        default:
            break
        }
        replyHandler(["received": true])
    }

    // Handles background-queued requests (transferUserInfo) sent when sendMessage
    // couldn't be delivered live because the watch wasn't reachable at the time.
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        switch userInfo["action"] as? String {
        case "testNotification":
            DispatchQueue.main.async { self.sendTestNotification() }
        default:
            break
        }
    }

    private nonisolated func apply(_ ctx: [String: Any]) {
        let clockedIn  = ctx["isClockedIn"] as? Bool ?? false
        let earnings   = ctx["earningsToday"] as? Double ?? 0
        let startDate  = (ctx["shiftStartTime"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        DispatchQueue.main.async {
            self.isClockedIn   = clockedIn
            self.earningsToday = earnings
            self.shiftStartTime = startDate
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension WatchShiftManager: UNUserNotificationCenterDelegate {
    // Show the banner + play sound even when the watch app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
