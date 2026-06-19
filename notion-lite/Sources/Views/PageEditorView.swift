import SwiftUI

// MARK: - Center: Page Editor (53%)

struct PageEditorView: View {
    @Binding var page: Page
    @FocusState private var focusedBlockID: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Cover
                CoverView(color: CoverColor(rawValue: page.coverColor)?.color ?? .gray)

                // Title area
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 10) {
                        Text(page.icon).font(.system(size: 48))
                        TextField("Untitled", text: Binding(
                            get: { page.title },
                            set: { page.title = $0 }
                        ))
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 40).padding(.top, 24).padding(.bottom, 20)
                }

                // Blocks
                VStack(spacing: 2) {
                    ForEach($page.blocks) { $block in
                        BlockRow(block: $block, focusedBlockID: _focusedBlockID, onDelete: {
                            deleteBlock(block)
                        }, onEnter: {
                            addBlockAfter(block)
                        })
                    }
                }
                .padding(.horizontal, 40).padding(.vertical, 10)

                // Add block button
                HStack(spacing: 6) {
                    ForEach(BlockType.allCases, id: \.self) { type in
                        Button {
                            addBlock(type)
                        } label: {
                            Image(systemName: type.icon)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.3))
                                .padding(6)
                        }
                        .buttonStyle(.plain)
                        .help(type.label)
                    }
                }
                .padding(.vertical, 16)

                Spacer().frame(height: 200)
            }
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.09))
    }

    // MARK: - Block Helpers

    private func addBlock(_ type: BlockType) {
        page.blocks.append(Block.new(type))
        focusedBlockID = page.blocks.last?.id
    }

    private func addBlockAfter(_ block: Block) {
        guard let idx = page.blocks.firstIndex(where: { $0.id == block.id }) else { return }
        let newBlock = Block.new(.paragraph)
        page.blocks.insert(newBlock, at: idx + 1)
        focusedBlockID = newBlock.id
    }

    private func deleteBlock(_ block: Block) {
        page.blocks.removeAll { $0.id == block.id }
        if page.blocks.isEmpty { page.blocks.append(Block.new(.paragraph)) }
    }
}

// MARK: - Cover

struct CoverView: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: 140)
            .overlay(alignment: .bottomTrailing) {
                Text("Cover")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(10)
            }
    }
}

// MARK: - Block Row

struct BlockRow: View {
    @Binding var block: Block
    @FocusState var focusedBlockID: UUID?
    var onDelete: () -> Void
    var onEnter: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            // Left gutter: drag handle + checkbox
            HStack(spacing: 4) {
                if block.type == .todo {
                    Button {
                        block.checked.toggle()
                    } label: {
                        Image(systemName: block.checked ? "checkmark.square.fill" : "square")
                            .font(.system(size: 14))
                            .foregroundColor(block.checked ? .green : .white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                } else if block.type == .bullet {
                    Text("•")
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 16)
                } else {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 9))
                        .foregroundColor(hover ? .white.opacity(0.3) : .clear)
                        .frame(width: 16)
                }
            }
            .frame(width: 20)

            // Content
            if block.type == .divider {
                Divider().background(Color.white.opacity(0.1)).padding(.vertical, 8)
            } else if block.type == .quote {
                HStack(spacing: 0) {
                    Rectangle().fill(Color.white.opacity(0.15)).frame(width: 3)
                    TextField("Quote", text: $block.content, axis: .vertical)
                        .focused($focusedBlockID, equals: block.id)
                        .textFieldStyle(.plain)
                        .font(fontFor(block.type))
                        .foregroundColor(.white.opacity(0.8))
                        .italic()
                        .padding(.leading, 10)
                }
            } else {
                TextField(placeholderFor(block.type), text: $block.content, axis: .vertical)
                    .focused($focusedBlockID, equals: block.id)
                    .textFieldStyle(.plain)
                    .font(fontFor(block.type))
                    .foregroundColor(textColor)
                    .strikethrough(block.type == .todo && block.checked)
                    .onSubmit { onEnter() }
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .onHover { hover = $0 }
        .contextMenu {
            ForEach(BlockType.allCases, id: \.self) { type in
                Button(type.label) { block.type = type }
            }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var textColor: Color {
        block.type == .todo && block.checked
            ? Color.white.opacity(0.25)
            : Color.white.opacity(0.8)
    }

    private func fontFor(_ type: BlockType) -> Font {
        switch type {
        case .heading1:  return .system(size: 26, weight: .bold)
        case .heading2:  return .system(size: 20, weight: .semibold)
        case .heading3:  return .system(size: 16, weight: .semibold)
        default:         return .system(size: 14, weight: .regular)
        }
    }

    private func placeholderFor(_ type: BlockType) -> String {
        switch type {
        case .heading1:  return "Heading 1"
        case .heading2:  return "Heading 2"
        case .heading3:  return "Heading 3"
        default:         return "Type something..."
        }
    }
}
