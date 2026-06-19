import Foundation

struct Note: Identifiable, Codable {
    var id: Int64
    var title: String
    var content: String
    var createdAt: String
    var updatedAt: String

    init(id: Int64 = 0, title: String = "New Note", content: String = "", createdAt: String = "", updatedAt: String = "") {
        self.id = id
        self.title = title
        self.content = content
        let now = ISO8601DateFormatter().string(from: Date())
        self.createdAt = createdAt.isEmpty ? now : createdAt
        self.updatedAt = updatedAt.isEmpty ? now : updatedAt
    }
}
