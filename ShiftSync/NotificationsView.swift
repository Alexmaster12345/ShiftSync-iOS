import SwiftUI
import Combine

// MARK: - Log Model

struct AlertLogEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var isArrival: Bool   // true = arrived at work, false = left work
    var actedOn: Bool = false
}

class AlertLog: ObservableObject {
    static let shared = AlertLog()
    @Published var entries: [AlertLogEntry] = []
    private let key = "ss_alert_log_v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode([AlertLogEntry].self, from: data) {
            entries = saved
        }
    }

    func addArrival() {
        add(AlertLogEntry(date: Date(), isArrival: true))
    }

    func addDeparture() {
        add(AlertLogEntry(date: Date(), isArrival: false))
    }

    func markActedOn(_ id: UUID) {
        if let idx = entries.firstIndex(where: { $0.id == id }) {
            entries[idx].actedOn = true
            save()
        }
    }

    func clearAll() {
        entries = []
        save()
    }

    var unreadCount: Int { entries.filter { !$0.actedOn }.count }

    private func add(_ entry: AlertLogEntry) {
        entries.insert(entry, at: 0)
        if entries.count > 50 { entries = Array(entries.prefix(50)) }
        save()
    }

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(entries), forKey: key)
    }
}

// MARK: - View

struct NotificationsView: View {
    @ObservedObject private var log   = AlertLog.shared
    @ObservedObject private var store = ShiftStore.shared
    @Binding var isPresented: Bool

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        NavigationStack {
            Group {
                if log.entries.isEmpty {
                    emptyState
                } else {
                    notificationList
                }
            }
            .background(Color.darkBg.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                        .foregroundColor(.shiftBlue)
                }
                if !log.entries.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear") { log.clearAll() }
                            .foregroundColor(.ssTextMuted)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            // Mark all as read when panel is opened
            log.entries.indices.forEach { log.entries[$0].actedOn = true }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(.ssTextMuted)
            Text("No alerts yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.ssTextSecondary)
            Text("Arrival and departure alerts will appear here.")
                .font(.system(size: 13))
                .foregroundColor(.ssTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List

    private var notificationList: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Current shift status card
                currentStatusCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Alert log entries
                ForEach(log.entries) { entry in
                    alertRow(entry)
                        .padding(.horizontal, 16)
                }

                Spacer().frame(height: 24)
            }
        }
    }

    private var currentStatusCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(store.activeShiftStart != nil ? Color.greenAccent.opacity(0.15) : Color.shiftBlue.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: store.activeShiftStart != nil ? "checkmark.circle.fill" : "clock")
                    .font(.system(size: 20))
                    .foregroundColor(store.activeShiftStart != nil ? .greenAccent : .shiftBlue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(store.activeShiftStart != nil ? "Currently clocked in" : "Not clocked in")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.ssTextPrimary)
                if let start = store.activeShiftStart {
                    let mins = max(0, Int(Date().timeIntervalSince(start) / 60))
                    Text("Shift in progress · \(formatDuration(mins))")
                        .font(.system(size: 12))
                        .foregroundColor(.ssTextSecondary)
                } else {
                    Text("Tap Clock In below or on the Home screen")
                        .font(.system(size: 12))
                        .foregroundColor(.ssTextMuted)
                }
            }
            Spacer()
            Button(action: {
                if store.activeShiftStart != nil { store.clockOut() } else { store.clockIn() }
            }) {
                Text(store.activeShiftStart != nil ? "Clock Out" : "Clock In")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(store.activeShiftStart != nil ? Color.redAccent : Color.shiftBlue)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func alertRow(_ entry: AlertLogEntry) -> some View {
        let isArrival = entry.isArrival
        let color: Color = isArrival ? .greenAccent : .orangeAccent
        let icon  = isArrival ? "mappin.circle.fill" : "figure.walk"
        let title = isArrival ? "Arrived at work" : "Left work"
        let actionLabel = isArrival ? "Clock In" : "Clock Out"
        let alreadyActed = isArrival
            ? (store.activeShiftStart != nil)   // arrival → clocked in
            : (store.activeShiftStart == nil)   // departure → clocked out

        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.ssTextPrimary)
                Text(timeFormatter.string(from: entry.date))
                    .font(.system(size: 11))
                    .foregroundColor(.ssTextMuted)
            }

            Spacer()

            if alreadyActed {
                Label("Done", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.greenAccent)
            } else {
                Button(action: {
                    if isArrival { store.clockIn() } else { store.clockOut() }
                    log.markActedOn(entry.id)
                }) {
                    Text(actionLabel)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isArrival ? Color.shiftBlue : Color.orangeAccent)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    NotificationsView(isPresented: .constant(true))
}
