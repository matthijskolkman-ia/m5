import SwiftUI

// MARK: - Path Bar (Breadcrumbs)

struct PathBarView: View {
    @EnvironmentObject var store: FileStore

    var components: [PathComponent] {
        var comps: [PathComponent] = []
        var url = store.currentURL
        var parts: [String] = []

        while url.path != "/" && url.path != "" {
            parts.insert(url.lastPathComponent, at: 0)
            url = url.deletingLastPathComponent()
        }
        if parts.isEmpty || store.currentURL.path == "/" {
            parts.insert("/", at: 0)
        }

        var builtURL = URL(fileURLWithPath: "/")
        for (i, part) in parts.enumerated() {
            if i > 0 { builtURL.appendPathComponent(part) }
            comps.append(PathComponent(name: i == 0 ? "" : part,
                                        displayName: i == 0 ? "Macintosh HD" : part,
                                        url: builtURL))
        }
        return comps
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(components.enumerated()), id: \.offset) { i, comp in
                    if i > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    Button(action: { store.navigate(to: comp.url) }) {
                        Text(i == 0 ? "🖥" : comp.displayName)
                            .font(.system(size: 12, weight: i == components.count - 1 ? .semibold : .regular))
                            .foregroundColor(i == components.count - 1 ? .white : .white.opacity(0.6))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

struct PathComponent {
    let name: String
    let displayName: String
    let url: URL
}
