import SwiftUI

// MARK: - Left Sidebar: Agent List (18%)

struct AgentListSidebar: View {
    @EnvironmentObject var store: AgentStore
    @State private var newName = ""
    @State private var newLang = "swift"
    @State private var showNew = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cpu.fill")
                    .font(.caption).foregroundColor(.blue.opacity(0.7))
                Text("AGENTS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
                Text("\(store.projects.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 12).padding(.vertical, 10)

            Divider().background(Color.white.opacity(0.06))

            // New Agent
            Button {
                store.createProject()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(.body).foregroundColor(.blue)
                    Text("New Agent").font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color.white.opacity(0.03))
            }.buttonStyle(.plain)

            Divider().background(Color.white.opacity(0.06))

            // Agent list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(store.pagedProjects) { project in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                store.selectProject(project)
                            }
                        } label: {
                            AgentRow(project: project, isSelected: store.selectedProjectID == project.id)
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 36).background(Color.white.opacity(0.04))
                    }
                }.padding(.vertical, 2)
            }

            Spacer()

            // Pagination
            HStack(spacing: 4) {
                Button {
                    if store.currentPage > 0 { store.currentPage -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(store.currentPage > 0 ? .white.opacity(0.5) : .white.opacity(0.15))
                }
                .buttonStyle(.plain)
                .disabled(store.currentPage == 0)

                Text("\(store.currentPage + 1) / \(store.totalPages)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))

                Button {
                    if store.currentPage < store.totalPages - 1 { store.currentPage += 1 }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(store.currentPage < store.totalPages - 1 ? .white.opacity(0.5) : .white.opacity(0.15))
                }
                .buttonStyle(.plain)
                .disabled(store.currentPage >= store.totalPages - 1)
            }
            .padding(.vertical, 6)

            Text("\(store.projects.count) agents")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.15)).padding(.bottom, 8)
        }
    }
}

// MARK: - Agent Row

struct AgentRow: View {
    let project: AgentProject
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: project.status.icon)
                .font(.system(size: 9))
                .foregroundColor(Color(hex: project.status.color))

            VStack(alignment: .leading, spacing: 1) {
                Text(project.name).font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7)).lineLimit(1)
                Text(project.language).font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(isSelected ? Color.white.opacity(0.06) : Color.clear)
        .contextMenu {
            Button("Delete", role: .destructive) {
                // handled via store in parent
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
