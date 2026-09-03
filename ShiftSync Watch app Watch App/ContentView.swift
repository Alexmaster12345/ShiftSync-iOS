import SwiftUI

struct WatchContentView: View {
    @EnvironmentObject private var manager: WatchShiftManager
    @State private var showNotificationAlert = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ScrollView {
                VStack(spacing: 8) {
                    statusIcon
                    if manager.isClockedIn {
                        elapsedLabel
                    }
                    actionButton
                    earningsLabel
                    testNotificationButton
                    notificationSettingsButton
                    if !manager.isReachable {
                        Text("iPhone not reachable")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .alert(manager.notificationStatusLabel, isPresented: $showNotificationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(manager.notificationStatusMessage)
        }
    }

    private var statusIcon: some View {
        VStack(spacing: 4) {
            Image(systemName: manager.isClockedIn ? "clock.fill" : "clock")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(manager.isClockedIn ? .green : .secondary)
            Text(manager.isClockedIn ? "On Shift" : "Off Shift")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(manager.isClockedIn ? .green : .secondary)
        }
    }

    private var elapsedLabel: some View {
        Text(elapsedString)
            .font(.system(size: 20, weight: .bold, design: .monospaced))
            .foregroundColor(.white)
    }

    private var actionButton: some View {
        Button(action: {
            if manager.isClockedIn { manager.clockOut() }
            else { manager.clockIn() }
        }) {
            Text(manager.actionSent ? "Sent ✓" :
                 (manager.isClockedIn ? "Clock Out" : "Clock In"))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    manager.actionSent ? Color.gray :
                    (manager.isClockedIn ? Color.red : Color.blue)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!manager.isReachable || manager.actionSent)
    }

    private var earningsLabel: some View {
        Group {
            if manager.earningsToday > 0 {
                Text(String(format: "Today: %.2f", manager.earningsToday))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var testNotificationButton: some View {
        Button(action: { manager.sendTestNotification() }) {
            Label(manager.testSent ? "Sent ✓" : "Test Notification",
                  systemImage: manager.testSent ? "checkmark.circle.fill" : "bell.badge")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(manager.testSent ? Color.green : Color.orange)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(manager.testSent)
    }

    private var notificationSettingsButton: some View {
        Button(action: {
            manager.refreshNotificationStatus()
            showNotificationAlert = true
        }) {
            Label("Notification Settings", systemImage: "gearshape.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.blue.opacity(0.8))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var elapsedString: String {
        guard let start = manager.shiftStartTime else { return "00:00:00" }
        let t = Int(Date().timeIntervalSince(start))
        let h = t / 3600
        let m = (t % 3600) / 60
        let s = t % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
