import Foundation
import SQLite3

final class Database {
    private var db: OpaquePointer?

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("NotionLite")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("notionlite.sqlite3")
        if sqlite3_open(url.path, &db) != SQLITE_OK {
            print("⚠️ NotionLite: failed to open database")
        }
        createTables()
    }

    deinit { sqlite3_close(db) }

    // MARK: - Schema

    private func createTables() {
        exec("""
        CREATE TABLE IF NOT EXISTS pages (
            id          TEXT PRIMARY KEY NOT NULL,
            title       TEXT NOT NULL DEFAULT '',
            icon        TEXT NOT NULL DEFAULT '📄',
            cover_color TEXT NOT NULL DEFAULT 'gray',
            created_at  REAL NOT NULL,
            modified_at REAL NOT NULL,
            is_favorite INTEGER NOT NULL DEFAULT 0
        );
        """)
        exec("""
        CREATE TABLE IF NOT EXISTS blocks (
            id        TEXT PRIMARY KEY NOT NULL,
            page_id   TEXT NOT NULL,
            type      TEXT NOT NULL DEFAULT 'paragraph',
            content   TEXT NOT NULL DEFAULT '',
            checked   INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (page_id) REFERENCES pages(id) ON DELETE CASCADE
        );
        """)
        exec("PRAGMA foreign_keys = ON;")
    }

    // MARK: - Pages

    func allPages() -> [Page] {
        let rows = query("SELECT * FROM pages ORDER BY is_favorite DESC, modified_at DESC;")
        return rows.map { row in
            let id = row["id"] as? String ?? ""
            return Page(
                id: UUID(uuidString: id) ?? UUID(),
                title: row["title"] as? String ?? "",
                icon: row["icon"] as? String ?? "📄",
                coverColor: row["cover_color"] as? String ?? "gray",
                blocks: blocksForPage(id),
                createdAt: Date(timeIntervalSince1970: row["created_at"] as? Double ?? 0),
                modifiedAt: Date(timeIntervalSince1970: row["modified_at"] as? Double ?? 0),
                isFavorite: (row["is_favorite"] as? Int64 ?? 0) != 0
            )
        }
    }

    func insertPage(_ page: Page) {
        exec("""
        INSERT INTO pages (id, title, icon, cover_color, created_at, modified_at, is_favorite)
        VALUES ('\(page.id.uuidString)', '\(esc(page.title))', '\(page.icon)', '\(page.coverColor)',
                \(page.createdAt.timeIntervalSince1970), \(page.modifiedAt.timeIntervalSince1970), \(page.isFavorite ? 1 : 0));
        """)
        saveBlocks(page.id.uuidString, page.blocks)
    }

    func updatePage(_ page: Page) {
        exec("""
        UPDATE pages SET title='\(esc(page.title))', icon='\(page.icon)',
            cover_color='\(page.coverColor)', modified_at=\(page.modifiedAt.timeIntervalSince1970),
            is_favorite=\(page.isFavorite ? 1 : 0)
        WHERE id='\(page.id.uuidString)';
        """)
        saveBlocks(page.id.uuidString, page.blocks)
    }

    func deletePage(_ id: UUID) {
        exec("DELETE FROM blocks WHERE page_id='\(id.uuidString)';")
        exec("DELETE FROM pages WHERE id='\(id.uuidString)';")
    }

    // MARK: - Blocks

    private func blocksForPage(_ pageId: String) -> [Block] {
        let rows = query("SELECT * FROM blocks WHERE page_id='\(pageId)' ORDER BY sort_order;")
        return rows.map { row in
            Block(
                id: UUID(uuidString: row["id"] as? String ?? "") ?? UUID(),
                type: BlockType(rawValue: row["type"] as? String ?? "paragraph") ?? .paragraph,
                content: row["content"] as? String ?? "",
                checked: (row["checked"] as? Int64 ?? 0) != 0
            )
        }
    }

    private func saveBlocks(_ pageId: String, _ blocks: [Block]) {
        exec("DELETE FROM blocks WHERE page_id='\(pageId)';")
        for (i, block) in blocks.enumerated() {
            exec("""
            INSERT INTO blocks (id, page_id, type, content, checked, sort_order)
            VALUES ('\(block.id.uuidString)', '\(pageId)', '\(block.type.rawValue)',
                    '\(esc(block.content))', \(block.checked ? 1 : 0), \(i));
            """)
        }
    }

    // MARK: - SQL Helpers

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

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

    private func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "'", with: "''")
    }
}
