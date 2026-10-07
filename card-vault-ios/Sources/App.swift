import SwiftUI

@main
struct CardVaultIOSApp: App {
    @StateObject private var connectivity = iOSConnectivity()
    @StateObject private var proximity = ProximityTracker()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
                .environmentObject(proximity)
        }
    }
}
