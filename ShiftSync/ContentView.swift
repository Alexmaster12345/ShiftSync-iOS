import SwiftUI
import CoreLocation
import Combine

// MARK: - Root
struct ContentView: View {
    @StateObject private var store = ShiftStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @AppStorage("ss_user_name") private var userName: String = ""
    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if !userName.isEmpty {
                    MainTabView(userName: userName, store: store) {
                        userName = ""
                    }
                } else {
                    LoginView { name in
                        userName = name
                    }
                }
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(settings.appTheme.colorScheme)
        .onAppear {
            // The native LaunchScreen.storyboard is a static system snapshot and can't
            // animate. This SwiftUI overlay takes over the instant our code runs, plays
            // a brief entrance animation, then fades to reveal the real content beneath —
            // the standard way apps achieve an "animated splash" on iOS.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.5)) { showSplash = false }
            }
        }
    }
}

// MARK: - Splash

private struct SplashView: View {
    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0
    @State private var dotPhase = 0
    @State private var handRotation = false

    private let dotTimer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.97, green: 0.98, blue: 1.0), Color(red: 0.89, green: 0.93, blue: 0.99)],
                center: .center, startRadius: 20, endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                clockFace
                    .scaleEffect(scale)
                    .opacity(opacity)

                loadingDots

                VStack(spacing: 8) {
                    Text("ShiftSync")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.11, green: 0.15, blue: 0.2))

                    HStack(spacing: 8) {
                        Rectangle().fill(Color.shiftBlue.opacity(0.4)).frame(width: 28, height: 1)
                        Text("INTELLIGENT SYNC")
                            .font(.system(size: 11, weight: .semibold))
                            .kerning(2)
                            .foregroundColor(.shiftBlue)
                        Rectangle().fill(Color.shiftBlue.opacity(0.4)).frame(width: 28, height: 1)
                    }
                }
                .opacity(opacity)
            }
            .offset(y: -140)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                handRotation = true
            }
        }
        .onReceive(dotTimer) { _ in
            dotPhase = (dotPhase + 1) % 3
        }
    }

    private var clockFace: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 168, height: 168)
                .overlay(Circle().stroke(Color(red: 0.82, green: 0.86, blue: 0.93), lineWidth: 1.5))
                .shadow(color: Color.shiftBlue.opacity(0.12), radius: 24, y: 12)

            // Cardinal tick marks
            ForEach([0, 90, 180, 270], id: \.self) { deg in
                Capsule()
                    .fill(Color(red: 0.78, green: 0.82, blue: 0.9))
                    .frame(width: 3, height: 10)
                    .offset(y: -66)
                    .rotationEffect(.degrees(Double(deg)))
            }

            // Hand sweeps like a clock's second hand, giving the loading screen motion
            Capsule()
                .fill(Color.shiftBlue)
                .frame(width: 5, height: 58)
                .offset(y: -29)
                .rotationEffect(.degrees(handRotation ? 360 : 0))
        }
    }

    private var loadingDots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.shiftBlue.opacity(i == dotPhase ? 1.0 : 0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .opacity(opacity)
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
        // The tab bar is hosted in a bottom safeAreaInset instead of being floated
        // in a ZStack over the content. Overlaying interactive controls on top of a
        // full-screen NavigationStack/ScrollView causes the scroll view to win the
        // hit-test race for touches in the overlap region — which is exactly why only
        // some bar buttons responded. safeAreaInset gives the bar its own reserved,
        // non-overlapping region, so every button reliably receives taps.
        Group {
            switch selectedTab {
            case 0:
                NavigationStack {
                    HomeView(userName: userName, store: store)
                        .navigationBarHidden(true)
                }
            case 1:
                NavigationStack { CalendarView(store: store) }
            case 2:
                NavigationStack { WorkplaceTabView() }
            default:
                NavigationStack { ProfileView(userName: userName, store: store, onLogout: onLogout) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
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

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            tabBtn(icon: "house",    tag: 0, label: "Home")
            tabBtn(icon: "calendar", tag: 1, label: "Calendar")

            // + button inside the bar
            Button(action: { showAddSheet = true }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.shiftBlue)
                        .frame(width: 38, height: 38)
                        .rotationEffect(.degrees(45))
                        .shadow(color: Color.shiftBlue.opacity(0.45), radius: 10, x: 0, y: 4)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 52, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add Shift")

            tabBtn(icon: "map",      tag: 2, label: "Workplace")
            tabBtn(icon: "person",   tag: 3, label: "Profile")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: -4)
        )
        .padding(.horizontal, 40)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var safeAreaBottom: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows.first?.safeAreaInsets.bottom ?? 0
    }

    private func tabBtn(icon: String, tag: Int, label: String) -> some View {
        let isActive = selectedTab == tag
        let activeIcon = icon == "calendar" ? "calendar" : "\(icon).fill"
        return Button(action: { selectedTab = tag }) {
            ZStack {
                if isActive {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.shiftBlue)
                        .frame(width: 38, height: 38)
                }
                Image(systemName: isActive ? activeIcon : icon)
                    .font(.system(size: 18, weight: isActive ? .semibold : .regular))
                    .foregroundColor(isActive ? .white : Color(UIColor.secondaryLabel))
            }
            .frame(width: 52, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
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

                    Divider().background(Color.darkBg)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            settingIcon("dot.radiowaves.up.forward", color: .tealAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Detection Radius")
                                    .font(.system(size: 15)).foregroundColor(.ssTextPrimary)
                                Text("How close you need to be for alerts to fire")
                                    .font(.system(size: 11)).foregroundColor(.ssTextSecondary)
                            }
                            Spacer()
                        }
                        HStack(spacing: 8) {
                            ForEach([30.0, 75.0, 150.0, 300.0], id: \.self) { radius in
                                Button(action: {
                                    settings.geofenceRadius = radius
                                    if locationManager.isMonitoring { locationManager.restoreMonitoring() }
                                }) {
                                    Text(radius >= 1000 ? "\(Int(radius/1000))km" : "\(Int(radius))m")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(settings.geofenceRadius == radius ? .white : .ssTextSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(settings.geofenceRadius == radius ? Color.tealAccent : Color.darkBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("Smaller radii are more precise but less reliable — GPS accuracy makes anything under ~30m unlikely to trigger consistently.")
                            .font(.system(size: 10))
                            .foregroundColor(.ssTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
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

#Preview {
    ContentView()
}
