import SwiftUI

// MARK: - App Entry

@main
struct FolderViewerApp: App {
    @StateObject private var store = FileStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 900, minHeight: 500)
                .preferredColorScheme(.dark)
                .onAppear { store.loadDirectory() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1100, height: 650)
        .commands {
            CommandGroup(replacing: .toolbar) {
                Button("Go Back") { store.goBack() }
                    .keyboardShortcut("[", modifiers: .command)
                    .disabled(!store.canGoBack())
                Button("Go Forward") { store.goForward() }
                    .keyboardShortcut("]", modifiers: .command)
                    .disabled(!store.canGoForward())
                Button("Go Up") { store.goUp() }
                    .keyboardShortcut(.upArrow, modifiers: .command)
                Divider()
                Button("Go to Home") {
                    store.navigate(to: FileManager.default.homeDirectoryForCurrentUser)
                }.keyboardShortcut("H", modifiers: [.command, .shift])
                Button("Go to Desktop") {
                    store.navigate(to: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop"))
                }.keyboardShortcut("D", modifiers: [.command, .shift])
            }
        }
    }
}
