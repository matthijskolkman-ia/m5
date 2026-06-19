# DeepAgents — AI Coding Agent Manager

> VS Code / Sublime–style macOS app for managing 56+ AI coding agents backed by the DeepSeek API.

## Quick Start

```bash
cd ~/Documents/m5/deep-agents
./build.sh
```

Launches from `~/Desktop/DeepAgents.app`.

---

## Architecture

```
deep-agents/
├── project.yml                    # XcodeGen spec (macOS 14.0)
├── build.sh                       # One-command build & launch
├── Sources/
│   ├── DeepAgentsApp.swift        # @main — hiddenTitleBar, 1400×850
│   ├── Info.plist
│   ├── Models/
│   │   └── AgentProject.swift     # AgentProject, AgentMessage, AgentStatus
│   ├── Services/
│   │   ├── DeepSeekService.swift  # Chat completions via api.deepseek.com/v1
│   │   └── Database.swift         # SQLite at ~/Library/Application Support/DeepAgents/
│   └── Views/
│       ├── ContentView.swift      # AgentStore + 3-panel layout
│       ├── AgentListSidebar.swift # Left 18% — paginated list (14/page)
│       ├── CodeEditorView.swift   # Center 58% — code + chat tabs
│       ├── AgentDetailPanel.swift # Right 24% — settings, rollback, delete
│       └── ToolbarView.swift      # Bottom bar — quick actions, notifications
```

### 3-Panel Layout

| Panel | Width | Purpose |
|---|---|---|
| **Left** | 18% | Agent list with pagination (14 per page), status indicators |
| **Center** | 58% | Chat-only — conversation, prompt input, progress indicator |
| **Right** | 24% | API key, system prompt, language, Make Mode toggle, rollback, delete |
| **Bottom bar** | 100% | Run, Rollback, Clear Chat, quick prompt, notification, agent count |

### Data Model

- **AgentProject**: name, language, currentCode, originalCode, systemPrompt, apiKey, model, status, outputDir, isMakeMode
- **AgentMessage**: projectId, role (user/assistant/system), content, timestamp
- **AgentStatus**: idle → running → done/error

### Output & Auto-Save

- Each agent writes to `~/Deepagent/<name>/`
- **Standard mode**: saves `<name>.<ext>` + `README.md`
- **Make Mode**: parses `## File: path/name` blocks, saves full project tree with directory structure
- "Open Output Folder" button in the right panel

### Make Mode

- Toggle in the right panel — switches agent to a full-stack architect persona
- Agent outputs multi-file projects using `## File: src/index.html` + code block format
- All files saved maintaining directory structure under the output folder
- Built-in system prompt defines the response format

### API Integration

- Endpoint: `POST https://api.deepseek.com/v1/chat/completions`
- Auth: `Bearer <apiKey>` header
- Model: `deepseek-chat` (configurable)
- Request: system prompt + last 20 messages + current code + user instruction
- Response: `choices[0].message.content`
- Code extraction: parses first ``` fenced block from response

---

## Known Improvements

### 🔴 Critical

- [ ] **Keychain storage** — API keys currently stored in plain-text SQLite. Should use `SecItemAdd`/`SecItemCopyMatching`.
- [ ] **Concurrency limiter** — Running 56 agents simultaneously will hit DeepSeek rate limits. Cap at 3–5 parallel `Task`s with an `AsyncSemaphore` or `TaskGroup`.
- [ ] **Retry/backoff** — No retry logic on API failures. Add exponential backoff for 429/5xx responses.

### 🟡 Nice-to-have

- [ ] **SSE streaming** — DeepSeek supports `stream: true` for token-by-token responses. Would make the chat feel snappier.
- [ ] **Code diff view** — Show a diff between `originalCode` and `currentCode` instead of just replacing.
- [ ] **Multi-code-block extraction** — Currently only extracts the first ``` block. The model may return multiple files.
- [ ] **Batch run mode** — Select multiple agents and run the same prompt across all of them.
- [ ] **Agent templates** — Pre-built system prompts for different tasks (refactor, add tests, fix bugs, explain code).
- [ ] **Export/import** — Export agent conversations as Markdown or JSON.
- [ ] **Syntax highlighting** — Basic colorization for keywords, strings, comments.
- [ ] **Keyboard shortcuts** — ⌘R to run, ⌘Z to rollback, ⌘N new agent, etc.

### 🟢 Polish

- [ ] App icon
- [ ] Drag-and-drop reorder agents in sidebar
- [ ] Search/filter agents
- [ ] Dark/light mode toggle (currently dark-only)
- [ ] Agent grouping / folders
- [ ] Progress bar for multi-agent runs

---

## Database

- Path: `~/Library/Application Support/DeepAgents/deepagents.sqlite3`
- Tables: `projects`, `messages`
- Foreign key: `messages.project_id → projects.id` (CASCADE delete)

To inspect:
```bash
sqlite3 ~/Library/Application\ Support/DeepAgents/deepagents.sqlite3 ".tables"
sqlite3 ~/Library/Application\ Support/DeepAgents/deepagents.sqlite3 "SELECT id, name, status FROM projects;"
```
