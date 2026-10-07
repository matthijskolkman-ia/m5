import SwiftUI

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var store: FileStore

    var body: some View {
        List(selection: Binding<UUID?>(
            get: { nil },
            set: { _ in }
        )) {
            Section("Favorites") {
                ForEach(store.sidebarFavorites) { loc in
                    SidebarRow(name: loc.name, icon: loc.icon)
                        .onTapGesture { store.navigate(to: loc.url) }
                }
            }

            if !store.volumes.isEmpty {
                Section("Volumes") {
                    ForEach(store.volumes) { vol in
                        SidebarRow(name: vol.name, icon: "externaldrive")
                            .onTapGesture { store.navigate(to: vol.url) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        .onAppear { store.refreshVolumes() }
    }
}

struct SidebarRow: View {
    let name: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.blue)
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.vertical, 2)
    }
}
