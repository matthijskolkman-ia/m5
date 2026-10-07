import SwiftUI
import AppKit

// MARK: - File List View

struct FileListView: View {
    @EnvironmentObject var store: FileStore

    var body: some View {
        if store.items.isEmpty && !store.isLoading {
            VStack(spacing: 12) {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.25))
                Text("Empty folder")
                    .foregroundColor(.white.opacity(0.4))
                    .font(.title3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.items) { item in
                        FileRow(item: item)
                            .onTapGesture(count: 2) {
                                store.openItem(item)
                            }
                            .onTapGesture(count: 1) {
                                store.selectedItem = item
                            }
                            .contextMenu {
                                Button("Open") { store.openItem(item) }
                                Divider()
                                Button("Reveal in Finder") { store.revealInFinder(item) }
                            }
                    }
                }
            }
        }
    }
}

// MARK: - File Row

struct FileRow: View {
    @EnvironmentObject var store: FileStore
    let item: FileItem

    var isSelected: Bool {
        store.selectedItem?.id == item.id
    }

    var body: some View {
        HStack(spacing: 0) {
            // Icon + Name
            HStack(spacing: 10) {
                Image(nsImage: item.icon)
                    .resizable()
                    .frame(width: 24, height: 24)

                Text(item.name)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .frame(width: 380, alignment: .leading)

            // Date Modified
            Text(item.dateDisplay)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 180, alignment: .leading)

            // Size
            Text(item.sizeDisplay)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 90, alignment: .trailing)

            // Kind
            Text(item.kind)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 120, alignment: .leading)
                .padding(.leading, 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.blue.opacity(0.25) : Color.clear)
        )
        .background(
            Rectangle()
                .fill(Color.white.opacity(0.015))
        )
        .onDrag {
            NSItemProvider(object: item.url as NSURL)
        }
    }
}
