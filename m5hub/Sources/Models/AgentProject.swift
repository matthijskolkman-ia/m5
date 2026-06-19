import Foundation

struct AgentProject: Identifiable, Codable {
    var id: Int64
    var name: String
    var prompt: String
    var language: String
    var systemPrompt: String
    var group: String
    var outputDir: String
    var isMakeMode: Bool
    var createdAt: String

    init(id: Int64 = 0, name: String = "", prompt: String = "", language: String = "Swift",
         systemPrompt: String = "You are a helpful coding assistant.", group: String = "General",
         outputDir: String = "", isMakeMode: Bool = false, createdAt: String = "") {
        self.id = id
        self.name = name
        self.prompt = prompt
        self.language = language
        self.systemPrompt = systemPrompt
        self.group = group
        self.outputDir = outputDir
        self.isMakeMode = isMakeMode
        self.createdAt = createdAt.isEmpty ? ISO8601DateFormatter().string(from: Date()) : createdAt
    }
}

struct AgentMessage: Identifiable, Codable {
    var id: Int64
    var projectId: Int64
    var role: String // "user" or "assistant"
    var content: String
    var timestamp: String
}

enum AgentStatus: String {
    case idle, running, done, error
}

let supportedLanguages = [
    "Swift", "Python", "JavaScript", "TypeScript", "Go", "Rust",
    "Kotlin", "Java", "C++", "C#", "Ruby", "PHP",
    "HTML/CSS", "SQL", "Shell", "YAML", "JSON", "Markdown",
    "Dart", "R", "Lua", "Zig"
]

let agentGroups = ["General", "Backend", "Frontend", "Mobile", "Data", "DevOps", "Systems"]

func languagesForGroup(_ group: String) -> [String] {
    switch group {
    case "Mobile": return ["Swift", "Kotlin", "Java", "Dart", "TypeScript"]
    case "Frontend": return ["TypeScript", "JavaScript", "HTML/CSS", "Dart"]
    case "Backend": return ["Python", "Go", "Rust", "Java", "C#", "Ruby", "PHP", "Kotlin"]
    case "Data": return ["Python", "R", "SQL", "Python"]
    case "DevOps": return ["Shell", "YAML", "Go", "Python", "Rust"]
    case "Systems": return ["Rust", "C++", "Zig", "Go"]
    default: return supportedLanguages
    }
}

func fileExtension(_ lang: String) -> String {
    switch lang {
    case "Swift": return "swift"
    case "Python": return "py"
    case "JavaScript": return "js"
    case "TypeScript": return "ts"
    case "Go": return "go"
    case "Rust": return "rs"
    case "Kotlin": return "kt"
    case "Java": return "java"
    case "C++": return "cpp"
    case "C#": return "cs"
    case "Ruby": return "rb"
    case "PHP": return "php"
    case "HTML/CSS": return "html"
    case "SQL": return "sql"
    case "Shell": return "sh"
    case "YAML": return "yml"
    case "JSON": return "json"
    case "Markdown": return "md"
    case "Dart": return "dart"
    case "R": return "r"
    case "Lua": return "lua"
    case "Zig": return "zig"
    default: return "txt"
    }
}
