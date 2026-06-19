import SwiftUI

// MARK: - Page Store

final class PageStore: ObservableObject {
    @Published var pages: [Page] = []
    @Published var selectedPageID: UUID?
    var isSyncing = false
    private var historyBack: [UUID] = []
    private var historyForward: [UUID] = []

    private let db = Database()

    var selectedPage: Page? {
        guard let id = selectedPageID else { return nil }
        return pages.first { $0.id == id }
    }

    init() { pages = db.allPages() }

    func selectPage(_ id: UUID?) {
        isSyncing = true
        if let current = selectedPageID {
            historyBack.append(current)
            historyForward = []
        }
        selectedPageID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isSyncing = false
        }
    }

    func goBack() {
        guard let last = historyBack.popLast(), let current = selectedPageID else { return }
        historyForward.append(current)
        isSyncing = true
        selectedPageID = last
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.isSyncing = false }
    }

    func goForward() {
        guard let next = historyForward.popLast(), let current = selectedPageID else { return }
        historyBack.append(current)
        isSyncing = true
        selectedPageID = next
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.isSyncing = false }
    }

    func createPage() {
        var page = Page.new()
        page.coverColor = CoverColor.allCases.randomElement()!.rawValue
        db.insertPage(page)
        pages = db.allPages()
        selectedPageID = page.id
    }

    func deletePage(_ page: Page) {
        db.deletePage(page.id)
        pages = db.allPages()
        if selectedPageID == page.id { selectedPageID = nil }
    }

    func updatePage(_ page: Page) {
        guard !isSyncing else { return }
        var updated = page
        updated.modifiedAt = Date()
        db.updatePage(updated)
        pages = db.allPages()
    }

    func toggleFavorite(_ page: Page) {
        var updated = page
        updated.isFavorite.toggle()
        updated.modifiedAt = Date()
        db.updatePage(updated)
        pages = db.allPages()
    }
}

// MARK: - Content View (3-Panel)

struct ContentView: View {
    @EnvironmentObject var store: PageStore

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Left: Pages (22%)
                PageListSidebar()
                    .frame(width: geo.size.width * 0.22)
                    .background(Color(red: 0.06, green: 0.06, blue: 0.10))

                Divider().background(Color.white.opacity(0.08))

                // Center: Editor (53%)
                if let page = store.selectedPage {
                    PageEditorView(page: binding(for: page))
                        .frame(width: geo.size.width * 0.53)
                } else {
                    EmptyEditorView()
                        .frame(width: geo.size.width * 0.53)
                }

                Divider().background(Color.white.opacity(0.08))

                // Right: Properties (25%)
                if let page = store.selectedPage {
                    PageDetailPanel(page: binding(for: page))
                        .frame(width: geo.size.width * 0.25)
                } else {
                    EmptyDetailView()
                        .frame(width: geo.size.width * 0.25)
                }
            }
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .preferredColorScheme(.dark)
        .overlay(shortcutButtons)
    }

    // Hidden buttons for keyboard shortcuts
    var shortcutButtons: some View {
        VStack {
            // ⌘N — New Page
            Button("") { store.createPage() }
                .keyboardShortcut("n", modifiers: .command).hidden()
            // ⌘D — Toggle favorite on selected page
            Button("") {
                if let page = store.selectedPage { store.toggleFavorite(page) }
            }
                .keyboardShortcut("d", modifiers: .command).hidden()
            // ⌥⌫ — Delete selected page
            Button("") {
                if let page = store.selectedPage { store.deletePage(page) }
            }
                .keyboardShortcut(.delete, modifiers: .option).hidden()
        }
    }

    private func binding(for page: Page) -> Binding<Page> {
        Binding<Page>(
            get: { self.store.pages.first(where: { $0.id == page.id }) ?? page },
            set: { self.store.updatePage($0) }
        )
    }
}
