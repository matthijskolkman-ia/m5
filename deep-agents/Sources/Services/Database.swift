import Foundation
import SQLite3

final class Database {
    private var db: OpaquePointer?

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("DeepAgents")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("deepagents.sqlite3")
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            print("⚠️ DeepAgents: failed to open database")
        }
        createTables()
    }

    deinit { sqlite3_close(db) }

    private func createTables() {
        exec("""
        CREATE TABLE IF NOT EXISTS projects (
            id            TEXT PRIMARY KEY NOT NULL,
            name          TEXT NOT NULL DEFAULT '',
            description   TEXT NOT NULL DEFAULT '',
            language      TEXT NOT NULL DEFAULT 'swift',
            current_code  TEXT NOT NULL DEFAULT '',
            original_code TEXT NOT NULL DEFAULT '',
            system_prompt TEXT NOT NULL DEFAULT '',
            status        TEXT NOT NULL DEFAULT 'idle',
            created_at    REAL NOT NULL,
            modified_at   REAL NOT NULL,
            api_key       TEXT NOT NULL DEFAULT '',
            model         TEXT NOT NULL DEFAULT 'deepseek-chat',
            output_dir    TEXT NOT NULL DEFAULT '',
            make_mode     INTEGER NOT NULL DEFAULT 0,
            agent_group   TEXT NOT NULL DEFAULT 'Web Apps'
        );
        """)
        exec("""
        CREATE TABLE IF NOT EXISTS messages (
            id         TEXT PRIMARY KEY NOT NULL,
            project_id TEXT NOT NULL,
            role       TEXT NOT NULL,
            content    TEXT NOT NULL DEFAULT '',
            timestamp  REAL NOT NULL,
            FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
        );
        """)
        exec("PRAGMA foreign_keys = ON;")
    }

    // MARK: - Projects

    func allProjects() -> [AgentProject] {
        let rows = query("SELECT * FROM projects ORDER BY modified_at DESC;")
        return rows.map(decodeProject)
    }

    func insertProject(_ p: AgentProject) {
        exec("""
        INSERT INTO projects (id,name,description,language,current_code,original_code,system_prompt,status,created_at,modified_at,api_key,model,output_dir,make_mode,agent_group)
        VALUES ('\(p.id.uuidString)','\(esc(p.name))','\(esc(p.description))','\(p.language)','\(esc(p.currentCode))','\(esc(p.originalCode))','\(esc(p.systemPrompt))','\(p.status.rawValue)',\(p.createdAt.timeIntervalSince1970),\(p.modifiedAt.timeIntervalSince1970),'\(esc(p.apiKey))','\(p.model)','\(esc(p.outputDir))',\(p.isMakeMode ? 1 : 0),'\(esc(p.group))');
        """)
    }

    func updateProject(_ p: AgentProject) {
        exec("""
        UPDATE projects SET name='\(esc(p.name))', description='\(esc(p.description))',
            language='\(p.language)', current_code='\(esc(p.currentCode))',
            original_code='\(esc(p.originalCode))', system_prompt='\(esc(p.systemPrompt))',
            status='\(p.status.rawValue)', modified_at=\(p.modifiedAt.timeIntervalSince1970), make_mode=\(p.isMakeMode ? 1 : 0), agent_group='\(esc(p.group))',
            api_key='\(esc(p.apiKey))', model='\(p.model)', output_dir='\(esc(p.outputDir))'
        WHERE id='\(p.id.uuidString)';
        """)
    }

    func deleteProject(_ id: UUID) {
        exec("DELETE FROM messages WHERE project_id='\(id.uuidString)';")
        exec("DELETE FROM projects WHERE id='\(id.uuidString)';")
    }

    // MARK: - Messages

    func messagesForProject(_ projectId: UUID) -> [AgentMessage] {
        let rows = query("SELECT * FROM messages WHERE project_id='\(projectId.uuidString)' ORDER BY timestamp;")
        return rows.map { row in
            AgentMessage(
                id: UUID(uuidString: row["id"] as? String ?? "") ?? UUID(),
                projectId: UUID(uuidString: row["project_id"] as? String ?? "") ?? UUID(),
                role: MessageRole(rawValue: row["role"] as? String ?? "user") ?? .user,
                content: row["content"] as? String ?? "",
                timestamp: Date(timeIntervalSince1970: row["timestamp"] as? Double ?? 0)
            )
        }
    }

    func insertMessage(_ m: AgentMessage) {
        exec("""
        INSERT INTO messages (id, project_id, role, content, timestamp)
        VALUES ('\(m.id.uuidString)','\(m.projectId.uuidString)','\(m.role.rawValue)','\(esc(m.content))',\(m.timestamp.timeIntervalSince1970));
        """)
    }

    func deleteMessages(for projectId: UUID) {
        exec("DELETE FROM messages WHERE project_id='\(projectId.uuidString)';")
    }

    func lastUserPrompt(for projectId: UUID) -> String? {
        let rows = query("SELECT content FROM messages WHERE project_id='\(projectId.uuidString)' AND role='user' ORDER BY timestamp DESC LIMIT 1;")
        return rows.first?["content"] as? String
    }

    // MARK: - Helpers

    private func decodeProject(_ row: [String: Any]) -> AgentProject {
        AgentProject(
            id: UUID(uuidString: row["id"] as? String ?? "") ?? UUID(),
            name: row["name"] as? String ?? "",
            description: row["description"] as? String ?? "",
            language: row["language"] as? String ?? "swift",
            currentCode: row["current_code"] as? String ?? "",
            originalCode: row["original_code"] as? String ?? "",
            systemPrompt: row["system_prompt"] as? String ?? "",
            status: AgentStatus(rawValue: row["status"] as? String ?? "idle") ?? .idle,
            createdAt: Date(timeIntervalSince1970: row["created_at"] as? Double ?? 0),
            modifiedAt: Date(timeIntervalSince1970: row["modified_at"] as? Double ?? 0),
            apiKey: row["api_key"] as? String ?? "",
            model: row["model"] as? String ?? "deepseek-chat",
            outputDir: row["output_dir"] as? String ?? "",
            isMakeMode: (row["make_mode"] as? Int64 ?? 0) != 0,
            group: row["agent_group"] as? String ?? "Web Apps"
        )
    }

    private func exec(_ sql: String) { sqlite3_exec(db, sql, nil, nil, nil) }

    private func query(_ sql: String) -> [[String: Any]] {
        var result: [[String: Any]] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            let colCount = sqlite3_column_count(stmt)
            while sqlite3_step(stmt) == SQLITE_ROW {
                var row: [String: Any] = [:]
                for i in 0..<colCount {
                    let name = String(cString: sqlite3_column_name(stmt, i))
                    switch sqlite3_column_type(stmt, i) {
                    case SQLITE_INTEGER: row[name] = sqlite3_column_int64(stmt, i)
                    case SQLITE_FLOAT:   row[name] = sqlite3_column_double(stmt, i)
                    case SQLITE_TEXT:    row[name] = String(cString: sqlite3_column_text(stmt, i))
                    default: break
                    }
                }
                result.append(row)
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    private func esc(_ s: String) -> String { s.replacingOccurrences(of: "'", with: "''") }
}
