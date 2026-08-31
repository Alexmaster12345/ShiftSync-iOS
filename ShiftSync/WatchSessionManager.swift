import Foundation
import WatchConnectivity

// Bridges ShiftStore state to the Apple Watch and handles clock commands from it.
final class WatchSessionManager: NSObject {
    static let shared = WatchSessionManager()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // Call this after every clockIn / clockOut / state change.
    func sendStateUpdate() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated else { return }
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
}

extension WatchSessionManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { self.sendStateUpdate() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
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
}
