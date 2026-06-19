import Foundation
import SQLite3

class Database {
    static let shared = Database()
    private var db: OpaquePointer?

    private init() {
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("m5hub.sqlite").path
        if sqlite3_open(path, &db) != SQLITE_OK {
            print("DB open error: \(String(cString: sqlite3_errmsg(db)))")
        }
        createTables()
    }

    private func createTables() {
        exec("""
            CREATE TABLE IF NOT EXISTS notes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL DEFAULT 'New Note',
                content TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
        """)
        exec("""
            CREATE TABLE IF NOT EXISTS agents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                prompt TEXT NOT NULL DEFAULT '',
                language TEXT NOT NULL DEFAULT 'Swift',
                system_prompt TEXT NOT NULL DEFAULT 'You are a helpful coding assistant.',
                agent_group TEXT NOT NULL DEFAULT 'General',
                output_dir TEXT NOT NULL DEFAULT '',
                is_make_mode INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL
            );
        """)
        exec("""
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                project_id INTEGER NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                FOREIGN KEY (project_id) REFERENCES agents(id) ON DELETE CASCADE
            );
        """)
    }

    private func exec(_ sql: String) {
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            print("SQL error: \(String(cString: err!))")
            sqlite3_free(err)
        }
    }

    func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "'", with: "''")
    }

    // MARK: - Notes

    func allNotes() -> [Note] {
        var notes: [Note] = []
        let sql = "SELECT id, title, content, created_at, updated_at FROM notes ORDER BY updated_at DESC"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                notes.append(Note(
                    id: sqlite3_column_int64(stmt, 0),
                    title: String(cString: sqlite3_column_text(stmt, 1)),
                    content: String(cString: sqlite3_column_text(stmt, 2)),
                    createdAt: String(cString: sqlite3_column_text(stmt, 3)),
                    updatedAt: String(cString: sqlite3_column_text(stmt, 4))
                ))
            }
        }
        sqlite3_finalize(stmt)
        return notes
    }

    func saveNote(_ note: Note) {
        let now = ISO8601DateFormatter().string(from: Date())
        if note.id == 0 {
            exec("INSERT INTO notes (title, content, created_at, updated_at) VALUES ('\(escape(note.title))', '\(escape(note.content))', '\(now)', '\(now)')")
        } else {
            exec("UPDATE notes SET title='\(escape(note.title))', content='\(escape(note.content))', updated_at='\(now)' WHERE id=\(note.id)")
        }
    }

    func deleteNote(_ id: Int64) {
        exec("DELETE FROM notes WHERE id=\(id)")
    }

    // MARK: - Agents

    func allAgents() -> [AgentProject] {
        var agents: [AgentProject] = []
        let sql = "SELECT id, name, prompt, language, system_prompt, agent_group, output_dir, is_make_mode, created_at FROM agents ORDER BY created_at DESC"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                agents.append(AgentProject(
                    id: sqlite3_column_int64(stmt, 0),
                    name: String(cString: sqlite3_column_text(stmt, 1)),
                    prompt: String(cString: sqlite3_column_text(stmt, 2)),
                    language: String(cString: sqlite3_column_text(stmt, 3)),
                    systemPrompt: String(cString: sqlite3_column_text(stmt, 4)),
                    group: String(cString: sqlite3_column_text(stmt, 5)),
                    outputDir: String(cString: sqlite3_column_text(stmt, 6)),
                    isMakeMode: sqlite3_column_int(stmt, 7) != 0,
                    createdAt: String(cString: sqlite3_column_text(stmt, 8))
                ))
            }
        }
        sqlite3_finalize(stmt)
        return agents
    }

    func saveAgent(_ agent: AgentProject) {
        if agent.id == 0 {
            exec("INSERT INTO agents (name, prompt, language, system_prompt, agent_group, output_dir, is_make_mode, created_at) VALUES ('\(escape(agent.name))', '\(escape(agent.prompt))', '\(escape(agent.language))', '\(escape(agent.systemPrompt))', '\(escape(agent.group))', '\(escape(agent.outputDir))', \(agent.isMakeMode ? 1 : 0), '\(agent.createdAt)')")
        } else {
            exec("UPDATE agents SET name='\(escape(agent.name))', prompt='\(escape(agent.prompt))', language='\(escape(agent.language))', system_prompt='\(escape(agent.systemPrompt))', agent_group='\(escape(agent.group))', output_dir='\(escape(agent.outputDir))', is_make_mode=\(agent.isMakeMode ? 1 : 0) WHERE id=\(agent.id)")
        }
    }

    func deleteAgent(_ id: Int64) {
        exec("DELETE FROM messages WHERE project_id=\(id)")
        exec("DELETE FROM agents WHERE id=\(id)")
    }

    func messagesForAgent(_ projectId: Int64) -> [AgentMessage] {
        var msgs: [AgentMessage] = []
        let sql = "SELECT id, project_id, role, content, timestamp FROM messages WHERE project_id=\(projectId) ORDER BY id ASC"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                msgs.append(AgentMessage(
                    id: sqlite3_column_int64(stmt, 0),
                    projectId: sqlite3_column_int64(stmt, 1),
                    role: String(cString: sqlite3_column_text(stmt, 2)),
                    content: String(cString: sqlite3_column_text(stmt, 3)),
                    timestamp: String(cString: sqlite3_column_text(stmt, 4))
                ))
            }
        }
        sqlite3_finalize(stmt)
        return msgs
    }

    func saveMessage(_ msg: AgentMessage) {
        exec("INSERT INTO messages (project_id, role, content, timestamp) VALUES (\(msg.projectId), '\(escape(msg.role))', '\(escape(msg.content))', '\(msg.timestamp)')")
    }
}
