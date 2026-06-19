import SwiftUI

// MARK: - Left Sidebar: Notes List (25%)

struct NotesListSidebar: View {
    @EnvironmentObject var store: NotesStore

    private var sortedNotes: [Note] {
        store.notes.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.modifiedAt > b.modifiedAt
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "note.text")
                    .font(.caption).foregroundColor(.white.opacity(0.5))
                Text("NOTES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
                Text("\(store.notes.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.06))

            // New Note Button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { store.createNote() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body).foregroundColor(.yellow)
                    Text("New Note")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.white.opacity(0.03))
            }
            .buttonStyle(.plain)

            Divider().background(Color.white.opacity(0.06))

            // Notes List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(sortedNotes) { note in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                store.selectedNoteID = note.id
                            }
                        } label: {
                            NoteRowView(
                                note: note,
                                isSelected: store.selectedNoteID == note.id,
                                onPin: { store.togglePin(note) },
                                onDelete: { store.deleteNote(note) }
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 44)
                            .background(Color.white.opacity(0.04))
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()

            // Footer
            Text("Stickies · macOS · \(store.notes.count) notes")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.15))
                .padding(.bottom, 10)
        }
    }
}

// MARK: - Note Row

struct NoteRowView: View {
    let note: Note
    let isSelected: Bool
    let onPin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(note.color.fill)
                .frame(width: 4, height: 32)

            // Pin icon
            if note.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .rotationEffect(.degrees(45))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(note.title.isEmpty ? "Untitled" : note.title)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                    .lineLimit(1)

                Text(previewText)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.25))
                    .lineLimit(1)
            }

            Spacer()

            Text(formatDate(note.modifiedAt))
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.white.opacity(0.2))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(isSelected ? Color.white.opacity(0.06) : Color.clear)
        .contextMenu {
            Button("Toggle Pin") { onPin() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var previewText: String {
        let text = note.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "Empty note..." : text
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }
}
