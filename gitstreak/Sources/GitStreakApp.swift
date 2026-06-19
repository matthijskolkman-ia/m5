import SwiftUI

@main
struct GitStreakApp: App {
    var body: some Scene {
        WindowGroup {
            StreakView()
                .frame(minWidth: 240, maxWidth: 240, minHeight: 180, maxHeight: 180)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 240, height: 180)
    }
}
