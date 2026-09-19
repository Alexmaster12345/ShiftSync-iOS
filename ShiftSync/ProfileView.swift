import SwiftUI
import WatchConnectivity
import UniformTypeIdentifiers

struct ProfileView: View {
    let userName: String
    @ObservedObject var store: ShiftStore
    @ObservedObject private var settings = AppSettings.shared
    let onLogout: () -> Void

    @State private var rateText: String = ""
    @FocusState private var rateFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)

                // Avatar card
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [.shiftBlue, .shiftBlueDark],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 88, height: 88)
                            .shadow(color: Color.shiftBlue.opacity(0.3), radius: 8, y: 4)
                        Text(String(userName.prefix(1)).uppercased())
                            .font(.ss(36, weight: .bold)).foregroundColor(.white)
                    }
                    Text(userName).font(.ss(22, weight: .bold)).foregroundColor(.ssTextPrimary)
                    let role = [settings.jobTitle, settings.branch]
                        .filter { !$0.isEmpty }.joined(separator: "  •  ")
                    if !role.isEmpty {
                        Text(role).font(.ss(14)).foregroundColor(.ssTextSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // ── App Settings ─────────────────────────────────────────
                settingsSection(title: "APP SETTINGS") {
                    navRow(icon: "moon.circle.fill", label: "Appearance", color: .shiftBlue, destination: AnyView(AppearanceView()))
                    Divider().background(Color.darkBg)
                    navRow(icon: "bell.circle.fill", label: "Notifications", color: .orangeAccent, destination: AnyView(NotificationPrefsView()))
                    Divider().background(Color.darkBg)
                    navRow(icon: "person.circle.fill", label: "Personal Info", color: .shiftBlue, destination: AnyView(PersonalInfoView(userName: userName)))
                }

                // ── Work Rules ───────────────────────────────────────────
                settingsSection(title: "WORK RULES") {
                    navRow(icon: "clock.badge.exclamationmark.fill", label: "Overtime Rules", color: .orangeAccent, destination: AnyView(OvertimeRulesView(store: store)))
                    Divider().background(Color.darkBg)
                    navRow(icon: "square.and.arrow.up.fill", label: "Export Reports", color: .tealAccent, destination: AnyView(ExportView(store: store)))
                }

                // ── Security ─────────────────────────────────────────────
                settingsSection(title: "SECURITY & PRIVACY") {
                    navRow(icon: "lock.shield.fill", label: "Security & Privacy", color: .shiftBlue, destination: AnyView(SecurityPrivacyView(store: store, onLogout: onLogout)))
                }

                // ── Help ─────────────────────────────────────────────────
                settingsSection(title: "HELP") {
                    navRow(icon: "book.fill", label: "How to Use ShiftSync", color: .shiftBlue, destination: AnyView(HowToUseView()))
                }

                // ── Legal ────────────────────────────────────────────────
                settingsSection(title: "LEGAL") {
                    navRow(icon: "doc.text.fill", label: "Terms of Use", color: .ssTextSecondary, destination: AnyView(TermsOfUseView()))
                    Divider().background(Color.darkBg)
                    navRow(icon: "hand.raised.fill", label: "Privacy Policy", color: .ssTextSecondary, destination: AnyView(PrivacyPolicyView()))
                }

                // ── Pay Settings ────────────────────────────────────────
                settingsSection(title: "PAY SETTINGS") {
                    navRow(icon: "bag.fill", label: "Salary & Currency", color: .greenAccent,
                           subtitle: salarySubtitle,
                           destination: AnyView(SalarySettingsView()))
                }

                // ── Vacation ────────────────────────────────────────────
                settingsSection(title: "VACATION") {
                    HStack(spacing: 12) {
                        settingIcon("beach.umbrella.fill", color: .tealAccent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Days per Year").font(.ss(15)).foregroundColor(.ssTextPrimary)
                            Text("\(store.vacationDaysUsed) used of \(settings.vacationDaysPerYear)")
                                .font(.ss(12)).foregroundColor(.ssTextSecondary)
                        }
                        Spacer()
                        HStack(spacing: 12) {
                            Button(action: { if settings.vacationDaysPerYear > 0 { settings.vacationDaysPerYear -= 1 } }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(settings.vacationDaysPerYear > 0 ? .shiftBlue : .ssTextMuted)
                            }
                            .accessibilityLabel("Decrease vacation days per year")
                            Text("\(settings.vacationDaysPerYear)")
                                .font(.ss(16, weight: .bold)).foregroundColor(.ssTextPrimary)
                                .lineLimit(1)
                                .fixedSize()
                                .frame(minWidth: 30, alignment: .center)
                            Button(action: { settings.vacationDaysPerYear += 1 }) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(.shiftBlue)
                            }
                            .accessibilityLabel("Increase vacation days per year")
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)

                    // Progress bar
                    let used     = store.vacationDaysUsed
                    let total    = max(1, settings.vacationDaysPerYear)
                    let progress = min(1.0, Double(used) / Double(total))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.darkBg).frame(height: 6)
                            RoundedRectangle(cornerRadius: 3).fill(Color.tealAccent)
                                .frame(width: geo.size.width * CGFloat(progress), height: 6)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }

                // ── Sign Out ─────────────────────────────────────────────
                settingsSection(title: "ACCOUNT") {
                    Button(action: onLogout) {
                        HStack(spacing: 12) {
                            settingIcon("rectangle.portrait.and.arrow.right", color: .redAccent)
                            Text("Sign Out")
                                .font(.ss(15)).foregroundColor(.redAccent)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                    }
                }

                // ── About ────────────────────────────────────────────────
                VStack(spacing: 2) {
                    Text("ShiftSync v\(appVersion)")
                        .font(.ss(12, weight: .medium))
                        .foregroundColor(.ssTextMuted)
                    Text("© 2026 ShiftSync. All rights reserved.")
                        .font(.ss(11))
                        .foregroundColor(.ssTextMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                Spacer().frame(height: tabBarBottomPadding)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var tabBarBottomPadding: CGFloat {
        let safeBottom = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first?.safeAreaInsets.bottom ?? 0
        return 82 + safeBottom
    }

    // MARK: - Helpers

    private var salarySubtitle: String {
        let rate = settings.paymentType == .hourly ? settings.hourlyRate : settings.monthlySalary
        let rateStr = String(format: "%.2f", rate)
        let unit = settings.paymentType == .hourly ? "HR" : "MO"
        let h = settings.workDayHours
        let hoursStr = h == h.rounded() ? "\(Int(h))H" : String(format: "%.1fH", h)
        return "\(settings.currency.symbol)\(rateStr)/\(unit) • \(settings.currency.displayName) • \(hoursStr) DAY"
    }

    private var rateString: String {
        let v = settings.paymentType == .hourly ? settings.hourlyRate : settings.monthlySalary
        return String(format: "%.2f", v)
    }

    private func applyRate() {
        guard let v = Double(rateText.replacingOccurrences(of: ",", with: ".")), v > 0 else { return }
        if settings.paymentType == .hourly { settings.hourlyRate = v } else { settings.monthlySalary = v }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.ss(17, weight: .bold)).foregroundColor(.ssTextPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.ss(11)).foregroundColor(.ssTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func settingIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).frame(width: 34, height: 34)
            Image(systemName: name).font(.system(size: 15)).foregroundColor(color)
        }
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.ss(11, weight: .semibold)).foregroundColor(.ssTextSecondary)
                .kerning(1).padding(.horizontal, 4).padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func settingsRow(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            settingIcon(icon, color: color)
            Text(label).font(.ss(15)).foregroundColor(.ssTextPrimary)
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(.ssTextMuted)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .overlay(Rectangle().fill(Color.darkBg.opacity(0.6)).frame(height: 0.5), alignment: .bottom)
    }

    private func navRow(icon: String, label: String, color: Color, subtitle: String? = nil, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                settingIcon(icon, color: color)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.ss(15)).foregroundColor(.ssTextPrimary)
                    if let subtitle {
                        Text(subtitle).font(.ss(12)).foregroundColor(.ssTextSecondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(.ssTextMuted)
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
        }
    }
}

// MARK: - Personal Info

struct PersonalInfoView: View {
    let userName: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @State private var displayName: String = ""
    @State private var email: String = ""
    @State private var jobTitle: String = ""
    @State private var branch: String = ""
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                navHeader(title: "Personal Info", dismiss: dismiss)

                // Avatar
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.shiftBlue, .shiftBlueDark],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 72, height: 72)
                    Text(String((displayName.isEmpty ? userName : displayName).prefix(1)).uppercased())
                        .font(.ss(28, weight: .bold)).foregroundColor(.white)
                }

                VStack(spacing: 0) {
                    infoField(icon: "person", label: "Display Name", placeholder: userName, text: $displayName)
                    Divider().background(Color.darkBg)
                    infoField(icon: "envelope", label: "Email", placeholder: "your@email.com", text: $email, keyboard: .emailAddress)
                    Divider().background(Color.darkBg)
                    infoField(icon: "briefcase", label: "Job Title", placeholder: "e.g. Senior Barista", text: $jobTitle)
                    Divider().background(Color.darkBg)
                    infoField(icon: "building.2", label: "Branch", placeholder: "e.g. Main Branch", text: $branch)
                }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button(action: saveChanges) {
                    Text(saved ? "Saved!" : "Save Changes")
                        .font(.ss(16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(saved ? Color.greenAccent : Color.shiftBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            displayName = UserDefaults.standard.string(forKey: "ss_user_name") ?? userName
            email       = settings.email
            jobTitle    = settings.jobTitle
            branch      = settings.branch
        }
    }

    private func saveChanges() {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty { UserDefaults.standard.set(name, forKey: "ss_user_name") }
        settings.email    = email.trimmingCharacters(in: .whitespaces)
        settings.jobTitle = jobTitle.trimmingCharacters(in: .whitespaces)
        settings.branch   = branch.trimmingCharacters(in: .whitespaces)
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { dismiss() }
    }

    private func infoField(icon: String, label: String, placeholder: String,
                           text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.shiftBlue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.ss(11, weight: .semibold)).foregroundColor(.ssTextMuted)
                TextField(placeholder, text: text)
                    .font(.ss(15)).foregroundColor(.ssTextPrimary)
                    .keyboardType(keyboard).autocorrectionDisabled()
                    .autocapitalization(.words)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - Security & Privacy

struct SecurityPrivacyView: View {
    @ObservedObject var store: ShiftStore
    let onLogout: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirm = false
    @State private var showImporter = false
    @State private var importAlertTitle = ""
    @State private var importAlertMessage = ""
    @State private var showImportAlert = false
    @State private var pendingImportData: Data? = nil
    @State private var pendingImportCount = 0
    @State private var showImportConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                navHeader(title: "Security & Privacy", dismiss: dismiss)

                // Privacy banner
                VStack(spacing: 0) {
                    privacyRow(icon: "lock.shield.fill", color: .shiftBlue,
                               title: "Data stored locally",
                               subtitle: "All shift data lives only on this device. Nothing is sent to external servers.")
                    Divider().background(Color.darkBg).padding(.leading, 62)
                    privacyRow(icon: "person.slash.fill", color: .tealAccent,
                               title: "No account required",
                               subtitle: "ShiftSync works without sign-up. Your data stays private and is never shared.")
                }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Data backup
                VStack(spacing: 0) {
                    Button(action: exportBackup) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.tealAccent.opacity(0.15)).frame(width: 38, height: 38)
                                Image(systemName: "square.and.arrow.up").font(.system(size: 15)).foregroundColor(.tealAccent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Export Backup (JSON)").font(.ss(15)).foregroundColor(.ssTextPrimary)
                                Text("Save your shift records to transfer to a new device")
                                    .font(.ss(12)).foregroundColor(.ssTextMuted)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(.ssTextMuted)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }

                    Divider().background(Color.darkBg).padding(.leading, 62)

                    Button(action: { showImporter = true }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.shiftBlue.opacity(0.15)).frame(width: 38, height: 38)
                                Image(systemName: "square.and.arrow.down").font(.system(size: 15)).foregroundColor(.shiftBlue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import Backup").font(.ss(15)).foregroundColor(.ssTextPrimary)
                                Text("Restore shift records from a previously exported file")
                                    .font(.ss(12)).foregroundColor(.ssTextMuted)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(.ssTextMuted)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Danger zone
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(Color.redAccent.opacity(0.15)).frame(width: 38, height: 38)
                            Image(systemName: "trash").font(.system(size: 15)).foregroundColor(.redAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear All Data").font(.ss(15)).foregroundColor(.redAccent)
                            Text("Deletes all shifts, settings, and profile info")
                                .font(.ss(12)).foregroundColor(.ssTextMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.ssTextMuted)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .contentShape(Rectangle())
                    .onTapGesture { showClearConfirm = true }
                }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .alert("Clear All Data?", isPresented: $showClearConfirm) {
            Button("Clear Everything", role: .destructive) {
                store.clearAll()
                AppSettings.shared.email    = ""
                AppSettings.shared.jobTitle = ""
                AppSettings.shared.branch   = ""
                onLogout()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all your shifts, settings, and profile info. This cannot be undone.")
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url), let count = store.peekBackupEntryCount(data) {
                    pendingImportData  = data
                    pendingImportCount = count
                    showImportConfirm  = true
                } else {
                    importAlertTitle   = "Import Failed"
                    importAlertMessage = "That file doesn't look like a valid ShiftSync backup."
                    showImportAlert    = true
                }
            case .failure:
                importAlertTitle   = "Import Failed"
                importAlertMessage = "Couldn't read that file."
                showImportAlert    = true
            }
        }
        .alert("Replace All Data?", isPresented: $showImportConfirm) {
            Button("Import & Replace", role: .destructive) {
                if let data = pendingImportData, store.importBackupData(data) {
                    importAlertTitle   = "Backup Restored"
                    importAlertMessage = "Your shift records have been restored from the backup file."
                } else {
                    importAlertTitle   = "Import Failed"
                    importAlertMessage = "That file doesn't look like a valid ShiftSync backup."
                }
                pendingImportData = nil
                showImportAlert = true
            }
            Button("Cancel", role: .cancel) { pendingImportData = nil }
        } message: {
            Text("This backup contains \(pendingImportCount) shift record\(pendingImportCount == 1 ? "" : "s"). Importing it will permanently replace all \(store.entries.count) shift\(store.entries.count == 1 ? "" : "s") currently on this device. This cannot be undone.")
        }
        .alert(importAlertTitle, isPresented: $showImportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importAlertMessage)
        }
    }

    private func exportBackup() {
        guard let data = store.exportBackupData() else { return }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShiftSync-Backup-\(df.string(from: Date())).json")
        try? data.write(to: url)
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(vc, animated: true)
        }
    }

    private func privacyRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.ss(15, weight: .semibold)).foregroundColor(.ssTextPrimary)
                Text(subtitle).font(.ss(12)).foregroundColor(.ssTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - Terms of Use

struct TermsOfUseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                navHeader(title: "Terms of Use", dismiss: dismiss)

                legalCard(
                    icon: "info.circle.fill", color: .shiftBlue,
                    title: "Informational Tool Only",
                    body: "ShiftSync is provided as a personal record-keeping tool to help you track your own shifts, hours, and estimated pay. It is not a substitute for your employer's official timekeeping or payroll system."
                )
                legalCard(
                    icon: "person.fill.checkmark", color: .orangeAccent,
                    title: "Your Responsibility",
                    body: "You are solely responsible for verifying the accuracy of any hours, pay calculations, or records logged in this app before relying on them for payroll, invoicing, tax, or any other employment-related purpose."
                )
                legalCard(
                    icon: "exclamationmark.shield.fill", color: .redAccent,
                    title: "Limitation of Liability",
                    body: "The developer of ShiftSync assumes no liability for payroll errors, missed or misrecorded shifts, incorrect pay calculations, or any employment disputes arising from use of this app. The app is provided \"as is\" without warranties of any kind."
                )
                legalCard(
                    icon: "location.fill", color: .tealAccent,
                    title: "Location & Notifications",
                    body: "Optional location-based reminders and notifications are generated entirely on your device to help you remember to clock in or out. They are provided for convenience only and should not be relied upon as your sole record of attendance."
                )

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Privacy Policy

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                navHeader(title: "Privacy Policy", dismiss: dismiss)

                legalCard(
                    icon: "checkmark.shield.fill", color: .greenAccent,
                    title: "No Data Is Collected",
                    body: "ShiftSync does not collect, transmit, or sell any personal data. There are no servers, no accounts, and no analytics or advertising SDKs in this app."
                )
                legalCard(
                    icon: "iphone", color: .shiftBlue,
                    title: "Everything Stays On Your Device",
                    body: "Shift entries, pay settings, your profile info, and your workplace location (if set) are stored only in this app's local storage on your device. This data is included in your standard iOS device backups (iCloud or computer), which are controlled by your iOS settings — not by this app."
                )
                legalCard(
                    icon: "location.fill", color: .tealAccent,
                    title: "Location Data",
                    body: "If you enable Workplace Geofencing, your location is used solely to detect arrival/departure at the workplace you set, entirely on-device, so the app can remind you to clock in or out. It is never transmitted anywhere."
                )
                legalCard(
                    icon: "square.and.arrow.up.on.square.fill", color: .orangeAccent,
                    title: "Your Choice to Export",
                    body: "The only way data leaves this app is if you explicitly export a report or backup file yourself (e.g. via AirDrop, email, or Files)."
                )

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - How to Use

struct HowToUseView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                navHeader(title: "How to Use ShiftSync", dismiss: dismiss)

                legalCard(
                    icon: "clock.fill", color: .shiftBlue,
                    title: "Clock In / Out",
                    body: "Tap Clock In on the Home screen to start a shift, and Clock Out when you're done. Pay is calculated live using your rate in Salary & Currency. Your Apple Watch mirrors clock in/out confirmations automatically."
                )
                legalCard(
                    icon: "square.and.pencil", color: .tealAccent,
                    title: "Manual Entry & Day Types",
                    body: "Tap the + button to log a shift after the fact, or record Vacation, Sick, Formation, Holiday, or Company Fun Day time off over a date range. Tap any entry on Home or Calendar to edit or delete it."
                )
                legalCard(
                    icon: "banknote.fill", color: .greenAccent,
                    title: "Pay & Overtime",
                    body: "Set your hourly or monthly rate, currency, and work day hours in Profile → Salary & Currency. Turn on Overtime Rules to automatically split shifts into regular + overtime pay once your daily threshold is exceeded."
                )
                legalCard(
                    icon: "calendar", color: .orangeAccent,
                    title: "Calendar & Export",
                    body: "The Calendar tab shows every logged shift by day. Profile → Export Reports lets you generate a CSV or PDF report for a custom date range to share or file."
                )
                legalCard(
                    icon: "location.fill", color: .redAccent,
                    title: "Workplace Alerts",
                    body: "Set your workplace on the map (Workplace tab) to get notified when you arrive or leave, with one-tap clock in/out right from the notification. Adjust the detection radius if alerts fire too early or late."
                )
                legalCard(
                    icon: "house.fill", color: .shiftBlue,
                    title: "Work From Home",
                    body: "No office to detect? Profile → Notifications → Work From Home lets you set fixed Clock In / Clock Out times instead, reminding you on your selected Work Days without needing a workplace location."
                )
                legalCard(
                    icon: "arrow.up.arrow.down.square.fill", color: .tealAccent,
                    title: "Backup Your Data",
                    body: "Profile → Security & Privacy → Export Backup saves all your shift records to a JSON file. Import it on another device to pick up right where you left off."
                )

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

private func legalCard(icon: String, color: Color, title: String, body: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).frame(width: 38, height: 38)
            Image(systemName: icon).font(.system(size: 15)).foregroundColor(color)
        }
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.ss(15, weight: .semibold)).foregroundColor(.ssTextPrimary)
            Text(body).font(.ss(13)).foregroundColor(.ssTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
    }
    .padding(14)
    .background(Color.darkCard)
    .clipShape(RoundedRectangle(cornerRadius: 16))
}

// MARK: - Notification Preferences

struct NotificationPrefsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                navHeader(title: "Notifications", dismiss: dismiss)

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(Color.orangeAccent.opacity(0.15)).frame(width: 34, height: 34)
                            Image(systemName: "bell.badge").font(.system(size: 14)).foregroundColor(.orangeAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Arrival & Departure Alerts").font(.ss(15)).foregroundColor(.ssTextPrimary)
                            Text(settings.locationAlertsEnabled ? "On — notified when you arrive or leave work" : "Off")
                                .font(.ss(12))
                                .foregroundColor(settings.locationAlertsEnabled ? .greenAccent : .ssTextMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.locationAlertsEnabled)
                            .tint(.shiftBlue)
                            .onChange(of: settings.locationAlertsEnabled) { _, enabled in
                                if enabled {
                                    locationManager.requestPermissions()
                                    if settings.hasWorkplaceCoordinates { locationManager.restoreMonitoring() }
                                    locationManager.scheduleDailyAbsenceCheck()
                                } else {
                                    locationManager.stopMonitoring()
                                    locationManager.cancelDailyAbsenceCheck()
                                }
                            }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)

                    Divider().background(Color.darkBg)
                }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Work From Home
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(Color.tealAccent.opacity(0.15)).frame(width: 34, height: 34)
                            Image(systemName: "house.fill").font(.system(size: 14)).foregroundColor(.tealAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Work From Home").font(.ss(15)).foregroundColor(.ssTextPrimary)
                            Text(settings.workFromHomeEnabled ? "On — reminded to clock in/out at set times" : "Off")
                                .font(.ss(12))
                                .foregroundColor(settings.workFromHomeEnabled ? .greenAccent : .ssTextMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.workFromHomeEnabled)
                            .tint(.shiftBlue)
                            .onChange(of: settings.workFromHomeEnabled) { _, enabled in
                                if enabled {
                                    locationManager.requestNotificationPermission()
                                    locationManager.scheduleWorkFromHomeReminders()
                                } else {
                                    locationManager.cancelWorkFromHomeReminders()
                                }
                            }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)

                    if settings.workFromHomeEnabled {
                        Divider().background(Color.darkBg)

                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.orangeAccent.opacity(0.15)).frame(width: 34, height: 34)
                                Image(systemName: "sunrise.fill").font(.system(size: 14)).foregroundColor(.orangeAccent)
                            }
                            Text("Clock In Time").font(.ss(15)).foregroundColor(.ssTextPrimary)
                            Spacer()
                            DatePicker("", selection: clockInTimeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden().datePickerStyle(.compact).tint(.shiftBlue)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)

                        Divider().background(Color.darkBg)

                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.shiftBlue.opacity(0.15)).frame(width: 34, height: 34)
                                Image(systemName: "sunset.fill").font(.system(size: 14)).foregroundColor(.shiftBlue)
                            }
                            Text("Clock Out Time").font(.ss(15)).foregroundColor(.ssTextPrimary)
                            Spacer()
                            DatePicker("", selection: clockOutTimeBinding, displayedComponents: .hourAndMinute)
                                .labelsHidden().datePickerStyle(.compact).tint(.shiftBlue)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)

                        Text("Doesn't need a workplace location — reminders fire at these times on your Home days below, no geofencing required.")
                            .font(.ss(11))
                            .foregroundColor(.ssTextMuted)
                            .padding(.horizontal, 16).padding(.bottom, 14)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Work Schedule (per-day Office / Home / Off)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(Color.tealAccent.opacity(0.15)).frame(width: 34, height: 34)
                            Image(systemName: "calendar.badge.checkmark").font(.system(size: 14)).foregroundColor(.tealAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Work Schedule").font(.ss(15)).foregroundColor(.ssTextPrimary)
                            Text(settings.workFromHomeEnabled ? "Tap a day to cycle Office → Home → Off" : "Tap a day to cycle Office → Off")
                                .font(.ss(12)).foregroundColor(.ssTextSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)

                    HStack(spacing: 0) {
                        ForEach(1...7, id: \.self) { weekday in
                            dayChip(weekday: weekday)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 10)

                    HStack(spacing: 0) {
                        legendDot(color: .shiftBlue, label: "Office").frame(maxWidth: .infinity)
                        legendDot(color: .greenAccent, label: "Home").frame(maxWidth: .infinity)
                        legendDot(color: .darkBg, label: "Off", bordered: true).frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 4)

                    if !settings.workFromHomeEnabled {
                        Text("Turn on Work From Home above to assign days as Home.")
                            .font(.ss(11))
                            .foregroundColor(.ssTextMuted)
                            .padding(.horizontal, 16).padding(.bottom, 6)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Office: \(settings.officeDaysLabel)").font(.ss(11)).foregroundColor(.ssTextSecondary)
                        Text("Home: \(settings.homeDaysLabel)").font(.ss(11)).foregroundColor(.ssTextSecondary)
                    }
                    .padding(.horizontal, 16).padding(.bottom, 14)

                    Divider().background(Color.darkBg)

                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(Color.orangeAccent.opacity(0.15)).frame(width: 34, height: 34)
                            Image(systemName: "clock.badge.exclamationmark").font(.system(size: 14)).foregroundColor(.orangeAccent)
                        }
                        Text("Reminder Time").font(.ss(15)).foregroundColor(.ssTextPrimary)
                        Spacer()
                        DatePicker("", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(.shiftBlue)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)

                    Text("\"Didn't make it to work today?\" fires at the time above, only on your Office days above.")
                        .font(.ss(11))
                        .foregroundColor(.ssTextMuted)
                        .padding(.horizontal, 16).padding(.bottom, 14)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Button(action: {
                    withAnimation { saved = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { saved = false }
                }) {
                    Text(saved ? "Saved!" : "Save Changes")
                        .font(.ss(16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(saved ? Color.greenAccent : Color.shiftBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    // ObservableObject's automatic $-binding synthesis only covers stored @Published
    // properties, not the computed missedDayReminderTime — so build the Binding by hand
    // and reschedule whenever the picker commits a new time.
    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { settings.missedDayReminderTime },
            set: {
                settings.missedDayReminderTime = $0
                locationManager.scheduleDailyAbsenceCheck()
            }
        )
    }

    private var clockInTimeBinding: Binding<Date> {
        Binding(
            get: { settings.clockInReminderTime },
            set: {
                settings.clockInReminderTime = $0
                locationManager.scheduleWorkFromHomeReminders()
            }
        )
    }

    private var clockOutTimeBinding: Binding<Date> {
        Binding(
            get: { settings.clockOutReminderTime },
            set: {
                settings.clockOutReminderTime = $0
                locationManager.scheduleWorkFromHomeReminders()
            }
        )
    }

    private enum DayAssignment { case office, home, off }

    private func assignment(for weekday: Int) -> DayAssignment {
        if settings.officeDays.contains(weekday) { return .office }
        if settings.homeDays.contains(weekday) { return .home }
        return .off
    }

    // Tapping a day cycles it Off → Office → Home → Off, so each weekday belongs to
    // at most one schedule (avoids firing both a geofence alert and a WFH reminder
    // on the same day). The Home state is only reachable while Work From Home is
    // enabled — no point assigning days to a feature that's off.
    private func cycleDay(_ weekday: Int) {
        switch assignment(for: weekday) {
        case .off:
            settings.officeDays.insert(weekday)
        case .office:
            settings.officeDays.remove(weekday)
            if settings.workFromHomeEnabled {
                settings.homeDays.insert(weekday)
            }
        case .home:
            settings.homeDays.remove(weekday)
        }
        locationManager.scheduleDailyAbsenceCheck()
        locationManager.scheduleWorkFromHomeReminders()
    }

    private func dayChip(weekday: Int) -> some View {
        let state = assignment(for: weekday)
        let bg: Color = {
            switch state {
            case .office: return .shiftBlue
            case .home:   return .greenAccent
            case .off:    return .darkBg
            }
        }()
        let label: String = {
            switch state {
            case .office: return "Office"
            case .home:   return "Home"
            case .off:    return "Off"
            }
        }()
        return Button(action: { cycleDay(weekday) }) {
            Text(AppSettings.weekdaySymbolsShort[weekday - 1].prefix(1))
                .font(.ss(13, weight: .bold))
                .foregroundColor(state == .off ? .ssTextMuted : .white)
                .frame(width: 34, height: 34)
                .background(bg)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(AppSettings.weekdaySymbolsShort[weekday - 1]): \(label)")
    }

    private func legendDot(color: Color, label: String, bordered: Bool = false) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
                .overlay(Circle().stroke(Color.ssTextMuted.opacity(bordered ? 0.6 : 0), lineWidth: 1))
            Text(label).font(.ss(11)).foregroundColor(.ssTextSecondary)
        }
    }
}

// MARK: - Appearance

struct AppearanceView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    private let options: [(theme: AppTheme, label: String)] = [
        (.dark,   "Dark"),
        (.light,  "Light"),
        (.system, "System"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                navHeader(title: "Appearance", dismiss: dismiss)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(Color.shiftBlue.opacity(0.15)).frame(width: 34, height: 34)
                            Image(systemName: "moon.circle.fill").font(.system(size: 15)).foregroundColor(.shiftBlue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Theme").font(.ss(15)).foregroundColor(.ssTextPrimary)
                            Text("Controls the app's overall color scheme")
                                .font(.ss(11)).foregroundColor(.ssTextSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)

                    HStack(spacing: 8) {
                        ForEach(options, id: \.theme) { opt in
                            Button(action: { settings.appTheme = opt.theme }) {
                                Text(opt.label)
                                    .font(.ss(13, weight: .semibold))
                                    .foregroundColor(settings.appTheme == opt.theme ? .white : .ssTextSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(settings.appTheme == opt.theme ? Color.shiftBlue : Color.darkBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 14)
                }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Time Format
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(Color.shiftBlue.opacity(0.15)).frame(width: 34, height: 34)
                            Image(systemName: "clock").font(.system(size: 15)).foregroundColor(.shiftBlue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Time Format").font(.ss(15)).foregroundColor(.ssTextPrimary)
                            Text("Used for shift times on Home, Calendar, and Export")
                                .font(.ss(11)).foregroundColor(.ssTextSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)

                    HStack(spacing: 8) {
                        ForEach([false, true], id: \.self) { use24h in
                            Button(action: { settings.use24HourClock = use24h }) {
                                Text(use24h ? "24-Hour" : "12-Hour (AM/PM)")
                                    .font(.ss(13, weight: .semibold))
                                    .foregroundColor(settings.use24HourClock == use24h ? .white : .ssTextSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(settings.use24HourClock == use24h ? Color.shiftBlue : Color.darkBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 12)

                    Text("Native time pickers (Manual Entry, Reminder Time) always follow your iPhone's own 12/24-hour Region setting — iOS doesn't let apps override that.")
                        .font(.ss(10))
                        .foregroundColor(.ssTextMuted)
                        .padding(.horizontal, 16).padding(.bottom, 14)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

}

// MARK: - Overtime Rules View

struct OvertimeRulesView: View {
    @ObservedObject var store: ShiftStore
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false
    @State private var showApplyChangeDialog = false

    // Snapshot of the rules that actually change past-shift math, captured when the screen
    // opens, so "Save Changes" can detect whether anything worth prompting about changed.
    @State private var initialOvertimeEnabled = AppSettings.shared.overtimeEnabled
    @State private var initialDailyOvertimeHours = AppSettings.shared.dailyOvertimeHours
    @State private var initialOvertimeMultiplier = AppSettings.shared.overtimeMultiplier

    private let multiplierOptions: [Double] = [1.25, 1.5, 2.0]

    private var rulesChanged: Bool {
        settings.overtimeEnabled != initialOvertimeEnabled ||
        settings.dailyOvertimeHours != initialDailyOvertimeHours ||
        settings.overtimeMultiplier != initialOvertimeMultiplier
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                navHeader(title: "Overtime Rules", dismiss: dismiss)

                // Enable toggle
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(Color.orangeAccent.opacity(0.15)).frame(width: 38, height: 38)
                            Image(systemName: "clock.badge.exclamationmark.fill").font(.system(size: 15)).foregroundColor(.orangeAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Overtime Rules").font(.ss(15)).foregroundColor(.ssTextPrimary)
                            Text(settings.overtimeEnabled ? "Auto-splits shifts when threshold is exceeded" : "Off")
                                .font(.ss(12)).foregroundColor(.ssTextSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.overtimeEnabled).tint(.orangeAccent)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if settings.overtimeEnabled {
                    // Thresholds
                    VStack(spacing: 0) {
                        thresholdRow(
                            icon: "sun.max.fill", color: .shiftBlue,
                            label: "Daily Threshold",
                            subtitle: "Shifts longer than this get split",
                            value: $settings.dailyOvertimeHours,
                            range: 4...16, step: 0.5,
                            unit: "h/day"
                        )
                        Divider().background(Color.darkBg).padding(.leading, 62)
                        thresholdRow(
                            icon: "calendar.badge.clock", color: .tealAccent,
                            label: "Weekly Threshold",
                            subtitle: "Used to flag weeks with excess hours",
                            value: $settings.weeklyOvertimeHours,
                            range: 20...60, step: 1,
                            unit: "h/week"
                        )
                    }
                    .background(Color.darkCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Multiplier
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.greenAccent.opacity(0.15)).frame(width: 38, height: 38)
                                Image(systemName: "multiply.circle.fill").font(.system(size: 15)).foregroundColor(.greenAccent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Overtime Multiplier").font(.ss(15)).foregroundColor(.ssTextPrimary)
                                Text("Pay rate for overtime hours").font(.ss(12)).foregroundColor(.ssTextSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)

                        HStack(spacing: 10) {
                            ForEach(multiplierOptions, id: \.self) { opt in
                                Button(action: { settings.overtimeMultiplier = opt }) {
                                    Text(String(format: "%.2g×", opt))
                                        .font(.ss(14, weight: .semibold))
                                        .foregroundColor(settings.overtimeMultiplier == opt ? .white : .ssTextPrimary)
                                        .frame(maxWidth: .infinity).frame(height: 38)
                                        .background(settings.overtimeMultiplier == opt ? Color.greenAccent : Color.darkBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 14)
                    }
                    .background(Color.darkCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Info card
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill").font(.system(size: 15)).foregroundColor(.shiftBlue)
                        Text("When you clock out after \(formattedHours(settings.dailyOvertimeHours)), ShiftSync automatically splits your shift: the first \(formattedHours(settings.dailyOvertimeHours)) at regular pay and the rest at \(String(format: "%.2g", settings.overtimeMultiplier))× pay.")
                            .font(.ss(12)).foregroundColor(.ssTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color.shiftBlue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: saveChanges) {
                    Text(saved ? "Saved!" : "Save Changes")
                        .font(.ss(16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(saved ? Color.greenAccent : Color.orangeAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .alert(
            "Apply New Overtime Rules To Past Shifts?",
            isPresented: $showApplyChangeDialog
        ) {
            Button("Apply to All Shifts") {
                store.reapplyOvertimeRulesToExistingEntries()
                confirmSaved()
            }
            Button("Only Future Shifts") {
                store.freezePayForExistingEntries()
                confirmSaved()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You changed the overtime threshold, multiplier, or toggle. Should already-logged shifts be recalculated with the new rules, or keep the pay they already had?")
        }
    }

    private func saveChanges() {
        let hasExistingShifts = store.entries.contains { !$0.shiftType.isDayType }
        if rulesChanged && hasExistingShifts {
            showApplyChangeDialog = true
        } else {
            confirmSaved()
        }
    }

    private func confirmSaved() {
        initialOvertimeEnabled = settings.overtimeEnabled
        initialDailyOvertimeHours = settings.dailyOvertimeHours
        initialOvertimeMultiplier = settings.overtimeMultiplier
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { saved = false }
    }

    private func formattedHours(_ h: Double) -> String {
        h == h.rounded() ? "\(Int(h))h" : String(format: "%.1fh", h)
    }

    private func thresholdRow(icon: String, color: Color, label: String, subtitle: String,
                              value: Binding<Double>, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.ss(15)).foregroundColor(.ssTextPrimary)
                Text(subtitle).font(.ss(12)).foregroundColor(.ssTextSecondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button(action: { if value.wrappedValue > range.lowerBound { value.wrappedValue = max(range.lowerBound, value.wrappedValue - step) } }) {
                    Image(systemName: "minus.circle.fill").font(.system(size: 22)).foregroundColor(color)
                }.buttonStyle(.plain)
                .accessibilityLabel("Decrease \(label)")
                Text(formattedHours(value.wrappedValue))
                    .font(.ss(14, weight: .bold)).foregroundColor(.ssTextPrimary)
                    .frame(minWidth: 36)
                Button(action: { if value.wrappedValue < range.upperBound { value.wrappedValue = min(range.upperBound, value.wrappedValue + step) } }) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(color)
                }.buttonStyle(.plain)
                .accessibilityLabel("Increase \(label)")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - Salary Settings

struct SalarySettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var rateText: String = ""
    @FocusState private var rateFocused: Bool
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                navHeader(title: "Salary & Currency", dismiss: dismiss)

                // Currency
                VStack(alignment: .leading, spacing: 0) {
                    Text("CURRENCY").font(.ss(11, weight: .semibold)).foregroundColor(.ssTextSecondary)
                        .kerning(1).padding(.horizontal, 4).padding(.bottom, 8)
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.greenAccent.opacity(0.15)).frame(width: 34, height: 34)
                                Image(systemName: "dollarsign.circle").font(.system(size: 15)).foregroundColor(.greenAccent)
                            }
                            Text("Currency").font(.ss(15)).foregroundColor(.ssTextPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)

                        HStack(spacing: 8) {
                            ForEach(Currency.allCases, id: \.self) { cur in
                                Button(action: { settings.currency = cur }) {
                                    Text(cur.displayName)
                                        .font(.ss(13, weight: .semibold))
                                        .foregroundColor(settings.currency == cur ? .white : .ssTextSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(settings.currency == cur ? Color.shiftBlue : Color.darkBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 12)
                    }
                    .background(Color.darkCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // Payment type, Rate, Work Day Hours — 3 side-by-side columns
                VStack(alignment: .leading, spacing: 0) {
                    Text("PAY RATE").font(.ss(11, weight: .semibold)).foregroundColor(.ssTextSecondary)
                        .kerning(1).padding(.horizontal, 4).padding(.bottom, 8)
                    HStack(alignment: .top, spacing: 0) {
                        payRateColumn(icon: "calendar.badge.clock", iconColor: .shiftBlue, label: "Type") {
                            Menu {
                                ForEach(PaymentType.allCases, id: \.self) { t in
                                    Button(t.rawValue) { settings.paymentType = t }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(settings.paymentType.rawValue)
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                // Picker's menu style doesn't reliably honor an outer .font()
                                // modifier on its auto-generated label — a Menu with an explicit
                                // Text gives exact control so this matches the other two columns.
                                .font(.ss(15, weight: .semibold))
                                .foregroundColor(.shiftBlue)
                            }
                        }

                        Divider().frame(height: 74).background(Color.darkBg)

                        payRateColumn(icon: "banknote", iconColor: .greenAccent, label: settings.rateLabel) {
                            HStack(spacing: 4) {
                                Text(settings.currency.symbol)
                                    .font(.ss(15, weight: .semibold)).foregroundColor(.shiftBlue)
                                TextField("0", text: $rateText)
                                    .keyboardType(.decimalPad)
                                    .font(.ss(15, weight: .semibold)).foregroundColor(.shiftBlue)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize()
                                    .focused($rateFocused)
                                    .onAppear { rateText = rateString }
                                    .onChange(of: settings.paymentType) { rateText = rateString }
                                    .onSubmit { applyRate() }
                                    .onChange(of: rateFocused) { if !rateFocused { applyRate() } }
                                    // The decimal pad has no Return key, so onSubmit never fires, and
                                    // dismissing via Back/swipe doesn't always resign focus in time for
                                    // onChange(of: rateFocused) to run — commit on every valid keystroke
                                    // instead of relying solely on losing focus.
                                    .onChange(of: rateText) { applyRate() }
                            }
                        }

                        Divider().frame(height: 74).background(Color.darkBg)

                        payRateColumn(icon: "clock.fill", iconColor: .tealAccent, label: "Work Hours") {
                            HStack(spacing: 6) {
                                Button(action: { if settings.workDayHours > 1 { settings.workDayHours = max(1, settings.workDayHours - 0.5) } }) {
                                    Image(systemName: "minus.circle.fill").font(.system(size: 18))
                                        .foregroundColor(settings.workDayHours > 1 ? .tealAccent : .ssTextMuted)
                                }
                                .accessibilityLabel("Decrease work day hours")
                                let h = settings.workDayHours
                                Text(h == h.rounded() ? "\(Int(h))h" : String(format: "%.1fh", h))
                                    .font(.ss(15, weight: .semibold)).foregroundColor(.ssTextPrimary)
                                Button(action: { if settings.workDayHours < 24 { settings.workDayHours = min(24, settings.workDayHours + 0.5) } }) {
                                    Image(systemName: "plus.circle.fill").font(.system(size: 18)).foregroundColor(.tealAccent)
                                }
                                .accessibilityLabel("Increase work day hours")
                            }
                        }
                    }
                    .padding(.vertical, 16)
                    .background(Color.darkCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button(action: saveChanges) {
                    Text(saved ? "Saved!" : "Save Changes")
                        .font(.ss(16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(saved ? Color.greenAccent : Color.shiftBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
        // The decimal pad has no Return/Done key, so tapping anywhere outside the
        // rate field is the only way to dismiss it.
        .onTapGesture { rateFocused = false }
    }

    private var rateString: String {
        let v = settings.paymentType == .hourly ? settings.hourlyRate : settings.monthlySalary
        return String(format: "%.2f", v)
    }

    private func applyRate() {
        guard let v = Double(rateText.replacingOccurrences(of: ",", with: ".")), v > 0 else { return }
        if settings.paymentType == .hourly { settings.hourlyRate = v } else { settings.monthlySalary = v }
    }

    private func payRateColumn<Content: View>(icon: String, iconColor: Color, label: String,
                                               @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(iconColor.opacity(0.15)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(iconColor)
            }
            Text(label).font(.ss(11, weight: .semibold)).foregroundColor(.ssTextSecondary)
                .lineLimit(1).minimumScaleFactor(0.8)
            content()
        }
        .frame(maxWidth: .infinity)
    }

    private func saveChanges() {
        // Currency, payment type, and work day hours already apply live; this commits
        // any pending rate text, dismisses the keyboard, and gives explicit confirmation.
        applyRate()
        rateFocused = false
        withAnimation { saved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { saved = false }
    }
}

#Preview {
    NavigationStack { ProfileView(userName: "Alex", store: ShiftStore()) {} }
}

