import SwiftUI

// MARK: - Right Panel: Properties (25%)

struct PageDetailPanel: View {
    @EnvironmentObject var store: PageStore
    @Binding var page: Page

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle().fill(CoverColor(rawValue: page.coverColor)?.color ?? .gray)
                    .frame(width: 8, height: 8)
                Text("PROPERTIES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { store.selectPage(nil) }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            Divider().background(Color.white.opacity(0.06))

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Page preview
                    HStack(spacing: 12) {
                        Text(page.icon).font(.system(size: 32))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(page.title.isEmpty ? "Untitled" : page.title)
                                .font(.headline).foregroundColor(.white)
                            Text("\(page.blocks.count) blocks")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }

                    // Stats
                    VStack(alignment: .leading, spacing: 5) {
                        PropRow(label: "Created", value: page.createdAt.formatted(date: .abbreviated, time: .shortened))
                        PropRow(label: "Modified", value: page.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                        PropRow(label: "Blocks", value: "\(page.blocks.count)")
                        PropRow(label: "Chars", value: "\(totalChars)")
                        PropRow(label: "Todos", value: "\(todoCount)")
                    }
                    Divider().background(Color.white.opacity(0.08))

                    // Icon picker
                    Text("ICON").font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.25))
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 5), spacing: 6) {
                        ForEach(pageIcons, id: \.self) { icon in
                            Button {
                                page.icon = icon
                            } label: {
                                Text(icon).font(.system(size: 18))
                                    .frame(height: 30)
                                    .background(page.icon == icon ? Color.white.opacity(0.08) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }.buttonStyle(.plain)
                        }
                    }
                    Divider().background(Color.white.opacity(0.08))

                    // Cover color
                    Text("COVER COLOR").font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.25))
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4), spacing: 8) {
                        ForEach(CoverColor.allCases, id: \.self) { cc in
                            Button {
                                page.coverColor = cc.rawValue
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 4).fill(cc.color).frame(height: 26)
                                    if page.coverColor == cc.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }.buttonStyle(.plain)
                        }
                    }
                    Divider().background(Color.white.opacity(0.08))

                    // Favorite
                    Button {
                        store.toggleFavorite(page)
                    } label: {
                        HStack {
                            Image(systemName: page.isFavorite ? "star.slash.fill" : "star.fill")
                                .font(.system(size: 12)).foregroundColor(.white.opacity(0.5))
                            Text(page.isFavorite ? "Unfavorite" : "Add to Favorites")
                                .font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(.plain)

                    // Delete
                    Button {
                        store.deletePage(page)
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill").font(.system(size: 12)).foregroundColor(.red.opacity(0.7))
                            Text("Delete Page").font(.system(size: 12)).foregroundColor(.red.opacity(0.7))
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }.buttonStyle(.plain)
                    .keyboardShortcut(.delete, modifiers: .command)
                    }
                    .padding(16)
                }
            }
        }

    private var totalChars: Int { page.blocks.reduce(0) { $0 + $1.content.count } }
    private var todoCount: Int { page.blocks.filter { $0.type == .todo }.count }
}

// MARK: - Prop Row

struct PropRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.25))
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - Empty States

struct EmptyEditorView: View {
    @EnvironmentObject var store: PageStore
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.09)
            VStack(spacing: 16) {
                Image(systemName: "doc.text").font(.system(size: 40)).foregroundColor(.white.opacity(0.1))
                Text("No Page Selected").font(.title3.weight(.medium)).foregroundColor(.white.opacity(0.35))
                Text("Create or select a page\nfrom the sidebar.")
                    .font(.caption).foregroundColor(.white.opacity(0.18)).multilineTextAlignment(.center)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { store.createPage() }
                } label: {
                    Label("New Page", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.blue)
                }.buttonStyle(.plain).padding(.top, 4)
            }
        }
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "sidebar.right").font(.system(size: 28)).foregroundColor(.white.opacity(0.08))
            Text("Page Properties").font(.subheadline).foregroundColor(.white.opacity(0.3))
            Text("Select a page to view\nand edit properties.")
                .font(.caption).foregroundColor(.white.opacity(0.15)).multilineTextAlignment(.center)
            Spacer()
        }
    }
}
