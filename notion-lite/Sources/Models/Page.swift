import SwiftUI
import Foundation

// MARK: - Page

struct Page: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var title: String
    var icon: String
    var coverColor: String
    var blocks: [Block]
    var createdAt: Date
    var modifiedAt: Date
    var isFavorite: Bool

    static func new() -> Page {
        let now = Date()
        return Page(
            title: "Untitled",
            icon: "📄",
            coverColor: "gray",
            blocks: [Block(type: .paragraph, content: "")],
            createdAt: now,
            modifiedAt: now,
            isFavorite: false
        )
    }
}

// MARK: - Block

struct Block: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var type: BlockType
    var content: String
    var checked: Bool = false

    static func new(_ type: BlockType) -> Block {
        Block(type: type, content: "")
    }
}

enum BlockType: String, CaseIterable, Codable {
    case heading1
    case heading2
    case heading3
    case paragraph
    case bullet
    case todo
    case divider
    case quote

    var icon: String {
        switch self {
        case .heading1:  return "h.square.fill"
        case .heading2:  return "h.square"
        case .heading3:  return "h.square"
        case .paragraph: return "text.alignleft"
        case .bullet:    return "list.bullet"
        case .todo:      return "checklist"
        case .divider:   return "minus"
        case .quote:     return "quote.bubble"
        }
    }

    var label: String {
        switch self {
        case .heading1:  return "Heading 1"
        case .heading2:  return "Heading 2"
        case .heading3:  return "Heading 3"
        case .paragraph: return "Text"
        case .bullet:    return "Bullet List"
        case .todo:      return "To-do"
        case .divider:   return "Divider"
        case .quote:     return "Quote"
        }
    }
}

// MARK: - Cover Colors

enum CoverColor: String, CaseIterable {
    case gray, red, orange, yellow, green, teal, blue, purple, pink

    var color: Color {
        switch self {
        case .gray:   return Color(red: 0.35, green: 0.35, blue: 0.38)
        case .red:    return Color(red: 0.82, green: 0.23, blue: 0.23)
        case .orange: return Color(red: 0.85, green: 0.45, blue: 0.18)
        case .yellow: return Color(red: 0.82, green: 0.70, blue: 0.15)
        case .green:  return Color(red: 0.22, green: 0.58, blue: 0.32)
        case .teal:   return Color(red: 0.17, green: 0.63, blue: 0.59)
        case .blue:   return Color(red: 0.21, green: 0.47, blue: 0.78)
        case .purple: return Color(red: 0.51, green: 0.31, blue: 0.75)
        case .pink:   return Color(red: 0.78, green: 0.31, blue: 0.55)
        }
    }
}

// MARK: - Page Icons (preset)

let pageIcons = ["📄", "📝", "📋", "📌", "📎", "💡", "🎯", "⭐", "🔥", "🚀", "🧠", "💻", "📚", "🎨", "🔧", "🌱", "🗂️", "📊", "🏠", "✈️"]
