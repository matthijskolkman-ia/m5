import SwiftUI
import AppKit

// MARK: - Right Panel: Agent Settings (24%)

struct AgentDetailPanel: View {
    @EnvironmentObject var store: AgentStore
    @State private var apiKeyInput: String = ""
    @State private var nameInput: String = ""
    @State private var descInput: String = ""
    @State private var promptInput: String = ""
    @State private var modelInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Circle().fill(Color(hex: store.selectedProject?.status.color ?? "#888")).frame(width: 8, height: 8)
                Text("SETTINGS")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.35))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { store.selectedProjectID = nil }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            Divider().background(Color.white.opacity(0.06))

            ScrollView {
                if var project = store.selectedProject {
                    VStack(alignment: .leading, spacing: 14) {
                    // Name
                    field("NAME", text: $nameInput, onChange: { project.name = $0; store.updateProject(project) })

                    // Language picker
                    Text("LANGUAGE").font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.25))
                    Picker("", selection: Binding(
                        get: { project.language },
                        set: { project.language = $0; store.updateProject(project) }
                    )) {
                        ForEach(supportedLanguages, id: \.self) { lang in
                            Text(lang).tag(lang).font(.system(size: 11))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, -4)

                    // Model
                    field("MODEL", text: Binding(
                        get: { project.model },
                        set: { project.model = $0; store.updateProject(project) }
                    ), onChange: { _ in })

                    Divider().background(Color.white.opacity(0.08))

                    // Make Mode toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MAKE MODE").font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.25))
                            Text("Generate multi-file projects").font(.system(size: 9)).foregroundColor(.white.opacity(0.2))
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { project.isMakeMode },
                            set: { project.isMakeMode = $0; store.updateProject(project) }
                        ))
                        .toggleStyle(.switch)
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // API Key
                    Text("API KEY").font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.25))
                    SecureField("sk-…", text: Binding(
                        get: { project.apiKey },
                        set: { project.apiKey = $0; store.updateProject(project) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(8)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    // System prompt
                    Text("SYSTEM PROMPT").font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.25))
                    TextEditor(text: Binding(
                        get: { project.systemPrompt },
                        set: { project.systemPrompt = $0; store.updateProject(project) }
                    ))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(height: 80)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    Divider().background(Color.white.opacity(0.08))

                    // Stats
                    VStack(alignment: .leading, spacing: 4) {
                        PropRow(label: "Status", value: project.status.rawValue.uppercased())
                        PropRow(label: "Messages", value: "\(store.messages.count)")
                        PropRow(label: "Lines", value: "\(project.currentCode.components(separatedBy: "\n").count)")
                        PropRow(label: "Language", value: project.language)
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // Open Output Folder
                    Button {
                        let dir = project.outputDir
                        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                        NSWorkspace.shared.open(URL(fileURLWithPath: dir))
                    } label: {
                        Label("Open Output Folder", systemImage: "folder")
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }.buttonStyle(.plain)

                    Button {
                        store.rollbackCode()
                    } label: {
                        Label("Rollback Code", systemImage: "arrow.uturn.backward")
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }.buttonStyle(.plain)

                    Button {
                        store.clearConversation()
                    } label: {
                        Label("Clear Chat", systemImage: "trash")
                            .font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }.buttonStyle(.plain)

                    Button {
                        store.deleteProject(project)
                    } label: {
                        Label("Delete Agent", systemImage: "trash.fill")
                            .font(.system(size: 11)).foregroundColor(.red.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }.buttonStyle(.plain)
                    }
                    .padding(14)
                } else {
                    Text("No project selected")
                        .foregroundColor(.white.opacity(0.3))
                        .padding(14)
                }
            }
        }
        .onAppear { loadFields() }
        .onChange(of: store.selectedProjectID) { _, _ in loadFields() }
    }

    private func loadFields() {
        guard let p = store.selectedProject else { return }
        apiKeyInput = p.apiKey
        nameInput = p.name
        descInput = p.description
        promptInput = p.systemPrompt
        modelInput = p.model
    }

    private func field(_ label: String, text: Binding<String>, onChange: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.25))
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.7))
                .padding(6)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .onChange(of: text.wrappedValue) { _, new in onChange(new) }
        }
    }
}

struct PropRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).font(.system(size: 8, weight: .bold)).foregroundColor(.white.opacity(0.25))
                .frame(width: 55, alignment: .leading)
            Text(value).font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.45))
        }
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "gearshape").font(.system(size: 28)).foregroundColor(.white.opacity(0.08))
            Text("Agent Settings").font(.subheadline).foregroundColor(.white.opacity(0.3))
            Text("Select an agent to configure\nAPI key, prompt, and more.")
                .font(.caption).foregroundColor(.white.opacity(0.15)).multilineTextAlignment(.center)
            Spacer()
        }
    }
}
