import SwiftUI

// MARK: - Pack Card List View (detail of one pack)

struct PackCardListView: View {
    @EnvironmentObject var store: CardStore
    let pack: Pack
    let boxID: UUID
    @State private var showSellPackSheet = false
    @State private var showSellCardSheet = false
    @State private var cardToSell: Card?
    @State private var showAddCardSheet = false

    var sortedCards: [Card] {
        pack.cards.sorted(by: { $0.position < $1.position })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Pack info bar
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pack #\(pack.position)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        Text("Serial: \(pack.serialCode)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .textSelection(.enabled)
                    }

                    Spacer()

                    // Status
                    if pack.isSold {
                        Label("SOLD", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.green)
                    } else if pack.isFullySold {
                        Label("CARDS SOLD", systemImage: "rectangle.stack.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.orange)
                    } else {
                        Label("Available", systemImage: "circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.blue)
                    }

                    // Sell pack button
                    if !pack.isSold {
                        Button("Sell Pack") { showSellPackSheet = true }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .controlSize(.small)
                    } else {
                        Button("Undo") { store.unsellPack(pack.id, in: boxID) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.03))

                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)

                // Card list header
                HStack(spacing: 0) {
                    Text("#").frame(width: 30, alignment: .leading)
                    Text("Card").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Rarity").frame(width: 140, alignment: .leading)
                    Text("Condition").frame(width: 90, alignment: .leading)
                    Text("Price").frame(width: 70, alignment: .trailing)
                    Spacer().frame(width: 100)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.35))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .textCase(.uppercase)

                // Cards
                ForEach(sortedCards) { card in
                    CardRowView(card: card, packID: pack.id, boxID: boxID)
                }

                // Add card button
                Button(action: { showAddCardSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Card")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.blue.opacity(0.7))
                }
                .buttonStyle(.plain)
                .padding(.vertical, 16)
            }
        }
        .sheet(isPresented: $showSellPackSheet) {
            SellPackSheet(isPresented: $showSellPackSheet, pack: pack, boxID: boxID)
        }
        .sheet(item: $cardToSell) { card in
            SellCardSheet(isPresented: Binding(
                get: { cardToSell != nil },
                set: { if !$0 { cardToSell = nil } }
            ), card: card, packID: pack.id, boxID: boxID)
        }
        .sheet(isPresented: $showAddCardSheet) {
            AddCardSheet(isPresented: $showAddCardSheet, packID: pack.id, boxID: boxID)
        }
    }
}

// MARK: - Card Row

struct CardRowView: View {
    @EnvironmentObject var store: CardStore
    let card: Card
    let packID: UUID
    let boxID: UUID
    @State private var showSellSheet = false
    @State private var showImagePreview = false

    var body: some View {
        HStack(spacing: 0) {
            // Card image thumbnail
            if let imgData = card.imageData, let nsImage = NSImage(data: imgData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .onTapGesture { showImagePreview = true }
                    .help("View card image")
                    .sheet(isPresented: $showImagePreview) {
                        CardImagePreviewSheet(card: card, packID: packID, boxID: boxID)
                    }
            }

            // Position
            Text(card.isQRCode ? "QR" : "\(card.position)")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 30, alignment: .leading)

            // Name
            HStack(spacing: 6) {
                Text(card.isQRCode ? "🔲" : rarityEmoji(card.rarity, holo: card.isHolo, rev: card.isReverseHolo))
                    .font(.system(size: 12))
                Text(card.name)
                    .font(.system(size: 13))
                    .foregroundColor(card.isSold ? .white.opacity(0.3) : .white.opacity(0.85))
                    .strikethrough(card.isSold)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Rarity
            Text(card.rarityDisplay)
                .font(.system(size: 11))
                .foregroundColor(card.isSold ? .white.opacity(0.2) : .white.opacity(0.5))
                .frame(width: 140, alignment: .leading)

            // Condition
            Text(card.condition.rawValue)
                .font(.system(size: 11))
                .foregroundColor(conditionColor(card.condition).opacity(card.isSold ? 0.3 : 0.7))
                .frame(width: 90, alignment: .leading)

            // Price
            if card.isSold, let price = card.salePrice {
                Text("€\(String(format: "%.2f", price))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
                    .frame(width: 70, alignment: .trailing)
            } else {
                Text("—")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(width: 70, alignment: .trailing)
            }

            // Actions
            HStack(spacing: 6) {
                if !card.isSold {
                    Button("Sell") { showSellSheet = true }
                        .buttonStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                } else if let buyer = card.buyerName {
                    Text("to \(buyer)")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.01))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.03))
                .frame(height: 1),
            alignment: .bottom
        )
        .contextMenu {
            if !card.isSold {
                Button("Sell Card...") { showSellSheet = true }
            } else {
                Button("Undo Sale") {
                    store.unsellCard(card.id, in: packID, boxID: boxID)
                }
            }
            Button("Delete", role: .destructive) {
                store.removeCard(card.id, from: packID, in: boxID)
            }
        }
        .sheet(isPresented: $showSellSheet) {
            SellCardSheet(isPresented: $showSellSheet, card: card, packID: packID, boxID: boxID)
        }
    }

    func rarityEmoji(_ r: Card.Rarity, holo: Bool, rev: Bool) -> String {
        if holo { return "✨" }
        if rev { return "🔄" }
        switch r {
        case .common: return "●"
        case .uncommon: return "◆"
        case .rare: return "★"
        case .doubleRare: return "★★"
        case .ultraRare: return "💎"
        case .illustrationRare: return "🎨"
        case .specialIllustrationRare: return "🌟"
        case .hyperRare: return "🌈"
        case .promo: return "⭐"
        case .energy: return "⚡"
        case .trainer: return "🏷"
        }
    }

    func conditionColor(_ c: Card.Condition) -> Color {
        switch c {
        case .mint: return .green
        case .nearMint: return .blue
        case .excellent: return .yellow
        case .good: return .orange
        case .played: return .red
        }
    }
}

// MARK: - Card Image Preview

struct CardImagePreviewSheet: View {
    @EnvironmentObject var store: CardStore
    @Environment(\.dismiss) private var dismiss

    let card: Card
    let packID: UUID
    let boxID: UUID

    var body: some View {
        VStack(spacing: 12) {
            if let imgData = card.imageData, let nsImage = NSImage(data: imgData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 480, maxHeight: 600)
                    .cornerRadius(8)
            }
            Text(card.name)
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                Button("Remove Photo", role: .destructive) {
                    var updated = card
                    updated.imageData = nil
                    store.updateCard(updated, in: packID, boxID: boxID)
                    dismiss()
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 520, height: 720)
        .background(Color(red: 0.10, green: 0.10, blue: 0.14))
        .onExitCommand { dismiss() }
    }
}
