import Foundation
import AppKit
import Combine

// MARK: - File Store

class FileStore: ObservableObject {
    @Published var currentURL: URL
    @Published var items: [FileItem] = []
    @Published var pathStack: [URL] = []
    @Published var forwardStack: [URL] = []
    @Published var selectedItem: FileItem? = nil
    @Published var sortKey: SortKey = .name
    @Published var sortAscending: Bool = true
    @Published var isLoading: Bool = false

    enum SortKey: String, CaseIterable {
        case name = "Name"
        case date = "Date Modified"
        case size = "Size"
        case kind = "Kind"
    }

    // MARK: Sidebar locations

    let sidebarFavorites: [SidebarLocation] = [
        SidebarLocation(name: "Home", icon: "house", url: FileManager.default.homeDirectoryForCurrentUser),
        SidebarLocation(name: "Desktop", icon: "desktopcomputer", url: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")),
        SidebarLocation(name: "Documents", icon: "doc", url: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")),
        SidebarLocation(name: "Downloads", icon: "arrow.down.circle", url: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")),
        SidebarLocation(name: "Applications", icon: "app.badge", url: URL(fileURLWithPath: "/Applications")),
    ]

    @Published var volumes: [SidebarLocation] = []

    init(startURL: URL? = nil) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.currentURL = startURL ?? home
        refreshVolumes()
    }

    // MARK: Navigation

    func navigate(to url: URL) {
        guard url != currentURL else { return }
        pathStack.append(currentURL)
        forwardStack.removeAll()
        currentURL = url
        selectedItem = nil
        loadDirectory()
    }

    func goBack() {
        guard let prev = pathStack.popLast() else { return }
        forwardStack.append(currentURL)
        currentURL = prev
        selectedItem = nil
        loadDirectory()
    }

    func goForward() {
        guard let next = forwardStack.popLast() else { return }
        pathStack.append(currentURL)
        currentURL = next
        selectedItem = nil
        loadDirectory()
    }

    func goUp() {
        let parent = currentURL.deletingLastPathComponent()
        navigate(to: parent)
    }

    func canGoBack() -> Bool { !pathStack.isEmpty }
    func canGoForward() -> Bool { !forwardStack.isEmpty }

    // MARK: Directory loading

    func loadDirectory() {
        isLoading = true
        defer { isLoading = false }

        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(
            at: currentURL,
            includingPropertiesForKeys: [
                .isDirectoryKey, .isPackageKey, .fileSizeKey,
                .contentModificationDateKey, .localizedTypeDescriptionKey,
                .effectiveIconKey
            ],
            options: [.skipsHiddenFiles]
        ) else {
            items = []
            return
        }

        items = urls.map { FileItem.from(url: $0) }
        sortItems()
    }

    // MARK: Sorting

    func sortItems() {
        items.sort { a, b in
            let result: Bool
            switch sortKey {
            case .name:
                result = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .date:
                let da = a.modificationDate ?? .distantPast
                let db = b.modificationDate ?? .distantPast
                result = da < db
            case .size:
                let sa = a.fileSize ?? 0
                let sb = b.fileSize ?? 0
                result = sa < sb
            case .kind:
                result = a.kind.localizedStandardCompare(b.kind) == .orderedAscending
            }
            return sortAscending ? result : !result
        }
        // Folders first
        items.sort { $0.isDirectory && !$1.isDirectory }
    }

    func toggleSort(_ key: SortKey) {
        if sortKey == key {
            sortAscending.toggle()
        } else {
            sortKey = key
            sortAscending = true
        }
        sortItems()
    }

    // MARK: Volumes

    func refreshVolumes() {
        let fm = FileManager.default
        let volURLs = fm.mountedVolumeURLs(includingResourceValuesForKeys: nil,
                                            options: .skipHiddenVolumes) ?? []
        volumes = volURLs.map { url in
            SidebarLocation(name: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
                            icon: "externaldrive",
                            url: url)
        }
    }

    // MARK: Open / Reveal

    func openItem(_ item: FileItem) {
        if item.isDirectory {
            navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func revealInFinder(_ item: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }
}

// MARK: - Sidebar Location

struct SidebarLocation: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let url: URL
}
