import SwiftUI

// MARK: - Left Sidebar (22%)

struct PageListSidebar: View {
    @EnvironmentObject var store: PageStore

    private var sorted: [Page] {
        store.pages.sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            return a.modifiedAt > b.modifiedAt
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 4) {
                // Back/Forward
                HStack(spacing: 2) {
                    Button(action: { store.goBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.35))
                    }.buttonStyle(.plain)
                    Button(action: { store.goForward() }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.35))
                    }.buttonStyle(.plain)
                }
                Image(systemName: "square.grid.3x3.topleft.filled")
                    .font(.caption).foregroundColor(.white.opacity(0.5))
                Text("PAGES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
                Text("\(store.pages.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.06))

            // New Page
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { store.createPage() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(.body).foregroundColor(.blue)
                    Text("New Page").font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.white.opacity(0.03))
            }.buttonStyle(.plain)

            Divider().background(Color.white.opacity(0.06))

            // Page List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(sorted) { page in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                store.selectPage(page.id)
                            }
                        } label: {
                            PageRow(page: page, isSelected: store.selectedPageID == page.id)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 44).background(Color.white.opacity(0.04))
                    }
                }.padding(.vertical, 4)
            }

            Spacer()

            Text("NotionLite · macOS")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.15)).padding(.bottom, 10)
        }
    }
}

// MARK: - Page Row

struct PageRow: View {
    let page: Page
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(page.icon).font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text(page.title.isEmpty ? "Untitled" : page.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    .lineLimit(1)
                Text(page.modifiedAt, style: .date)
                    .font(.system(size: 9)).foregroundColor(.white.opacity(0.2))
            }
            Spacer()

            if page.isFavorite {
                Image(systemName: "star.fill").font(.system(size: 9))
                    .foregroundColor(.yellow.opacity(0.6))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(isSelected ? Color.white.opacity(0.06) : Color.clear)
    }
}
