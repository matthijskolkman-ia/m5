import SwiftUI

struct AgentsView: View {
    @State private var agents: [AgentProject] = []
    @State private var showNewAgent = false
    @State private var apiKey: String = UserDefaults.standard.string(forKey: "deepseek_key") ?? ""
    @State private var runningAgents: Set<Int64> = []

    let presets: [(String, String)] = [
        ("Add tests", "Write comprehensive unit tests"),
        ("Refactor", "Refactor for readability and performance"),
        ("Add error handling", "Add proper error handling"),
        ("Write README", "Write a detailed README.md"),
        ("Optimize", "Optimize for speed and memory")
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // API Key
                HStack {
                    TextField("DeepSeek API Key", text: $apiKey)
                        .font(.caption).textFieldStyle(.roundedBorder)
                    Button("Save") {
                        UserDefaults.standard.set(apiKey, forKey: "deepseek_key")
                    }.font(.caption)
                }.padding(.horizontal).padding(.top, 8)

                // Presets
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.0) { name, prompt in
                            Button(action: { createAgent(name: name, prompt: prompt) }) {
                                Text(name).font(.caption2)
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(Color.blue.opacity(0.3))
                                    .cornerRadius(12)
                            }
                        }
                    }.padding(.horizontal)
                }.padding(.vertical, 6)

                Divider()

                // Agent list
                List {
                    ForEach(agents) { agent in
                        NavigationLink(destination: AgentChatView(agent: agent, apiKey: apiKey, runningAgents: $runningAgents)) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(agent.name).font(.subheadline).foregroundColor(.white)
                                    if runningAgents.contains(agent.id) {
                                        ProgressView().scaleEffect(0.6)
                                    }
                                    Spacer()
                                    Text(agent.language).font(.caption2)
                                        .foregroundColor(.blue).padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2)).cornerRadius(4)
                                }
                                Text(agent.prompt.prefix(60)).font(.caption).foregroundColor(.gray).lineLimit(1)
                            }
                        }
                    }
                    .onDelete { idx in
                        for i in idx { Database.shared.deleteAgent(agents[i].id) }
                        loadAgents()
                    }
                }
            }
            .navigationTitle("AI Agents")
            .toolbar {
                Button(action: { showNewAgent = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showNewAgent) {
                NewAgentView(onCreate: { agent in
                    Database.shared.saveAgent(agent)
                    loadAgents()
                    showNewAgent = false
                })
            }
            .onAppear { loadAgents() }
        }
    }

    private func loadAgents() {
        agents = Database.shared.allAgents()
    }

    private func createAgent(name: String, prompt: String) {
        let agent = AgentProject(name: name, prompt: prompt)
        Database.shared.saveAgent(agent)
        loadAgents()
    }
}

struct NewAgentView: View {
    let onCreate: (AgentProject) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var prompt = ""
    @State private var language = "Swift"
    @State private var group = "General"
    @State private var systemPrompt = "You are a helpful coding assistant."

    var body: some View {
        NavigationStack {
            Form {
                TextField("Project name", text: $name)
                TextEditor(text: $prompt).frame(minHeight: 100)
                Picker("Language", selection: $language) {
                    ForEach(supportedLanguages, id: \.self) { Text($0) }
                }
                Picker("Group", selection: $group) {
                    ForEach(agentGroups, id: \.self) { Text($0) }
                }
                TextField("System prompt", text: $systemPrompt)
            }
            .navigationTitle("New Agent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let agent = AgentProject(name: name, prompt: prompt, language: language, systemPrompt: systemPrompt, group: group)
                        onCreate(agent)
                    }
                }
            }
        }
    }
}

struct AgentChatView: View {
    let agent: AgentProject
    let apiKey: String
    @Binding var runningAgents: Set<Int64>
    @State private var messages: [AgentMessage] = []
    @State private var input: String = ""
    @State private var status: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { msg in
                        HStack {
                            if msg.role == "user" { Spacer() }
                            Text(msg.content)
                                .font(.system(size: 13))
                                .padding(10)
                                .background(msg.role == "user" ? Color.blue.opacity(0.3) : Color.gray.opacity(0.2))
                                .cornerRadius(10)
                                .foregroundColor(.white)
                            if msg.role == "assistant" { Spacer() }
                        }
                    }
                    if !status.isEmpty {
                        Text(status).font(.caption).foregroundColor(.gray)
                    }
                }.padding()
            }

            Divider()

            HStack(spacing: 8) {
                TextField("Type message...", text: $input)
                    .textFieldStyle(.roundedBorder).font(.system(size: 13))
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(input.isEmpty ? .gray : .blue)
                }.disabled(input.isEmpty || runningAgents.contains(agent.id))
            }.padding()
        }
        .navigationTitle(agent.name)
        .onAppear { loadMessages() }
    }

    private func loadMessages() {
        messages = Database.shared.messagesForAgent(agent.id)
    }

    private func sendMessage() {
        guard !input.isEmpty else { return }
        let userMsg = AgentMessage(id: 0, projectId: agent.id, role: "user", content: input, timestamp: ISO8601DateFormatter().string(from: Date()))
        Database.shared.saveMessage(userMsg)
        messages.append(userMsg)
        input = ""

        runningAgents.insert(agent.id)
        status = "Thinking..."

        let svc = DeepSeekService(apiKey: apiKey)
        let chatMsgs = messages.map { ChatMessage(role: $0.role, content: $0.content) }

        Task {
            do {
                let response = try await svc.send(messages: chatMsgs, systemPrompt: agent.systemPrompt)
                let assistantMsg = AgentMessage(id: 0, projectId: agent.id, role: "assistant", content: response, timestamp: ISO8601DateFormatter().string(from: Date()))
                Database.shared.saveMessage(assistantMsg)
                await MainActor.run {
                    messages.append(assistantMsg)
                    status = ""
                    runningAgents.remove(agent.id)
                }
            } catch {
                await MainActor.run {
                    status = "Error: \(error.localizedDescription)"
                    runningAgents.remove(agent.id)
                }
            }
        }
    }
}
