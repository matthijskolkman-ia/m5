import SwiftUI
import Foundation

/// Represents a single sticky note
struct Note: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var title: String
    var content: String
    var color: NoteColor
    var createdAt: Date
    var modifiedAt: Date
    var isPinned: Bool
    var fontSize: NoteFontSize

    static func new() -> Note {
        let now = Date()
        return Note(
            title: "New Note",
            content: "",
            color: NoteColor.allCases.randomElement() ?? .yellow,
            createdAt: now,
            modifiedAt: now,
            isPinned: false,
            fontSize: .medium
        )
    }
}

enum NoteColor: String, CaseIterable, Codable {
    case yellow
    case pink
    case green
    case blue
    case purple
    case orange
    case white
    case mint

    var fill: Color {
        switch self {
        case .yellow: return Color(red: 1.0, green: 0.94, blue: 0.47)
        case .pink:   return Color(red: 1.0, green: 0.71, blue: 0.76)
        case .green:  return Color(red: 0.73, green: 0.93, blue: 0.67)
        case .blue:   return Color(red: 0.67, green: 0.82, blue: 1.0)
        case .purple: return Color(red: 0.82, green: 0.73, blue: 1.0)
        case .orange: return Color(red: 1.0, green: 0.80, blue: 0.55)
        case .white:  return Color(red: 0.95, green: 0.95, blue: 0.92)
        case .mint:   return Color(red: 0.67, green: 0.95, blue: 0.88)
        }
    }

    var hexName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .yellow: return "sun.max.fill"
        case .pink:   return "heart.fill"
        case .green:  return "leaf.fill"
        case .blue:   return "drop.fill"
        case .purple: return "sparkles"
        case .orange: return "flame.fill"
        case .white:  return "doc.fill"
        case .mint:   return "leaf.arrow.circlepath"
        }
    }
}

enum NoteFontSize: String, CaseIterable, Codable {
    case small
    case medium
    case large

    var size: CGFloat {
        switch self {
        case .small:  return 12
        case .medium: return 14
        case .large:  return 18
        }
    }

    var label: String {
        rawValue.capitalized
    }
}
