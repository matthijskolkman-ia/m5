import SwiftUI

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var store: FileStore
    @State private var sidebarWidth: CGFloat = 200

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            SidebarView()
                .frame(width: sidebarWidth)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)

            // Main area
            VStack(spacing: 0) {
                // Toolbar
                ToolbarView()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                // Path bar
                PathBarView()

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                // File list
                FileListView()
            }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
    }
}

// MARK: - Empty Detail

struct EmptyDetailView: View {
    var body: some View {
        VStack {
            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.25))
            Text("Select a folder to browse")
                .foregroundColor(.white.opacity(0.4))
                .font(.title3)
        }
    }
}
