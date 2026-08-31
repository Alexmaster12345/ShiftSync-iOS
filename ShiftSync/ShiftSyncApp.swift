import SwiftUI

@main
struct ShiftSyncApp: App {
    init() {
        // Wake up LocationManager so it can receive geofence events at launch
        _ = LocationManager.shared
        if AppSettings.shared.locationAlertsEnabled && AppSettings.shared.hasWorkplaceCoordinates {
            LocationManager.shared.restoreMonitoring()
            LocationManager.shared.scheduleDailyAbsenceCheck()
        }
        // Activate Watch session so state syncs immediately on launch
        _ = WatchSessionManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
