import SwiftUI

@main
struct BndplyApp: App {
    var body: some Scene {
        WindowGroup {
            PlayerView()
                .frame(minWidth: 380, minHeight: 550)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 400, height: 620)
    }
}
