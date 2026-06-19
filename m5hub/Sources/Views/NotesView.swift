import SwiftUI

struct NotesView: View {
    @State private var notes: [Note] = []
    @State private var selectedNote: Note?
    @State private var showEditor = false
    @State private var editingNote = Note()

    var body: some View {
        NavigationStack {
            List {
                ForEach(notes) { note in
                    Button(action: {
                        editingNote = note
                        showEditor = true
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title).font(.headline).foregroundColor(.white)
                            Text(note.content.prefix(80))
                                .font(.caption).foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                }
                .onDelete { idx in
                    for i in idx { Database.shared.deleteNote(notes[i].id) }
                    loadNotes()
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                Button(action: {
                    editingNote = Note()
                    showEditor = true
                }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showEditor) {
                NoteEditorView(note: $editingNote, onSave: {
                    Database.shared.saveNote(editingNote)
                    loadNotes()
                    showEditor = false
                })
            }
            .onAppear { loadNotes() }
        }
    }

    private func loadNotes() {
        notes = Database.shared.allNotes()
    }
}

struct NoteEditorView: View {
    @Binding var note: Note
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $note.title)
                TextEditor(text: $note.content)
                    .frame(minHeight: 200)
            }
            .navigationTitle(note.id == 0 ? "New Note" : "Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                }
            }
        }
    }
}
