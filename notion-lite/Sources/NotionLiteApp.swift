import SwiftUI

@main
struct NotionLiteApp: App {
    @StateObject private var store = PageStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1000, minHeight: 650)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 750)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Page") {
                Button("New Page") { store.createPage() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Toggle Favorite") {
                    if let p = store.selectedPage { store.toggleFavorite(p) }
                }.keyboardShortcut("d", modifiers: .command)
                Divider()
                Button("Delete Page") {
                    if let p = store.selectedPage { store.deletePage(p) }
                }.keyboardShortcut(.delete, modifiers: .option)
            }
        }
    }
}
