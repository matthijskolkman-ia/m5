import SwiftUI

// MARK: - Pack Grid View

struct PackGridView: View {
    @EnvironmentObject var store: CardStore
    let box: Box

    let columns = [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 12)]

    var body: some View {
        ScrollView {
            if box.packs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "envelope.open")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No packs yet")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.4))
                    Text("Press ⌘N to add a pack")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.3))
                    Button("Add First Pack") {
                        let count = box.packs.count
                        let serial = CardStore.generateSerial(boxName: box.name, packPosition: count + 1)
                        store.addPack(to: box.id, pack: Pack.new(serial: serial, position: count + 1))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 60)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(box.packs.sorted(by: { $0.position < $1.position })) { pack in
                        PackCard(pack: pack, boxID: box.id)
                            .onTapGesture {
                                store.selectedPackID = pack.id
                            }
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Pack Card

struct PackCard: View {
    @EnvironmentObject var store: CardStore
    let pack: Pack
    let boxID: UUID

    var qrCard: Card? { pack.cards.first(where: \.isQRCode) }
    var regularCards: [Card] { pack.cards.filter { !$0.isQRCode } }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: pack.isSold ? "envelope.fill" : "envelope.open.fill")
                    .foregroundColor(pack.isSold ? .green : .blue)
                Text("#\(pack.position)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if pack.isSold {
                    Text("€\(String(format: "%.0f", pack.salePrice ?? 0))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))

            Divider().background(Color.white.opacity(0.06))

            // Card summary
            VStack(spacing: 6) {
                ForEach(pack.cards.sorted(by: { $0.position < $1.position })) { card in
                    HStack(spacing: 6) {
                        Text(card.isQRCode ? "🔲" : rarityIcon(card.rarity))
                            .font(.system(size: 10))
                        Text(card.name)
                            .font(.system(size: 11))
                            .foregroundColor(card.isSold ? .white.opacity(0.25) : .white.opacity(0.7))
                            .lineLimit(1)
                            .strikethrough(card.isSold)
                        Spacer()
                        if card.isSold, let price = card.salePrice {
                            Text("€\(String(format: "%.0f", price))")
                                .font(.system(size: 9))
                                .foregroundColor(.green.opacity(0.6))
                        }
                    }
                }
            }
            .padding(10)

            Divider().background(Color.white.opacity(0.06))

            // Footer
            HStack {
                Text(pack.serialCode)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1)
                Spacer()
                Text("\(pack.totalCards) cards")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(pack.isFullySold ? Color.green.opacity(0.06) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    store.selectedPackID == pack.id ? Color.blue.opacity(0.5) :
                    pack.isSold ? Color.green.opacity(0.3) : Color.white.opacity(0.06),
                    lineWidth: store.selectedPackID == pack.id ? 2 : 1
                )
        )
        .contextMenu {
            if !pack.isSold {
                Button("Sell Pack...") {
                    // Will trigger sell sheet
                }
            } else {
                Button("Undo Sale") {
                    store.unsellPack(pack.id, in: boxID)
                }
            }
            Divider()
            Button("Delete Pack", role: .destructive) {
                store.deletePack(pack.id, from: boxID)
            }
        }
    }

    func rarityIcon(_ rarity: Card.Rarity) -> String {
        switch rarity {
        case .common: return "●"
        case .uncommon: return "◆"
        case .rare: return "★"
        case .doubleRare: return "★★"
        case .ultraRare: return "💎"
        case .illustrationRare: return "🎨"
        case .specialIllustrationRare: return "✨"
        case .hyperRare: return "🌈"
        case .promo: return "⭐"
        case .energy: return "⚡"
        case .trainer: return "🏷"
        }
    }
}
