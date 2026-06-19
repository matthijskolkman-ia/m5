import SwiftUI
import AppKit

// MARK: - Agent Store

final class AgentStore: ObservableObject {
    @Published var projects: [AgentProject] = []
    @Published var selectedProjectID: UUID?
    @Published var messages: [AgentMessage] = []
    @Published var currentPage: Int = 0
    @Published var notification: String?
    @Published var isRunning: Bool = false
    @Published var runningAgents: Set<UUID> = []
    @Published var selectedForBulk: Set<UUID> = []
    @Published var bulkMode = false

    var isAnyRunning: Bool { !runningAgents.isEmpty }

    let pageSize = 14
    private let db = Database()

    var selectedProject: AgentProject? {
        guard let id = selectedProjectID else { return nil }
        return projects.first { $0.id == id }
    }

    var totalPages: Int {
        max(1, Int(ceil(Double(projects.count) / Double(pageSize))))
    }

    var pagedProjects: [AgentProject] {
        let start = currentPage * pageSize
        return Array(projects.dropFirst(start).prefix(pageSize))
    }

    init() {
        projects = db.allProjects()
        if !projects.isEmpty { selectProject(projects[0]) }
    }

    // MARK: - Actions

    func createProject(name: String = "New Agent", language: String = "swift") {
        let p = AgentProject.new(name: name, language: language)
        db.insertProject(p)
        projects = db.allProjects()
        selectProject(p)
    }

    func deleteProject(_ p: AgentProject) {
        db.deleteProject(p.id)
        projects = db.allProjects()
        if selectedProjectID == p.id { selectedProjectID = projects.first?.id }
    }

    func updateProject(_ p: AgentProject) {
        var updated = p
        updated.modifiedAt = Date()
        db.updateProject(updated)
        projects = db.allProjects()
    }

    func selectProject(_ p: AgentProject) {
        selectedProjectID = p.id
        messages = db.messagesForProject(p.id)
    }

    func rollbackCode() {
        guard var p = selectedProject else { return }
        p.currentCode = p.originalCode
        p.modifiedAt = Date()
        db.updateProject(p)
        projects = db.allProjects()
        notify("Rolled back to original code")
    }

    func clearConversation() {
        guard let p = selectedProject else { return }
        db.deleteMessages(for: p.id)
        messages = []
        notify("Conversation cleared")
    }

    // MARK: - DeepSeek Iteration

    func runAgent(prompt: String) {
        guard let project = selectedProject, !runningAgents.contains(project.id) else { return }
        guard !project.apiKey.isEmpty else {
            notify("Set your DeepSeek API key first (right panel)")
            return
        }

        let projectId = project.id
        let apiKey = project.apiKey
        let model = project.model
        let systemPrompt = project.effectiveSystemPrompt
        let currentCode = project.currentCode

        runningAgents.insert(projectId)
        isRunning = true
        db.updateProject(AgentProject(
            id: projectId, name: project.name, description: project.description,
            language: project.language, currentCode: currentCode, originalCode: project.originalCode,
            systemPrompt: systemPrompt, status: .running, createdAt: project.createdAt,
            modifiedAt: Date(), apiKey: apiKey, model: model, outputDir: project.outputDir, isMakeMode: project.isMakeMode, group: project.group
        ))
        projects = db.allProjects()

        // Save user message
        let userMsg = AgentMessage(projectId: projectId, role: .user, content: prompt, timestamp: Date())
        db.insertMessage(userMsg)
        messages.append(userMsg)

        // Build conversation
        let filename = "main.\(fileExtension(for: project.language))"
        var apiMessages: [DeepSeekService.ChatMessage] = [
            .init(role: "system", content: systemPrompt),
            .init(role: "system", content: "The output file is named `\(filename)` (standard \(project.language) entry point). Use this exact filename in your README instructions.")
        ]
        for m in messages.suffix(20) {
            apiMessages.append(.init(role: m.role.rawValue, content: m.content))
        }
        apiMessages.append(.init(role: "user", content: "Here is the current code:\n```\n\(currentCode)\n```\n\nInstruction: \(prompt)"))

        Task {
            do {
                let response = try await DeepSeekService.shared.send(
                    messages: apiMessages, apiKey: apiKey, model: model
                )
                let asstMsg = AgentMessage(projectId: projectId, role: .assistant, content: response, timestamp: Date())
                await MainActor.run {
                    db.insertMessage(asstMsg)
                    messages.append(asstMsg)
                    let reloaded = db.allProjects()
                    if var p = reloaded.first(where: { $0.id == projectId }) {
                        if p.isMakeMode {
                            saveMultiFile(response: response, project: p)
                        } else if let code = extractCodeBlock(from: response) {
                            p.originalCode = p.currentCode
                            p.currentCode = code
                            saveCodeToFile(code: code, project: p)
                        }
                        saveReadme(response: response, project: p)
                        p.status = .done
                        p.modifiedAt = Date()
                        db.updateProject(p)
                    }
                    projects = db.allProjects()
                    runningAgents.remove(projectId)
                    isRunning = !runningAgents.isEmpty
                    notify("Agent iteration complete")
                }
            } catch {
                await MainActor.run {
                    let errMsg = AgentMessage(projectId: projectId, role: .system, content: "❌ \(error.localizedDescription)", timestamp: Date())
                    db.insertMessage(errMsg)
                    messages.append(errMsg)
                    let reloaded = db.allProjects()
                    if var p = reloaded.first(where: { $0.id == projectId }) {
                        p.status = .error
                        p.modifiedAt = Date()
                        db.updateProject(p)
                    }
                    runningAgents.remove(projectId)
                    isRunning = !runningAgents.isEmpty
                    isRunning = false
                    notify("Error: \(error.localizedDescription)")
                }
            }
        }
    }

    func notify(_ msg: String) {
        notification = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.notification == msg { self.notification = nil }
        }
    }
}

private func extractCodeBlock(from text: String) -> String? {
    guard let start = text.range(of: "```") else { return nil }
    let afterStart = text[start.upperBound...]
    // Skip optional language identifier
    let codeStart: Substring
    if let newline = afterStart.firstIndex(of: "\n") {
        codeStart = afterStart[afterStart.index(after: newline)...]
    } else {
        codeStart = afterStart
    }
    guard let end = codeStart.range(of: "```") else { return nil }
    return String(codeStart[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
}

private func saveCodeToFile(code: String, project: AgentProject) {
    let dir = project.outputDir
    cleanDir(dir)
    let ext = fileExtension(for: project.language)
    let path = dir + "/main." + ext
    try? code.write(toFile: path, atomically: true, encoding: .utf8)
}

private func saveReadme(response: String, project: AgentProject) {
    let dir = project.outputDir
    // Don't strip code blocks — save the full response as README
    let content = """
# \(project.name)

\(response.trimmingCharacters(in: .whitespacesAndNewlines))

---
*Generated by DeepAgents · \(project.language)*
"""
    try? content.write(toFile: dir + "/README.md", atomically: true, encoding: .utf8)
}

private func saveMultiFile(response: String, project: AgentProject) {
    let dir = project.outputDir
    cleanDir(dir)

    let pattern = try? NSRegularExpression(
        pattern: "## File:\\s*(\\S+)\\s*\\n```(?:\\w+)?\\n([\\s\\S]*?)```",
        options: []
    )
    let range = NSRange(response.startIndex..<response.endIndex, in: response)
    pattern?.enumerateMatches(in: response, options: [], range: range) { match, _, _ in
        guard let match, match.numberOfRanges >= 3,
              let fileRange = Range(match.range(at: 1), in: response),
              let codeRange = Range(match.range(at: 2), in: response)
        else { return }
        let filePath = String(response[fileRange]).trimmingCharacters(in: .whitespaces)
        let code = String(response[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        let fullPath = dir + "/" + filePath
        let fileDir = (fullPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: fileDir, withIntermediateDirectories: true)
        try? code.write(toFile: fullPath, atomically: true, encoding: .utf8)
    }
}

private func cleanDir(_ dir: String) {
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    if let files = try? FileManager.default.contentsOfDirectory(atPath: dir) {
        for file in files { try? FileManager.default.removeItem(atPath: dir + "/" + file) }
    }
}

// MARK: - Dashboard View

struct ContentView: View {
    @EnvironmentObject var store: AgentStore
    @State private var showChat = false
    @State private var showNewAgent = false
    @State private var newName = ""
    @State private var newGroup = "Web Apps"
    @State private var newLang = "swift"

    var grouped: [String: [AgentProject]] {
        Dictionary(grouping: store.projects, by: { $0.group })
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header with legend
                HStack {
                    Text("DeepAgents")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    // Legend
                    HStack(spacing: 10) {
                        LegendDot(color: .gray, label: "idle")
                        LegendDot(color: .blue, label: "running")
                        LegendDot(color: .green, label: "done")
                        LegendDot(color: .red, label: "error")
                    }
                    Spacer()
                    // Bulk toggle
                    Button {
                        store.bulkMode.toggle()
                        if !store.bulkMode { store.selectedForBulk = [] }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: store.bulkMode ? "checkmark.rectangle.stack.fill" : "rectangle.stack")
                                .font(.system(size: 11))
                            Text("Bulk")
                                .font(.system(size: 8, weight: .medium))
                        }
                        .foregroundColor(store.bulkMode ? .orange : .white.opacity(0.5))
                    }.buttonStyle(.plain).help("Bulk prompt mode")
                    Button {
                        newName = ""; showNewAgent = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16)).foregroundColor(.blue)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(red: 0.06, green: 0.06, blue: 0.10))

                // Preset quick-prompts (when in bulk mode)
                if store.bulkMode && !store.selectedForBulk.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(["Add tests", "Refactor", "Add error handling", "Write README", "Optimize"], id: \.self) { preset in
                            Button(preset) {
                                for id in store.selectedForBulk {
                                    if let p = store.projects.first(where: { $0.id == id }) {
                                        store.selectProject(p)
                                        store.runAgent(prompt: preset)
                                    }
                                }
                                store.selectedForBulk = []
                                store.bulkMode = false
                            }
                                .font(.system(size: 8)).foregroundColor(.white.opacity(0.5))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.white.opacity(0.04))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                        .buttonStyle(.plain)
                    }.padding(.horizontal, 10).padding(.vertical, 4)
                    Divider().background(Color.white.opacity(0.06))
                }

                Divider().background(Color.white.opacity(0.06))

                // Agent grid
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(agentGroups, id: \.self) { group in
                            if let agents = grouped[group], !agents.isEmpty {
                                AgentGroupSection(
                                    title: group.uppercased(),
                                    agents: agents,
                                    count: agents.count,
                                    onTap: { agent in
                                        if store.bulkMode {
                                            if store.selectedForBulk.contains(agent.id) {
                                                store.selectedForBulk.remove(agent.id)
                                            } else {
                                                store.selectedForBulk.insert(agent.id)
                                            }
                                        } else {
                                            store.selectProject(agent); showChat = true
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(14)
                }

                // Bottom bar
                HStack {
                    if let notif = store.notification {
                        Text(notif).font(.system(size: 9))
                            .foregroundColor(.white.opacity(0.4)).lineLimit(1)
                    }
                    Spacer()
                    Text("\(store.projects.count) agents · tap a block to chat")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white.opacity(0.2))
                    if store.isRunning {
                        ProgressView().scaleEffect(0.4)
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(Color(red: 0.05, green: 0.05, blue: 0.09))
            }

            // Chat sheet overlay
            if showChat, store.selectedProject != nil {
                ChatOverlay(onClose: { showChat = false })
                    .transition(.move(edge: .bottom))
            }
        }
        .background(Color(red: 0.03, green: 0.03, blue: 0.07))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showNewAgent) {
            newAgentSheet
        }
    }

    var newAgentSheet: some View {
        VStack(spacing: 14) {
            Text("New Agent").font(.headline).foregroundColor(.white)
            TextField("Name", text: $newName).textFieldStyle(.roundedBorder)
            Picker("Group", selection: $newGroup) {
                ForEach(agentGroups, id: \.self) { Text($0).tag($0) }
            }
            .onChange(of: newGroup) { _, g in
                let langs = languagesForGroup(g)
                if !langs.contains(newLang) { newLang = langs.first ?? "swift" }
            }
            Picker("Language", selection: $newLang) {
                ForEach(languagesForGroup(newGroup), id: \.self) { Text($0).tag($0) }
            }
            Button("Create") {
                let name = newName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                store.createProject(name: name, language: newLang)
                if var p = store.selectedProject {
                    p.group = newGroup; store.updateProject(p)
                }
                showNewAgent = false
            }
            .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 280, height: 260)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
    }
}

// MARK: - Legend Dot

struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(label).font(.system(size: 8)).foregroundColor(.white.opacity(0.3))
        }
    }
}

// MARK: - Agent Group Section

struct AgentGroupSection: View {
    @EnvironmentObject var store: AgentStore
    let title: String
    let agents: [AgentProject]
    let count: Int
    let onTap: (AgentProject) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
                Text("\(count)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.15))
            }

            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(agents.enumerated()), id: \.element.id) { idx, agent in
                    AgentBlock(
                        number: agents.startIndex + idx + 1 + startOffset,
                        agent: agent,
                        isSelected: store.selectedForBulk.contains(agent.id),
                        isBulkMode: store.bulkMode,
                        onTap: { onTap(agent) }
                    )
                }
            }
        }
    }

    // Offset for block numbering across groups
    var startOffset: Int {
        var offset = 0
        for group in agentGroups {
            if group == title { break }
            offset += (Dictionary(grouping: agents, by: { $0.group })[group]?.count ?? 0)
        }
        return offset
    }
}

// MARK: - Agent Block

struct AgentBlock: View {
    let number: Int
    let agent: AgentProject
    let isSelected: Bool
    let isBulkMode: Bool
    let onTap: () -> Void

    var statusColor: Color {
        Color(hex: agent.status.color)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                VStack(spacing: 2) {
                    Text("\(number)")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                    Text(agent.name.prefix(3))
                        .font(.system(size: 7))
                        .foregroundColor(isSelected ? .white.opacity(0.7) : .white.opacity(0.35))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.orange.opacity(0.25) : statusColor.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.orange : statusColor.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                )

                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.orange)
                                .offset(x: 4, y: -4)
                        }
                        Spacer()
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open Chat") { onTap() }
            Button("Delete", role: .destructive) { }
        }
    }
}

// MARK: - Chat Overlay

struct ChatOverlay: View {
    @EnvironmentObject var store: AgentStore
    @State private var prompt = ""
    @State private var showSettings = false
    @FocusState private var focused: Bool
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Circle().fill(Color(hex: store.selectedProject?.status.color ?? "#888"))
                        .frame(width: 6, height: 6)
                    Text(store.selectedProject?.name ?? "")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.35))
                    }.buttonStyle(.plain)
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16)).foregroundColor(.white.opacity(0.3))
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color(red: 0.08, green: 0.08, blue: 0.14))

                Divider().background(Color.white.opacity(0.08))

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(store.messages) { msg in
                                HStack(alignment: .top, spacing: 6) {
                                    Text(msg.role == .user ? "→" : "←")
                                        .font(.system(size: 9)).foregroundColor(.white.opacity(0.3))
                                    Text(msg.content)
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.75))
                                        .textSelection(.enabled)
                                }
                            }
                            if store.runningAgents.contains(store.selectedProject?.id ?? UUID()) {
                                HStack(spacing: 4) {
                                    ProgressView().scaleEffect(0.4)
                                    Text("Thinking…").font(.system(size: 9)).foregroundColor(.white.opacity(0.3))
                                }
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }.padding(10)
                    }
                    .frame(height: 160)
                    .onChange(of: store.messages.count) { _, _ in
                        withAnimation { proxy.scrollTo("bottom") }
                    }
                }

                Divider().background(Color.white.opacity(0.08))

                // Input
                HStack(spacing: 6) {
                    TextField("Prompt…", text: $prompt, axis: .vertical)
                        .focused($focused)
                        .textFieldStyle(.plain).font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .onSubmit { send() }
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 18))
                            .foregroundColor(prompt.trimmingCharacters(in: .whitespaces).isEmpty ? .white.opacity(0.2) : .blue)
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 10).padding(.vertical, 6)
            }
            .frame(height: 280)
            .background(Color(red: 0.06, green: 0.06, blue: 0.11))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .shadow(color: .black.opacity(0.5), radius: 20)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onAppear { focused = true }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
    }

    var settingsSheet: some View {
        VStack(spacing: 8) {
            Text("Agent Settings").font(.headline).foregroundColor(.white)
            if var project = store.selectedProject {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        // Group + Language row
                        HStack(spacing: 8) {
                            VStack(alignment: .leading) {
                                Text("GROUP").font(.system(size: 7, weight: .bold)).foregroundColor(.white.opacity(0.3))
                                Picker("", selection: Binding(
                                    get: { project.group },
                                    set: { project.group = $0; store.updateProject(project) }
                                )) {
                                    ForEach(agentGroups, id: \.self) { Text($0).tag($0).font(.system(size: 10)) }
                                }.labelsHidden()
                            }
                            VStack(alignment: .leading) {
                                Text("LANGUAGE").font(.system(size: 7, weight: .bold)).foregroundColor(.white.opacity(0.3))
                                Picker("", selection: Binding(
                                    get: { project.language },
                                    set: { project.language = $0; store.updateProject(project) }
                                )) {
                                    ForEach(languagesForGroup(project.group), id: \.self) { Text($0).tag($0).font(.system(size: 10)) }
                                }.labelsHidden()
                            }
                        }

                        // Make Mode toggle
                        Toggle("Make Mode (multi-file projects)", isOn: Binding(
                            get: { project.isMakeMode },
                            set: { project.isMakeMode = $0; store.updateProject(project) }
                        )).font(.system(size: 10))

                        // Output folder
                        HStack {
                            Text(project.outputDir).font(.system(size: 8, design: .monospaced)).foregroundColor(.white.opacity(0.3)).lineLimit(1)
                            Spacer()
                            Button("Open") { NSWorkspace.shared.open(URL(fileURLWithPath: project.outputDir)) }
                                .font(.system(size: 9))
                        }

                        Divider().background(Color.white.opacity(0.1))

                        Text("API Key").font(.system(size: 7, weight: .bold)).foregroundColor(.white.opacity(0.3))
                        SecureField("sk-…", text: Binding(
                            get: { project.apiKey },
                            set: { project.apiKey = $0; store.updateProject(project) }
                        )).textFieldStyle(.roundedBorder).font(.system(size: 10))

                        Text("Model").font(.system(size: 7, weight: .bold)).foregroundColor(.white.opacity(0.3))
                        TextField("deepseek-chat", text: Binding(
                            get: { project.model },
                            set: { project.model = $0; store.updateProject(project) }
                        )).textFieldStyle(.roundedBorder).font(.system(size: 10))

                        Text("System Prompt").font(.system(size: 7, weight: .bold)).foregroundColor(.white.opacity(0.3))
                        TextEditor(text: Binding(
                            get: { project.systemPrompt },
                            set: { project.systemPrompt = $0; store.updateProject(project) }
                        )).font(.system(size: 9)).frame(height: 50)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.1)))
                    }
                }
            }
            Button("Done") { showSettings = false }.buttonStyle(.borderedProminent)
        }
        .padding(16).frame(width: 340, height: 420)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
    }

    func send() {
        let p = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty, !store.runningAgents.contains(store.selectedProject?.id ?? UUID()) else { return }
        store.runAgent(prompt: p)
        prompt = ""
    }
}
