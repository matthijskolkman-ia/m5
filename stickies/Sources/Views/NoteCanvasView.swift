import SwiftUI

struct NoteCanvasView: View {
    @Binding var note: Note
    @State private var titleText: String
    @State private var bodyText: String
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isBodyFocused: Bool
    @State private var isSyncing = false

    init(note: Binding<Note>) {
        self._note = note
        self._titleText = State(initialValue: note.wrappedValue.title)
        self._bodyText = State(initialValue: note.wrappedValue.content)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(note.color.fill)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 3)

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.black.opacity(0.15))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .fill(Color.black.opacity(0.25))
                                .frame(width: 6, height: 6)
                        )
                        .offset(y: 2)
                    Spacer()
                }
                Spacer()
            }

            VStack(spacing: 6) {
                TextField("Title", text: $titleText)
                    .focused($isTitleFocused)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black.opacity(0.8))
                    .textFieldStyle(.plain)
                    .onChange(of: titleText) { _, new in
                        guard !isSyncing else { return }
                        var updated = note
                        updated.title = new
                        note = updated
                    }
                    .padding(.top, 22)

                Divider()
                    .background(Color.black.opacity(0.1))
                    .padding(.horizontal, 4)

                TextEditor(text: $bodyText)
                    .focused($isBodyFocused)
                    .font(.system(size: note.fontSize.size, weight: .regular))
                    .foregroundColor(.black.opacity(0.75))
                    .scrollContentBackground(.hidden)
                    .onChange(of: bodyText) { _, new in
                        guard !isSyncing else { return }
                        var updated = note
                        updated.content = new
                        note = updated
                    }
            }
            .padding(.horizontal, 28)

            VStack {
                Spacer()
                HStack {
                    Text(formatFullDate(note.modifiedAt))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.black.opacity(0.3))
                    Spacer()
                    Text("\(note.content.count) chars")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.black.opacity(0.3))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
        .padding(16)
        .onAppear {
            isSyncing = true
            titleText = note.title
            bodyText = note.content
            DispatchQueue.main.async { isSyncing = false }
        }
        .onChange(of: note.id) { _, _ in
            isSyncing = true
            titleText = note.title
            bodyText = note.content
            DispatchQueue.main.async { isSyncing = false }
        }
    }

    private func formatFullDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "E, MMM d 'at' h:mm a"
        return fmt.string(from: date)
    }
}

struct EmptyCanvasView: View {
    @EnvironmentObject var store: NotesStore
    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.09)
            VStack(spacing: 16) {
                Image(systemName: "note.text.badge.plus")
                    .font(.system(size: 40)).foregroundColor(.white.opacity(0.1))
                VStack(spacing: 6) {
                    Text("No Note Selected").font(.title3.weight(.medium)).foregroundColor(.white.opacity(0.35))
                    Text("Select a note from the sidebar\nor create a new one.")
                        .font(.caption).foregroundColor(.white.opacity(0.18)).multilineTextAlignment(.center)
                }
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { store.createNote() }
                } label: {
                    Label("Create Note", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.yellow)
                }.buttonStyle(.plain).padding(.top, 4)
            }
        }
    }
}
