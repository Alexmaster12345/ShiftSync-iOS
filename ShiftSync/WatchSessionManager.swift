import Foundation
import WatchConnectivity
import Combine
import UIKit

// Bridges ShiftStore state to the Apple Watch and handles clock commands from it.
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var isWatchReachable: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var watchTestResult: String? = nil
    @Published var isPaired: Bool = false
    @Published var activationState: WCSessionActivationState = .notActivated

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        self.isPaired = WCSession.default.isPaired
        self.isWatchAppInstalled = WCSession.default.isWatchAppInstalled
        WCSession.default.activate()
    }

    // Call this after every clockIn / clockOut / state change.
    func sendStateUpdate() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }
        let store = ShiftStore.shared
        var ctx: [String: Any] = [
            "isClockedIn": store.activeShiftStart != nil
        ]
        if let start = store.activeShiftStart {
            ctx["shiftStartTime"] = start.timeIntervalSince1970
        }
        let cal = Calendar.current
        let todayPay = store.entries
            .filter { cal.isDateInToday($0.startedAt) }
            .reduce(0.0) { $0 + $1.estimatedPay }
        ctx["earningsToday"] = todayPay

        try? WCSession.default.updateApplicationContext(ctx)
    }

    /// Asks the paired Apple Watch to fire a local test notification on itself,
    /// so notifications can be verified independently of the phone.
    func sendTestNotificationToWatch() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else {
            watchTestResult = "Watch connectivity isn't available on this device."
            return
        }
        let session = WCSession.default
        self.isPaired = session.isPaired

        guard session.isPaired else {
            watchTestResult = "No Apple Watch is paired with this iPhone."
            return
        }

        // WCErrorCodeWatchAppNotInstalled in the console is an authoritative signal
        // (not a stale flag) — the ShiftSync watch app genuinely isn't installed on
        // the paired watch. Calling sendMessage/updateApplicationContext/transferUserInfo
        // anyway just spams that error, so stop here and tell the user how to fix it.
        guard session.isWatchAppInstalled else {
            watchTestResult = "ShiftSync isn't installed on your Apple Watch yet.\n\nOpen the Watch app on your iPhone → My Watch → scroll to ShiftSync → tap Install.\n\nIf you're testing in Xcode/Simulator, run the \"ShiftSync Watch app Watch App\" scheme at least once so it gets installed on the paired watch."
            _ = self.openWatchAppManagePage()
            return
        }

        if session.isReachable {
            // Live, immediate delivery.
            session.sendMessage(
                ["action": "testNotification"],
                replyHandler: { [weak self] _ in
                    DispatchQueue.main.async { self?.watchTestResult = "Test notification sent to your Apple Watch ✓" }
                },
                errorHandler: { [weak self] error in
                    // Fall back to a guaranteed background delivery instead of just failing.
                    self?.transferTestNotificationInBackground()
                }
            )
        } else {
            // Not reachable right now (locked, out of range, app not foregrounded) —
            // queue a guaranteed background transfer instead of failing outright.
            transferTestNotificationInBackground()
        }
    }

    /// Queues the test-notification request via transferUserInfo, which iOS delivers
    /// in the background and wakes the watch app to process it — even when
    /// sendMessage can't be used because the watch isn't live-reachable.
    private func transferTestNotificationInBackground() {
        guard WCSession.default.isWatchAppInstalled else { return }
        WCSession.default.transferUserInfo(["action": "testNotification"])
        DispatchQueue.main.async {
            self.watchTestResult = "Apple Watch isn't reachable right now, so the test was queued — it'll arrive once your watch reconnects."
        }
    }

    /// Attempts to open the Watch app's My Watch tab to help the user install the companion app.
    /// Returns true if the system accepted the request to open the Watch app.
    @discardableResult
    func openWatchAppManagePage() -> Bool {
        guard let url = URL(string: "itms-watchs://") else { return false }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        return true
    }
}

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.activationState = activationState
            self.isPaired = session.isPaired
            self.sendStateUpdate()
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isPaired = session.isPaired
        }
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
            self.isWatchAppInstalled = session.isWatchAppInstalled
            self.isPaired = session.isPaired
            self.sendStateUpdate()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            switch message["action"] as? String {
            case "clockIn":  ShiftStore.shared.clockIn()
            case "clockOut": ShiftStore.shared.clockOut()
            default: break
            }
            self.sendStateUpdate()
        }
    }

    // Reply-based variant: the watch now sends clockIn/clockOut with a replyHandler
    // so it can confirm success/failure with its own local notification. Without
    // implementing this, sendMessage on the watch always times out and reports
    // failure, even when the clock action actually succeeded.
    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            switch message["action"] as? String {
            case "clockIn":  ShiftStore.shared.clockIn()
            case "clockOut": ShiftStore.shared.clockOut()
            default: break
            }
            self.sendStateUpdate()
            replyHandler(["received": true])
        }
    }
}
