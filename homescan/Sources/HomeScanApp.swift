import SwiftUI

@main
struct HomeScanApp: App {
    var body: some Scene {
        WindowGroup {
            HomeScanView()
                .frame(minWidth: 280, maxWidth: 280, minHeight: 220, maxHeight: 220)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 280, height: 220)
    }
}
