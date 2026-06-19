import SwiftUI
import Combine

// MARK: - Observable Store

final class NotesStore: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selectedNoteID: UUID?

    var selectedNote: Note? {
        guard let id = selectedNoteID else { return nil }
        return notes.first { $0.id == id }
    }

    private let db = Database()

    init() { notes = db.allNotes() }

    // MARK: - Actions

    func createNote() {
        let note = Note.new()
        db.insert(note)
        notes = db.allNotes()
        selectedNoteID = note.id
    }

    func deleteNote(_ note: Note) {
        db.delete(id: note.id)
        notes = db.allNotes()
        if selectedNoteID == note.id { selectedNoteID = nil }
    }

    func updateNote(_ note: Note) {
        var updated = note
        updated.modifiedAt = Date()
        db.update(updated)
        notes = db.allNotes()
    }

    func togglePin(_ note: Note) {
        var updated = note
        updated.isPinned.toggle()
        updated.modifiedAt = Date()
        db.update(updated)
        notes = db.allNotes()
    }
}

// MARK: - Content View (3-Panel Layout)

struct ContentView: View {
    @EnvironmentObject var store: NotesStore

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // ── Left: Notes List (25%) ──
                NotesListSidebar()
                    .frame(width: geo.size.width * 0.25)
                    .background(Color(red: 0.06, green: 0.06, blue: 0.10))

                Divider().background(Color.white.opacity(0.08))

                // ── Center: Sticky Canvas (50%) ──
                if let note = store.selectedNote {
                    NoteCanvasView(note: binding(for: note))
                        .frame(width: geo.size.width * 0.50)
                } else {
                    EmptyCanvasView()
                        .frame(width: geo.size.width * 0.50)
                }

                Divider().background(Color.white.opacity(0.08))

                // ── Right: Detail Panel (25%) ──
                if let note = store.selectedNote {
                    NoteDetailPanel(note: binding(for: note))
                        .frame(width: geo.size.width * 0.25)
                } else {
                    EmptyDetailPanel()
                        .frame(width: geo.size.width * 0.25)
                }
            }
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .preferredColorScheme(.dark)
    }

    private func binding(for note: Note) -> Binding<Note> {
        Binding<Note>(
            get: { self.store.notes.first(where: { $0.id == note.id }) ?? note },
            set: { self.store.updateNote($0) }
        )
    }
}

// MARK: - Color Hex Helper

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
