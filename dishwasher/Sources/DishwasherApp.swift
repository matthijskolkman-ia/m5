import SwiftUI

@main
struct DishwasherApp: App {
    var body: some Scene {
        WindowGroup {
            DishwasherView()
                .frame(minWidth: 210, maxWidth: 210, minHeight: 160, maxHeight: 160)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 210, height: 160)
    }
}
