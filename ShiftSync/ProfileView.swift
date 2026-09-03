import SwiftUI

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
                            .font(.system(size: 36, weight: .bold)).foregroundColor(.white)
                    }
                    Text(userName).font(.system(size: 22, weight: .bold)).foregroundColor(.ssTextPrimary)
                    let role = [settings.jobTitle, settings.branch]
                        .filter { !$0.isEmpty }.joined(separator: "  •  ")
                    if !role.isEmpty {
                        Text(role).font(.system(size: 14)).foregroundColor(.ssTextSecondary)
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
                    navRow(icon: "clock.badge.exclamationmark.fill", label: "Overtime Rules", color: .orangeAccent, destination: AnyView(OvertimeRulesView()))
                    Divider().background(Color.darkBg)
                    navRow(icon: "square.and.arrow.up.fill", label: "Export Reports", color: .tealAccent, destination: AnyView(ExportView(store: store)))
                }

                // ── Security ─────────────────────────────────────────────
                settingsSection(title: "SECURITY & PRIVACY") {
                    navRow(icon: "lock.shield.fill", label: "Security & Privacy", color: .shiftBlue, destination: AnyView(SecurityPrivacyView(store: store, onLogout: onLogout)))
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
                            Text("Days per Year").font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                            Text("\(store.vacationDaysUsed) used of \(settings.vacationDaysPerYear)")
                                .font(.system(size: 12)).foregroundColor(.ssTextSecondary)
                        }
                        Spacer()
                        HStack(spacing: 12) {
                            Button(action: { if settings.vacationDaysPerYear > 0 { settings.vacationDaysPerYear -= 1 } }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(settings.vacationDaysPerYear > 0 ? .shiftBlue : .ssTextMuted)
                            }
                            Text("\(settings.vacationDaysPerYear)")
                                .font(.system(size: 16, weight: .bold)).foregroundColor(.ssTextPrimary)
                                .frame(width: 30, alignment: .center)
                            Button(action: { settings.vacationDaysPerYear += 1 }) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(.shiftBlue)
                            }
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
                                .font(.system(size: 15)).foregroundColor(.redAccent)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 13)
                    }
                }

                Spacer().frame(height: tabBarBottomPadding)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
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
            Text(value).font(.system(size: 17, weight: .bold)).foregroundColor(.ssTextPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11)).foregroundColor(.ssTextSecondary)
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
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(.ssTextSecondary)
                .kerning(1).padding(.horizontal, 4).padding(.bottom, 8)
            VStack(spacing: 0) { content() }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func settingsRow(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 12) {
            settingIcon(icon, color: color)
            Text(label).font(.system(size: 15)).foregroundColor(.ssTextPrimary)
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
                    Text(label).font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 12)).foregroundColor(.ssTextSecondary)
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
                        .font(.system(size: 28, weight: .bold)).foregroundColor(.white)
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
                        .font(.system(size: 16, weight: .bold))
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
                Text(label).font(.system(size: 11, weight: .semibold)).foregroundColor(.ssTextMuted)
                TextField(placeholder, text: text)
                    .font(.system(size: 15)).foregroundColor(.ssTextPrimary)
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

                // Danger zone
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(Color.redAccent.opacity(0.15)).frame(width: 38, height: 38)
                            Image(systemName: "trash").font(.system(size: 15)).foregroundColor(.redAccent)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Clear All Data").font(.system(size: 15)).foregroundColor(.redAccent)
                            Text("Deletes all shifts, settings, and profile info")
                                .font(.system(size: 12)).foregroundColor(.ssTextMuted)
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
        .confirmationDialog("Clear All Data?", isPresented: $showClearConfirm, titleVisibility: .visible) {
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
    }

    private func privacyRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 15)).foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(.ssTextPrimary)
                Text(subtitle).font(.system(size: 12)).foregroundColor(.ssTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

// MARK: - Notification Preferences

struct NotificationPrefsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @ObservedObject private var watchSession = WatchSessionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showWatchResultAlert = false

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
                            Text("Arrival & Departure Alerts").font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                            Text(settings.locationAlertsEnabled ? "On — notified when you arrive or leave work" : "Off")
                                .font(.system(size: 12))
                                .foregroundColor(settings.locationAlertsEnabled ? .greenAccent : .ssTextMuted)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.locationAlertsEnabled)
                            .tint(.shiftBlue)
                            .onChange(of: settings.locationAlertsEnabled) { _, enabled in
                                if enabled {
                                    locationManager.requestPermissions()
                                    if settings.hasWorkplaceCoordinates { locationManager.restoreMonitoring() }
                                } else {
                                    locationManager.stopMonitoring()
                                }
                            }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)

                    Divider().background(Color.darkBg)

                    Button(action: { LocationManager.openSettings() }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.shiftBlue.opacity(0.15)).frame(width: 34, height: 34)
                                Image(systemName: "gear").font(.system(size: 14)).foregroundColor(.shiftBlue)
                            }
                            Text("iOS Notification Settings").font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                            Spacer()
                            Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .semibold)).foregroundColor(.ssTextMuted)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }

                    Divider().background(Color.darkBg)

                    Button(action: {
                        watchSession.watchTestResult = nil
                        watchSession.sendTestNotificationToWatch()
                    }) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.tealAccent.opacity(0.15)).frame(width: 34, height: 34)
                                Image(systemName: "applewatch").font(.system(size: 14)).foregroundColor(.tealAccent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Test Apple Watch Notification").font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                                Text(watchStatusLabel)
                                    .font(.system(size: 12))
                                    .foregroundColor(watchStatusColor)
                            }
                            Spacer()
                            Image(systemName: "paperplane.fill").font(.system(size: 12, weight: .semibold)).foregroundColor(.ssTextMuted)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)
                    }
                }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .onChange(of: watchSession.watchTestResult) { _, result in
            showWatchResultAlert = result != nil
        }
        .alert("Apple Watch", isPresented: $showWatchResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(watchSession.watchTestResult ?? "")
        }
    }

    private var watchStatusLabel: String {
        if !watchSession.isWatchAppInstalled { return "ShiftSync not installed on watch" }
        return watchSession.isWatchReachable ? "Watch is connected" : "Watch may be unreachable"
    }

    private var watchStatusColor: Color {
        if !watchSession.isWatchAppInstalled { return .orangeAccent }
        return watchSession.isWatchReachable ? .greenAccent : .ssTextMuted
    }
}

// MARK: - Appearance

struct AppearanceView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    private let options: [(theme: AppTheme, label: String, icon: String)] = [
        (.dark,   "Dark",   "moon.fill"),
        (.light,  "Light",  "sun.max.fill"),
        (.system, "System", "circle.lefthalf.filled"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                navHeader(title: "Appearance", dismiss: dismiss)

                HStack(spacing: 12) {
                    ForEach(options, id: \.theme) { opt in
                        Button(action: { settings.appTheme = opt.theme }) {
                            themeChip(label: opt.label, icon: opt.icon,
                                      selected: settings.appTheme == opt.theme)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Label("Dark", systemImage: "moon.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.ssTextPrimary)
                    Text("Optimised for low-light environments.")
                        .font(.system(size: 13)).foregroundColor(.ssTextSecondary)
                    Label("Light", systemImage: "sun.max.fill")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.ssTextPrimary)
                        .padding(.top, 4)
                    Text("Classic bright interface.")
                        .font(.system(size: 13)).foregroundColor(.ssTextSecondary)
                    Label("System", systemImage: "circle.lefthalf.filled")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(.ssTextPrimary)
                        .padding(.top, 4)
                    Text("Follows your iPhone's appearance setting automatically.")
                        .font(.system(size: 13)).foregroundColor(.ssTextSecondary)
                }
                .padding(16)
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private func themeChip(label: String, icon: String, selected: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? Color.shiftBlue : Color.darkBg)
                    .frame(height: 60)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(selected ? Color.shiftBlue : Color.ssTextMuted.opacity(0.3), lineWidth: selected ? 2 : 1))
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(selected ? .white : .ssTextMuted)
            }
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(selected ? .ssTextPrimary : .ssTextMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Overtime Rules View

struct OvertimeRulesView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    private let multiplierOptions: [Double] = [1.25, 1.5, 2.0]

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
                            Text("Overtime Rules").font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                            Text(settings.overtimeEnabled ? "Auto-splits shifts when threshold is exceeded" : "Off")
                                .font(.system(size: 12)).foregroundColor(.ssTextSecondary)
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
                                Text("Overtime Multiplier").font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                                Text("Pay rate for overtime hours").font(.system(size: 12)).foregroundColor(.ssTextSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 14)

                        HStack(spacing: 10) {
                            ForEach(multiplierOptions, id: \.self) { opt in
                                Button(action: { settings.overtimeMultiplier = opt }) {
                                    Text(String(format: "%.2g×", opt))
                                        .font(.system(size: 14, weight: .semibold))
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
                            .font(.system(size: 12)).foregroundColor(.ssTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color.shiftBlue.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
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
                Text(label).font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                Text(subtitle).font(.system(size: 12)).foregroundColor(.ssTextSecondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button(action: { if value.wrappedValue > range.lowerBound { value.wrappedValue = max(range.lowerBound, value.wrappedValue - step) } }) {
                    Image(systemName: "minus.circle.fill").font(.system(size: 22)).foregroundColor(color)
                }.buttonStyle(.plain)
                Text(formattedHours(value.wrappedValue))
                    .font(.system(size: 14, weight: .bold)).foregroundColor(.ssTextPrimary)
                    .frame(minWidth: 36)
                Button(action: { if value.wrappedValue < range.upperBound { value.wrappedValue = min(range.upperBound, value.wrappedValue + step) } }) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(color)
                }.buttonStyle(.plain)
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

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                navHeader(title: "Salary & Currency", dismiss: dismiss)

                // Currency
                VStack(alignment: .leading, spacing: 0) {
                    Text("CURRENCY").font(.system(size: 11, weight: .semibold)).foregroundColor(.ssTextSecondary)
                        .kerning(1).padding(.horizontal, 4).padding(.bottom, 8)
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.greenAccent.opacity(0.15)).frame(width: 34, height: 34)
                                Image(systemName: "dollarsign.circle").font(.system(size: 15)).foregroundColor(.greenAccent)
                            }
                            Text("Currency").font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)

                        HStack(spacing: 8) {
                            ForEach(Currency.allCases, id: \.self) { cur in
                                Button(action: { settings.currency = cur }) {
                                    Text(cur.displayName)
                                        .font(.system(size: 13, weight: .semibold))
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

                // Payment type, Rate, Work Day Hours
                VStack(alignment: .leading, spacing: 0) {
                    Text("PAY RATE").font(.system(size: 11, weight: .semibold)).foregroundColor(.ssTextSecondary)
                        .kerning(1).padding(.horizontal, 4).padding(.bottom, 8)
                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.shiftBlue.opacity(0.15)).frame(width: 34, height: 34)
                                Image(systemName: "calendar.badge.clock").font(.system(size: 15)).foregroundColor(.shiftBlue)
                            }
                            Text("Payment Type").font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                            Spacer()
                            Picker("", selection: $settings.paymentType) {
                                ForEach(PaymentType.allCases, id: \.self) { t in Text(t.rawValue).tag(t) }
                            }
                            .pickerStyle(.menu).tint(.shiftBlue)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)

                        Divider().background(Color.darkBg)

                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.greenAccent.opacity(0.15)).frame(width: 34, height: 34)
                                Image(systemName: "banknote").font(.system(size: 15)).foregroundColor(.greenAccent)
                            }
                            Text(settings.rateLabel).font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                            Spacer()
                            HStack(spacing: 4) {
                                Text(settings.currency.symbol)
                                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.shiftBlue)
                                TextField("0", text: $rateText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.shiftBlue)
                                    .multilineTextAlignment(.trailing).frame(width: 80)
                                    .focused($rateFocused)
                                    .onAppear { rateText = rateString }
                                    .onChange(of: settings.paymentType) { rateText = rateString }
                                    .onSubmit { applyRate() }
                                    .onChange(of: rateFocused) { if !rateFocused { applyRate() } }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)

                        Divider().background(Color.darkBg)

                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8).fill(Color.tealAccent.opacity(0.15)).frame(width: 34, height: 34)
                                Image(systemName: "clock.fill").font(.system(size: 15)).foregroundColor(.tealAccent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Work Day Hours").font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                                Text("Used for day-off pay calculation")
                                    .font(.system(size: 12)).foregroundColor(.ssTextSecondary)
                            }
                            Spacer()
                            HStack(spacing: 12) {
                                Button(action: { if settings.workDayHours > 1 { settings.workDayHours = max(1, settings.workDayHours - 0.5) } }) {
                                    Image(systemName: "minus.circle.fill").font(.system(size: 22))
                                        .foregroundColor(settings.workDayHours > 1 ? .tealAccent : .ssTextMuted)
                                }
                                let h = settings.workDayHours
                                Text(h == h.rounded() ? "\(Int(h))h" : String(format: "%.1fh", h))
                                    .font(.system(size: 16, weight: .bold)).foregroundColor(.ssTextPrimary)
                                    .frame(width: 38, alignment: .center)
                                Button(action: { if settings.workDayHours < 24 { settings.workDayHours = min(24, settings.workDayHours + 0.5) } }) {
                                    Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundColor(.tealAccent)
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                    .background(Color.darkCard)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
    }

    private var rateString: String {
        let v = settings.paymentType == .hourly ? settings.hourlyRate : settings.monthlySalary
        return String(format: "%.2f", v)
    }

    private func applyRate() {
        guard let v = Double(rateText.replacingOccurrences(of: ",", with: ".")), v > 0 else { return }
        if settings.paymentType == .hourly { settings.hourlyRate = v } else { settings.monthlySalary = v }
    }
}

#Preview {
    NavigationStack { ProfileView(userName: "Alex", store: ShiftStore()) {} }
}
