import SwiftUI

// MARK: - Bottom Toolbar

struct ToolbarView: View {
    @EnvironmentObject var store: AgentStore
    @State private var promptText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Divider().background(Color.white.opacity(0.08))

            HStack(spacing: 10) {
                // Quick-actions left
                HStack(spacing: 4) {
                    ToolBtn(icon: "play.fill", label: "Run", color: .green, disabled: store.isRunning || store.selectedProject == nil) {
                        guard !promptText.isEmpty else { return }
                        store.runAgent(prompt: promptText)
                        promptText = ""
                    }

                    ToolBtn(icon: "arrow.uturn.backward", label: "Rollback", color: .orange, disabled: store.selectedProject == nil) {
                        store.rollbackCode()
                    }

                    ToolBtn(icon: "trash", label: "Clear Chat", color: .gray, disabled: store.selectedProject == nil) {
                        store.clearConversation()
                    }
                }

                Divider().frame(height: 16).background(Color.white.opacity(0.1))

                // Quick prompt input
                HStack(spacing: 6) {
                    Image(systemName: "terminal")
                        .font(.system(size: 9)).foregroundColor(.white.opacity(0.25))
                    TextField("Quick prompt…", text: $promptText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .onSubmit {
                            guard !promptText.isEmpty else { return }
                            store.runAgent(prompt: promptText)
                            promptText = ""
                        }
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                // Status / notifications
                if let notif = store.notification {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 5, height: 5)
                        Text(notif).font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.5)).lineLimit(1)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.green.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .transition(.opacity)
                }

                // Agent count + page
                Text("\(store.projects.count) agents · pg \(store.currentPage + 1)/\(store.totalPages)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))

                // Running indicator
                if store.isRunning {
                    HStack(spacing: 4) {
                        ProgressView().scaleEffect(0.4)
                        Text("Running").font(.system(size: 9)).foregroundColor(.blue.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 6)
            .background(Color(red: 0.05, green: 0.05, blue: 0.09))
        }
    }
}

// MARK: - Toolbar Button

struct ToolBtn: View {
    let icon: String
    let label: String
    let color: Color
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 9))
                Text(label).font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(disabled ? .white.opacity(0.2) : color.opacity(0.8))
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(disabled ? Color.clear : color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}
