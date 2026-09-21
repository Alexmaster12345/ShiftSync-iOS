import Combine
import LocalAuthentication
import SwiftUI

// Opt-in app lock (Profile > Security & Privacy). Gates the whole app behind
// Face ID / Touch ID / device passcode — deliberately uses .deviceOwnerAuthentication
// (not .deviceOwnerAuthenticationWithBiometrics) so it falls back to the passcode
// automatically instead of us building a custom fallback UI.
final class AppLockManager: ObservableObject {
    static let shared = AppLockManager()

    @Published var isUnlocked = true

    // Call when the app leaves the foreground, so the next return to active
    // requires re-authentication if App Lock is on.
    func lock() {
        guard AppSettings.shared.appLockEnabled else { return }
        isUnlocked = false
    }

    func authenticate() {
        guard AppSettings.shared.appLockEnabled, !isUnlocked else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode set on the device at all — nothing to lock with, so don't
            // strand the user behind a lock screen they have no way to open.
            isUnlocked = true
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock ShiftSync to view your shifts and earnings.") { success, _ in
            DispatchQueue.main.async {
                self.isUnlocked = success
            }
        }
    }
}

struct AppLockOverlay: View {
    @ObservedObject var lock = AppLockManager.shared

    var body: some View {
        ZStack {
            Color.darkBg.ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.shiftBlue)
                Text("ShiftSync is Locked")
                    .font(.ss(20, weight: .bold))
                    .foregroundColor(.ssTextPrimary)
                Button(action: { lock.authenticate() }) {
                    Text("Unlock")
                        .font(.ss(16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.shiftBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .onAppear { lock.authenticate() }
    }
}
