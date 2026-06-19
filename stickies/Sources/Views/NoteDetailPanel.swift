import SwiftUI

// MARK: - Right Panel: Note Properties (25%)

struct NoteDetailPanel: View {
    @EnvironmentObject var store: NotesStore
    @Binding var note: Note

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                RoundedRectangle(cornerRadius: 2)
                    .fill(note.color.fill)
                    .frame(width: 8, height: 8)
                Text("PROPERTIES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.35))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.selectedNoteID = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.06))

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Note preview
                    HStack(spacing: 12) {
                        Image(systemName: note.color.icon)
                            .font(.title2)
                            .foregroundColor(note.color.fill)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(note.title.isEmpty ? "Untitled" : note.title)
                                .font(.headline).foregroundColor(.white)
                            Text(note.isPinned ? "📌 PINNED" : "NOTE")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(note.color.fill.opacity(0.7))
                        }
                    }

                    // Stats
                    VStack(alignment: .leading, spacing: 6) {
                        StatRow(label: "Created", value: formatDate(note.createdAt))
                        StatRow(label: "Modified", value: formatDate(note.modifiedAt))
                        StatRow(label: "Characters", value: "\(note.content.count)")
                        StatRow(label: "Words", value: "\(wordCount)")
                        StatRow(label: "Lines", value: "\(lineCount)")
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // Color Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COLOR")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.25))

                        LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4), spacing: 8) {
                            ForEach(NoteColor.allCases, id: \.self) { color in
                                Button {
                                    var updated = note
                                    updated.color = color
                                    note = updated
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(color.fill)
                                            .frame(height: 28)
                                        if note.color == color {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.black.opacity(0.5))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // Font Size
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FONT SIZE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.25))

                        HStack(spacing: 4) {
                            ForEach(NoteFontSize.allCases, id: \.self) { size in
                                Button {
                                    var updated = note
                                    updated.fontSize = size
                                    note = updated
                                } label: {
                                    Text(size.label)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(note.fontSize == size ? .white : .white.opacity(0.4))
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(
                                            note.fontSize == size
                                                ? Color.white.opacity(0.1)
                                                : Color.clear
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider().background(Color.white.opacity(0.08))

                    // Pin Toggle
                    Button {
                        store.togglePin(note)
                    } label: {
                        HStack {
                            Image(systemName: note.isPinned ? "pin.slash.fill" : "pin.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                            Text(note.isPinned ? "Unpin Note" : "Pin Note")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.7))
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)

                    // Delete
                    Button {
                        store.deleteNote(note)
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.7))
                            Text("Delete Note")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.7))
                            Spacer()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.red.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
            }
        }
    }

    // MARK: - Helpers

    private var wordCount: Int {
        note.content.split(separator: " ").count + note.content.split(separator: "\n").count - 1
    }

    private var lineCount: Int {
        note.content.split(separator: "\n").count
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy 'at' h:mm a"
        return fmt.string(from: date)
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.white.opacity(0.25))
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
    }
}

// MARK: - Empty Detail Panel

struct EmptyDetailPanel: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.justify.left")
                .font(.system(size: 30))
                .foregroundColor(.white.opacity(0.08))
            Text("Note Properties")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.3))
            Text("Select a note to view\nand edit its properties.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.15))
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
}
