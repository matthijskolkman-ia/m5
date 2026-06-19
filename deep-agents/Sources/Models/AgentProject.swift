import Foundation

// MARK: - Agent Project

struct AgentProject: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var language: String
    var currentCode: String
    var originalCode: String
    var systemPrompt: String
    var status: AgentStatus
    var createdAt: Date
    var modifiedAt: Date
    var apiKey: String
    var model: String
    var outputDir: String
    var isMakeMode: Bool
    var group: String

    var effectiveSystemPrompt: String {
        if isMakeMode {
            return makeSystemPrompt
        }
        return systemPrompt
    }

    static func new(name: String = "New Agent", language: String = "swift") -> AgentProject {
        let now = Date()
        let dir = NSHomeDirectory() + "/Deepagent/\(name)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return AgentProject(
            name: name,
            description: "",
            language: language,
            currentCode: "",
            originalCode: "",
            systemPrompt: defaultSystemPrompt(language: language),
            status: .idle,
            createdAt: now,
            modifiedAt: now,
            apiKey: "",
            model: "deepseek-chat",
            outputDir: dir,
            isMakeMode: false,
            group: "Web Apps"
        )
    }

    private var makeSystemPrompt: String {
        """
You are an expert full-stack developer and project architect. You generate complete, runnable applications — a lite version of Figma Make.

OUTPUT FORMAT — For every file you create, use this exact format:

## File: path/to/filename.ext
```language
(complete file contents)
```

End with a ## README section.

RULES:
- Be concise and professional. No filler.
- Output EVERY file needed for the project to run.
- Use clear, descriptive file paths.
- Include a README with run instructions and dependencies.
- The project folder is ready — just output the files.
- If you need clarification, ask before generating.
"""
    }

    static func defaultSystemPrompt(language: String) -> String {
        """
You are an expert \(language) developer working in a formal, structured environment called DeepAgents.

RESPONSE FORMAT:
1. State what you have created in one clear sentence.
2. Provide the complete code in a fenced block (```\(language) ... ```).
3. End with a concise "README" section explaining how to run or use the code.

RULES:
- Be concise and professional. No excessive enthusiasm.
- Always output complete, runnable code in a single code block.
- The code will be saved to a file. Mention the filename.
- If you need clarification, ask before writing code.
- Do not include multiple code blocks unless they are separate files.
"""
    }
}

enum AgentStatus: String, CaseIterable, Codable {
    case idle
    case running
    case done
    case error

    var icon: String {
        switch self {
        case .idle:   return "circle"
        case .running: return "circle.dotted"
        case .done:   return "checkmark.circle.fill"
        case .error:  return "xmark.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .idle:   return "#888888"
        case .running: return "#3b82f6"
        case .done:   return "#22c55e"
        case .error:  return "#ef4444"
        }
    }
}

// MARK: - Agent Message (conversation)

struct AgentMessage: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var projectId: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - Languages

let supportedLanguages = [
    "swift", "python", "javascript", "typescript", "go", "rust",
    "ruby", "java", "kotlin", "c", "cpp", "php", "sql", "html", "css", "shell",
    "dart", "markdown", "yaml", "dockerfile", "json", "xml"
]

func fileExtension(for language: String) -> String {
    switch language {
    case "swift":      return "swift"
    case "python":     return "py"
    case "javascript": return "js"
    case "typescript": return "ts"
    case "go":         return "go"
    case "rust":       return "rs"
    case "ruby":       return "rb"
    case "java":       return "java"
    case "kotlin":     return "kt"
    case "c":          return "c"
    case "cpp":        return "cpp"
    case "php":        return "php"
    case "sql":        return "sql"
    case "html":       return "html"
    case "css":        return "css"
    case "dart":       return "dart"
    case "markdown":   return "md"
    case "yaml":       return "yaml"
    case "dockerfile": return "Dockerfile"
    case "json":       return "json"
    case "xml":        return "xml"
    case "shell":      return "sh"
    default:           return language
    }
}

// MARK: - Agent Groups

let agentGroups = ["Web Apps", "APIs & Services", "Infrastructure", "Misc"]

func languagesForGroup(_ group: String) -> [String] {
    switch group {
    case "Web Apps":        return ["html", "css", "javascript", "typescript", "dart", "python", "ruby", "php", "go"]
    case "APIs & Services": return ["python", "javascript", "typescript", "go", "rust", "java", "kotlin", "ruby", "swift", "json"]
    case "Infrastructure":  return ["shell", "python", "go", "rust", "sql", "c", "cpp", "yaml", "dockerfile"]
    default:               return supportedLanguages
    }
}
