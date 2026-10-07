import SwiftUI

@main
struct KakatuApp: App {
    @StateObject private var store = PageStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1000, minHeight: 650)
                .preferredColorScheme(.dark)
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
            // Ensure standard edit commands (Cmd+A, Cmd+C, Cmd+V)
            CommandGroup(replacing: .textEditing) {
                Button("Undo") { NSApp.sendAction(Selector(("undo:")), to: nil, from: nil) }
                    .keyboardShortcut("z", modifiers: .command)
                Button("Cut") { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }
                    .keyboardShortcut("x", modifiers: .command)
                Button("Copy") { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
                    .keyboardShortcut("c", modifiers: .command)
                Button("Paste") { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }
                    .keyboardShortcut("v", modifiers: .command)
                Button("Select All") { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
                    .keyboardShortcut("a", modifiers: .command)
            }
        }
    }
}
