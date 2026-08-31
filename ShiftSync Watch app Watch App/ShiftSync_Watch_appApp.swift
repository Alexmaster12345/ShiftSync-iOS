import SwiftUI

@main
struct ShiftSync_Watch_app_Watch_AppApp: App {
    @StateObject private var manager = WatchShiftManager.shared

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(manager)
        }
    }
}
