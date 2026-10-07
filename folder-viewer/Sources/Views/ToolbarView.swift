import SwiftUI

// MARK: - Toolbar

struct ToolbarView: View {
    @EnvironmentObject var store: FileStore
    @State private var goToSheet = false
    @State private var goToPath = ""

    var body: some View {
        HStack(spacing: 8) {
            // Navigation buttons
            HStack(spacing: 4) {
                Button(action: { store.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!store.canGoBack())

                Button(action: { store.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!store.canGoForward())

                Button(action: { store.goUp() }) {
                    Image(systemName: "chevron.up")
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .medium))

            // Sort controls
            Spacer()

            HStack(spacing: 2) {
                ForEach(FileStore.SortKey.allCases, id: \.self) { key in
                    SortButton(key: key)
                }
            }

            // Go To button
            Button(action: { goToSheet = true }) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $goToSheet) {
                GoToSheet(isPresented: $goToSheet)
            }
        }
        .foregroundColor(.white.opacity(0.7))
    }
}

// MARK: - Sort Button

struct SortButton: View {
    @EnvironmentObject var store: FileStore
    let key: FileStore.SortKey

    var body: some View {
        Button(action: { store.toggleSort(key) }) {
            HStack(spacing: 4) {
                Text(key.rawValue)
                    .font(.system(size: 11, weight: store.sortKey == key ? .bold : .regular))
                if store.sortKey == key {
                    Image(systemName: store.sortAscending ? "chevron.down" : "chevron.up")
                        .font(.system(size: 8))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(store.sortKey == key ? Color.white.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Go To Sheet

struct GoToSheet: View {
    @EnvironmentObject var store: FileStore
    @Binding var isPresented: Bool
    @State private var pathText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Go to Folder")
                .font(.headline)
                .foregroundColor(.white)

            TextField("/path/to/folder", text: $pathText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 400)
                .onSubmit { go() }

            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.escape)

                Button("Go") { go() }
                    .keyboardShortcut(.return)
                    .disabled(pathText.isEmpty)
            }
        }
        .padding(30)
        .background(Color(red: 0.10, green: 0.10, blue: 0.14))
        .onAppear {
            pathText = store.currentURL.path
        }
    }

    private func go() {
        let expanded = NSString(string: pathText).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            store.navigate(to: url)
        }
        isPresented = false
    }
}
