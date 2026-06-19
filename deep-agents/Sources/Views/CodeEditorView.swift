import SwiftUI

// MARK: - Center: Agent Chat (58%)

struct CodeEditorView: View {
    @EnvironmentObject var store: AgentStore
    @State private var userPrompt: String = ""
    @FocusState private var promptFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let project = store.selectedProject {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color(hex: project.status.color))
                            .frame(width: 7, height: 7)
                        Text(project.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Text("· \(project.language) · \(project.outputDir)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.white.opacity(0.2))
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color(red: 0.05, green: 0.05, blue: 0.10))
            Divider().background(Color.white.opacity(0.06))

            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.messages) { msg in
                            ChatBubble(message: msg)
                        }
                        if store.isRunning {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.5)
                                Text("Agent thinking…").font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.3))
                            }.padding(.vertical, 6).padding(.horizontal, 10)
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(12)
                }
                .onChange(of: store.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom") }
                }
            }

            Divider().background(Color.white.opacity(0.06))

            // Prompt input
            HStack(spacing: 8) {
                TextField("Send a prompt…", text: $userPrompt, axis: .vertical)
                    .focused($promptFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onSubmit { sendPrompt() }

                Button(action: sendPrompt) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(
                            userPrompt.trimmingCharacters(in: .whitespaces).isEmpty
                                ? .white.opacity(0.2) : .blue
                        )
                }
                .buttonStyle(.plain)
                .disabled(store.isRunning || userPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.09))
    }

    private func sendPrompt() {
        let prompt = userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !store.isRunning else { return }
        store.runAgent(prompt: prompt)
        userPrompt = ""
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: AgentMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color.opacity(0.6))
                Text(message.content)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.8))
                    .textSelection(.enabled)
            }
            Spacer()
        }
    }

    private var icon: String {
        switch message.role {
        case .user:      return "person.circle.fill"
        case .assistant: return "cpu.fill"
        case .system:    return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch message.role {
        case .user:      return .blue
        case .assistant: return .green
        case .system:    return .orange
        }
    }

    private var label: String {
        switch message.role {
        case .user:      return "You"
        case .assistant: return "Agent"
        case .system:    return "System"
        }
    }
}

// MARK: - Empty State

struct EmptyEditorView: View {
    @EnvironmentObject var store: AgentStore
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.09)
            VStack(spacing: 16) {
                Image(systemName: "cpu").font(.system(size: 40)).foregroundColor(.white.opacity(0.1))
                Text("No Agent Selected").font(.title3.weight(.medium)).foregroundColor(.white.opacity(0.35))
                Text("Create or select an agent\nfrom the sidebar.")
                    .font(.caption).foregroundColor(.white.opacity(0.18)).multilineTextAlignment(.center)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { store.createProject() }
                } label: {
                    Label("New Agent", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.blue)
                }.buttonStyle(.plain).padding(.top, 4)
            }
        }
    }
}
