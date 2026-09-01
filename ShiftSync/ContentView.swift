import SwiftUI
import CoreLocation

// MARK: - Root
struct ContentView: View {
    @StateObject private var store = ShiftStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var userName: String? = UserDefaults.standard.string(forKey: "ss_user_name")

    var body: some View {
        Group {
            if let name = userName {
                MainTabView(userName: name, store: store) {
                    UserDefaults.standard.removeObject(forKey: "ss_user_name")
                    userName = nil
                }
            } else {
                LoginView { name in
                    UserDefaults.standard.set(name, forKey: "ss_user_name")
                    userName = name
                }
            }
        }
        .preferredColorScheme(settings.appTheme.colorScheme)
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    let userName: String
    @ObservedObject var store: ShiftStore
    let onLogout: () -> Void

    @ObservedObject private var locationManager = LocationManager.shared
    @State private var selectedTab = 0
    @State private var showAddSheet = false
    @State private var showAlwaysPermissionAlert = false

    var body: some View {
        activeTabContent
            // overlay ensures the tab bar is always rendered on top AND receives touches first,
            // regardless of what UIKit views the NavigationStack creates underneath
            .overlay(alignment: .bottom) {
                bottomBar
            }
            .ignoresSafeArea(.keyboard)
            .tint(.shiftBlue)
            .sheet(isPresented: $showAddSheet) {
                ManualEntryView(store: store, isPresented: $showAddSheet)
            }
            .onChange(of: locationManager.authStatus) { _, status in
                if status == .authorizedWhenInUse,
                   AppSettings.shared.locationAlertsEnabled {
                    showAlwaysPermissionAlert = true
                }
            }
            .alert("One More Step Required", isPresented: $showAlwaysPermissionAlert) {
                Button("Open Settings") { LocationManager.openSettings() }
                Button("Later", role: .cancel) {}
            } message: {
                Text("To receive arrival & departure notifications:\n\n1. Tap \"Open Settings\"\n2. Tap \"Location\"\n3. Select \"Always\"\n\nWithout this, notifications only work while the app is open.")
            }
    }

    // MARK: - Active Tab

    // TabView handles switching at the UIKit level — guaranteed to work unlike SwiftUI switch/ZStack tricks
    private var activeTabContent: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(userName: userName, store: store)
                    .navigationBarHidden(true)
                    .toolbar(.hidden, for: .tabBar)
            }
            .tag(0)

            NavigationStack {
                CalendarView(store: store)
                    .toolbar(.hidden, for: .tabBar)
            }
            .tag(1)

            NavigationStack {
                WorkplaceTabView()
                    .toolbar(.hidden, for: .tabBar)
            }
            .tag(2)

            NavigationStack {
                ProfileView(userName: userName, store: store, onLogout: onLogout)
                    .toolbar(.hidden, for: .tabBar)
            }
            .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    // MARK: - Bottom Bar (overlay)

    private var bottomBar: some View {
        HStack(spacing: 0) {
            tabBtn(icon: "house",    label: "Home",      tag: 0)
            tabBtn(icon: "calendar", label: "Schedule",  tag: 1)

            // + button — floating above bar
            Button(action: { showAddSheet = true }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.shiftBlue)
                        .frame(width: 46, height: 46)
                        .rotationEffect(.degrees(45))
                        .shadow(color: Color.shiftBlue.opacity(0.45), radius: 14, x: 0, y: 6)
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 72, height: 54)
            }
            .buttonStyle(.plain)
            .offset(y: -22)

            tabBtn(icon: "map",      label: "Workplace", tag: 2)
            tabBtn(icon: "person",   label: "Profile",   tag: 3)
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, safeAreaBottom > 0 ? safeAreaBottom : 10)
        .background(
            UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(
                topLeading: 26, bottomLeading: 0, bottomTrailing: 0, topTrailing: 26
            ))
            .fill(Color(UIColor.systemBackground))
            .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: -6)
        )
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private var safeAreaBottom: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first?.safeAreaInsets.bottom ?? 0
    }

    private func tabBtn(icon: String, label: String, tag: Int) -> some View {
        let isActive = selectedTab == tag
        let activeIcon = icon == "calendar" ? "calendar" : "\(icon).fill"
        return Button(action: { selectedTab = tag }) {
            VStack(spacing: 5) {
                Image(systemName: isActive ? activeIcon : icon)
                    .font(.system(size: 22, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .shiftBlue : Color(UIColor.secondaryLabel))
                Text(label)
                    .font(.system(size: 10, weight: isActive ? .semibold : .medium))
                    .foregroundColor(isActive ? .shiftBlue : Color(UIColor.secondaryLabel))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Workplace Tab

struct WorkplaceTabView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var showMapPicker = false
    @State private var locationAlertTitle = ""
    @State private var locationAlertMessage = ""
    @State private var showLocationAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Workplace")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.ssTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)

                // Status card
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(statusColor.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Image(systemName: "location.fill")
                                .font(.system(size: 22))
                                .foregroundColor(statusColor)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(settings.workplaceAddress.isEmpty ? "No workplace set" : "Workplace Active")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.ssTextPrimary)
                            Text(settings.workplaceAddress.isEmpty
                                 ? "Tap below to set your workplace location"
                                 : settings.workplaceAddress)
                                .font(.system(size: 13))
                                .foregroundColor(.ssTextSecondary)
                                .lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(16)

                    Divider().background(Color.darkBg)

                    HStack(spacing: 12) {
                        settingIcon("antenna.radiowaves.left.and.right", color: .shiftBlue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto-Geofencing")
                                .font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                            Text(geofenceLabel)
                                .font(.system(size: 11)).foregroundColor(geofenceLabelColor)
                        }
                        Spacer()
                        Toggle("", isOn: $settings.locationAlertsEnabled)
                            .tint(.shiftBlue)
                            .onChange(of: settings.locationAlertsEnabled) { _, enabled in
                                if enabled {
                                    locationManager.requestPermissions()
                                    if settings.hasWorkplaceCoordinates { locationManager.restoreMonitoring() }
                                    else {
                                        locationAlertTitle   = "Set a Location First"
                                        locationAlertMessage = "Pick your workplace on the map first."
                                        showLocationAlert    = true
                                        settings.locationAlertsEnabled = false
                                    }
                                } else {
                                    locationManager.stopMonitoring()
                                }
                            }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                // Action buttons
                VStack(spacing: 12) {
                    Button(action: { showMapPicker = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "map.fill").font(.system(size: 17))
                            Text(settings.workplaceAddress.isEmpty ? "Set Workplace on Map" : "Update Workplace")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Color.shiftBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    if !settings.workplaceAddress.isEmpty {
                        Button(action: {
                            locationManager.sendTestNotification()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "bell.fill").font(.system(size: 17))
                                Text("Test Notification")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.shiftBlue)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(Color.shiftBlue.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }

                Spacer().frame(height: 120)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationBarHidden(true)
        .sheet(isPresented: $showMapPicker) {
            MapLocationPickerView(isPresented: $showMapPicker)
        }
        .alert(locationAlertTitle, isPresented: $showLocationAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(locationAlertMessage) }
    }

    private var statusColor: Color {
        if settings.workplaceAddress.isEmpty { return .ssTextMuted }
        return locationManager.isMonitoring ? .greenAccent : .orangeAccent
    }

    private var geofenceLabel: String {
        guard settings.locationAlertsEnabled else { return "Off" }
        if locationManager.isMonitoring && locationManager.authStatus == .authorizedAlways {
            return "Active — monitoring your workplace"
        }
        return "Needs location permission"
    }

    private var geofenceLabelColor: Color {
        guard settings.locationAlertsEnabled else { return .ssTextMuted }
        return locationManager.isMonitoring ? .greenAccent : .orangeAccent
    }

    private func settingIcon(_ name: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)).frame(width: 34, height: 34)
            Image(systemName: name).font(.system(size: 15)).foregroundColor(color)
        }
    }
}

// MARK: - Earnings View
struct EarningsView: View {
    @ObservedObject var store: ShiftStore

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 12)

                // Summary card
                ZStack {
                    LinearGradient(
                        colors: [Color.shiftBlue, Color.shiftBlueDark],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("THIS WEEK")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                            .kerning(1)
                        Text(formatCurrency(store.weeklyEarnings))
                            .font(.system(size: 40, weight: .black))
                            .foregroundColor(.white)
                        HStack(spacing: 16) {
                            earningsStat(label: "Hours", value: formatDuration(store.weeklyMinutes))
                            earningsStat(label: "Shifts", value: "\(weeklyShiftCount)")
                            earningsStat(label: "Rate", value: "$24.00/hr")
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // All-time totals
                VStack(spacing: 0) {
                    sectionHeader("ALL TIME")
                    HStack(spacing: 0) {
                        totalStatCell(value: "\(store.entries.count)", label: "Shifts")
                        Divider().background(Color.darkBg).frame(height: 40)
                        totalStatCell(value: formatDuration(store.entries.reduce(0) { $0 + $1.durationMinutes }), label: "Hours")
                        Divider().background(Color.darkBg).frame(height: 40)
                        totalStatCell(value: formatCurrency(store.entries.reduce(0) { $0 + $1.estimatedPay }), label: "Earned")
                    }
                    .padding(.vertical, 16)
                }
                .background(Color.darkCard)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Recent shifts
                if !store.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("RECENT SHIFTS")
                        ForEach(store.entries.sorted { $0.startedAt > $1.startedAt }.prefix(10)) { entry in
                            WorkedShiftRow(entry: entry)
                        }
                    }
                }

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
        }
        .background(Color.darkBg.ignoresSafeArea())
        .navigationTitle("Earnings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private var weeklyShiftCount: Int {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())),
              let end = cal.date(byAdding: .day, value: 7, to: start) else { return 0 }
        return store.entries.filter { $0.startedAt >= start && $0.startedAt < end }.count
    }

    private func earningsStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
            Text(value).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
        }
    }

    private func totalStatCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 17, weight: .bold)).foregroundColor(.ssTextPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 11)).foregroundColor(.ssTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.ssTextSecondary)
            .kerning(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 4)
    }
}

// MARK: - Placeholder
struct PlaceholderView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.shiftBlue)
            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.ssTextPrimary)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundColor(.ssTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.darkBg.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

#Preview {
    ContentView()
}
