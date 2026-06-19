import Foundation
import SQLite3

/// Thin SQLite3 wrapper for the Stickies app.
/// Uses the system SQLite3 that ships with macOS — no external dependencies.
final class Database {
    private var db: OpaquePointer?

    // MARK: - Init

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Stickies")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("stickies.sqlite3")
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            print("⚠️ Stickies: failed to open database at \(url.path)")
        }
        createTable()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Schema

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS notes (
            id          TEXT PRIMARY KEY NOT NULL,
            title       TEXT NOT NULL DEFAULT '',
            content     TEXT NOT NULL DEFAULT '',
            color       TEXT NOT NULL DEFAULT 'yellow',
            created_at  REAL NOT NULL,
            modified_at REAL NOT NULL,
            is_pinned   INTEGER NOT NULL DEFAULT 0,
            font_size   TEXT NOT NULL DEFAULT 'medium'
        );
        """
        exec(sql)
    }

    // MARK: - Public API

    func allNotes() -> [Note] {
        let sql = "SELECT * FROM notes ORDER BY is_pinned DESC, modified_at DESC;"
        var result: [Note] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let note = decode(stmt) { result.append(note) }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }

    func insert(_ note: Note) {
        let sql = """
        INSERT INTO notes (id, title, content, color, created_at, modified_at, is_pinned, font_size)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            bind(stmt, note: note)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func update(_ note: Note) {
        let sql = """
        UPDATE notes SET title=?, content=?, color=?, modified_at=?, is_pinned=?, font_size=?
        WHERE id=?;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (note.title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 2, (note.content as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 3, (note.color.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_double(stmt, 4, note.modifiedAt.timeIntervalSince1970)
            sqlite3_bind_int(stmt, 5, note.isPinned ? 1 : 0)
            sqlite3_bind_text(stmt, 6, (note.fontSize.rawValue as NSString).utf8String, -1, nil)
            sqlite3_bind_text(stmt, 7, (note.id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func delete(id: UUID) {
        let sql = "DELETE FROM notes WHERE id=?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Helpers

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private func bind(_ stmt: OpaquePointer?, note: Note) {
        sqlite3_bind_text(stmt, 1, (note.id.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (note.title as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (note.content as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (note.color.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 5, note.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 6, note.modifiedAt.timeIntervalSince1970)
        sqlite3_bind_int(stmt, 7, note.isPinned ? 1 : 0)
        sqlite3_bind_text(stmt, 8, (note.fontSize.rawValue as NSString).utf8String, -1, nil)
    }

    private func decode(_ stmt: OpaquePointer?) -> Note? {
        guard
            let idRaw    = sqlite3_column_text(stmt, 0),
            let titleRaw = sqlite3_column_text(stmt, 1),
            let contRaw  = sqlite3_column_text(stmt, 2),
            let colorRaw = sqlite3_column_text(stmt, 3),
            let fontRaw  = sqlite3_column_text(stmt, 7)
        else { return nil }

        return Note(
            id: UUID(uuidString: String(cString: idRaw)) ?? UUID(),
            title:      String(cString: titleRaw),
            content:    String(cString: contRaw),
            color:      NoteColor(rawValue: String(cString: colorRaw)) ?? .yellow,
            createdAt:  Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4)),
            modifiedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5)),
            isPinned:   sqlite3_column_int(stmt, 6) != 0,
            fontSize:   NoteFontSize(rawValue: String(cString: fontRaw)) ?? .medium
        )
    }
}
