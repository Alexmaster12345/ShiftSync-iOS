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
    func session(_ session: WCSession,
                 activationDidCompleteWith state: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { self.isReachable = session.isReachable }
        if !session.receivedApplicationContext.isEmpty {
            apply(session.receivedApplicationContext)
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.isReachable = session.isReachable }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext ctx: [String: Any]) {
        apply(ctx)
    }

    private func apply(_ ctx: [String: Any]) {
        DispatchQueue.main.async {
            self.isClockedIn   = ctx["isClockedIn"] as? Bool ?? false
            self.earningsToday = ctx["earningsToday"] as? Double ?? 0
            if let ts = ctx["shiftStartTime"] as? TimeInterval {
                self.shiftStartTime = Date(timeIntervalSince1970: ts)
            } else {
                self.shiftStartTime = nil
            }
        }
    }
}
