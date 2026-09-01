import Foundation
import Combine
import WatchConnectivity

final class WatchShiftManager: NSObject, ObservableObject {
    static let shared = WatchShiftManager()

    @Published var isClockedIn: Bool = false
    @Published var shiftStartTime: Date? = nil
    @Published var earningsToday: Double = 0
    @Published var isReachable: Bool = false
    @Published var actionSent: Bool = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func clockIn()  { send(["action": "clockIn"]) }
    func clockOut() { send(["action": "clockOut"]) }

    private func send(_ message: [String: Any]) {
        guard WCSession.default.isReachable else { return }
        actionSent = true
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { self.actionSent = false }
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
