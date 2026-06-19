import SwiftUI

@main
struct SysMonApp: App {
    var body: some Scene {
        WindowGroup {
            SysMonView()
                .frame(minWidth: 300, maxWidth: 300, minHeight: 280, maxHeight: 280)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 300, height: 280)
    }
}
