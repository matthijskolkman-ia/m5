import SwiftUI

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var store: CardStore
    @EnvironmentObject var connectivity: ConnectivityManager
    @State private var receivedCardToAdd: ConnectivityManager.ReceivedCard?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Sidebar: Boxes
                SidebarView()
                    .frame(width: 220)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)

                // Main area: Packs or Cards
                if let box = store.selectedBox {
                    VStack(spacing: 0) {
                        // Box header
                        BoxHeaderView(box: box)

                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)

                        if let pack = store.selectedPack {
                            PackCardListView(pack: pack, boxID: box.id)
                        } else {
                            PackGridView(box: box)
                        }
                    }
                } else {
                    EmptyStateView()
                }
            }

            // Connection bar at the bottom
            ConnectionBarView()
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.10))
        .onChange(of: connectivity.lastReceivedCard?.id) { _, _ in
            if let card = connectivity.lastReceivedCard {
                receivedCardToAdd = card
            }
        }
        .sheet(item: $receivedCardToAdd) { card in
            ReceivedCardSheet(card: card) { boxID, packID in
                addCardFromPhone(card, to: packID, in: boxID)
                receivedCardToAdd = nil
            }
        }
    }

    private func addCardFromPhone(_ received: ConnectivityManager.ReceivedCard, to packID: UUID, in boxID: UUID) {
        let rarity = Card.Rarity.allCases.first { $0.rawValue.contains(received.rarity) } ?? .common
        let condition = Card.Condition.allCases.first { $0.rawValue == received.condition } ?? .mint
        let count = store.selectedBox?.packs.first(where: { $0.id == packID })?.cards.count ?? 0

        var card = Card.standard(
            name: received.name,
            number: received.cardNumber,
            rarity: rarity,
            position: count + 1,
            holo: received.isHolo,
            reverseHolo: received.isReverseHolo
        )
        card.condition = condition
        card.imageData = received.imageData
        store.addCard(to: packID, in: boxID, card: card)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    @EnvironmentObject var store: CardStore

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.2))
            Text("No boxes yet")
                .font(.title2)
                .foregroundColor(.white.opacity(0.5))
            Text("Create a box to start tracking your Pokémon cards.")
                .foregroundColor(.white.opacity(0.3))
            Button("New Box") {
                store.addBox(Box.new(name: "Booster Box", set: "Scarlet & Violet", type: .boosterBox))
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Box Header

struct BoxHeaderView: View {
    @EnvironmentObject var store: CardStore
    let box: Box

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: iconFor(box.boxType))
                .font(.system(size: 28))
                .foregroundColor(colorFor(box.boxType))

            VStack(alignment: .leading, spacing: 2) {
                Text(box.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("\(box.set) — \(box.packCount) packs · \(box.totalCards) cards")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 12) {
                    Label("\(box.soldPacks) packs sold", systemImage: "tag")
                        .font(.system(size: 11))
                        .foregroundColor(.green.opacity(0.8))
                    Label("\(box.soldCards) cards sold", systemImage: "rectangle.stack")
                        .font(.system(size: 11))
                        .foregroundColor(.green.opacity(0.8))
                }
            }

            Button(action: { store.selectedPackID = nil }) {
                Image(systemName: "arrow.left")
            }
            .buttonStyle(.plain)
            .foregroundColor(.white.opacity(0.5))
            .opacity(store.selectedPackID != nil ? 1 : 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    func iconFor(_ type: Box.BoxType) -> String {
        switch type {
        case .boosterBox: return "shippingbox.fill"
        case .eliteTrainerBox: return "cube.box.fill"
        case .blisterPack: return "bag.fill"
        case .tin: return "cylinder.fill"
        case .collectionBox: return "giftcard.fill"
        case .other: return "tray.full.fill"
        }
    }

    func colorFor(_ type: Box.BoxType) -> Color {
        switch type {
        case .boosterBox: return .orange
        case .eliteTrainerBox: return .blue
        case .blisterPack: return .green
        case .tin: return .purple
        case .collectionBox: return .pink
        case .other: return .gray
        }
    }
}

// MARK: - Connection Bar

struct ConnectionBarView: View {
    @EnvironmentObject var connectivity: ConnectivityManager

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connectivity.isHosting ? Color.green : Color.gray.opacity(0.4))
                .frame(width: 7, height: 7)

            Text(connectivity.statusMessage)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.5))

            Spacer()

            Button(action: {
                if connectivity.isHosting {
                    connectivity.stopHosting()
                } else {
                    connectivity.startHosting()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: connectivity.isHosting ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 10))
                    Text(connectivity.isHosting ? "Stop" : "Host for iPhone")
                        .font(.system(size: 11))
                }
                .foregroundColor(connectivity.isHosting ? .green : .blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Received Card Sheet

struct ReceivedCardSheet: View {
    @EnvironmentObject var store: CardStore
    let card: ConnectivityManager.ReceivedCard
    let onAdd: (UUID, UUID) -> Void

    @State private var selectedBoxID: UUID?
    @State private var selectedPackID: UUID?

    var selectedBox: Box? {
        store.boxes.first(where: { $0.id == selectedBoxID })
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("📸 Card Received from iPhone")
                .font(.title3.bold())
                .foregroundColor(.white)

            // Card preview
            VStack(spacing: 6) {
                if let imgData = card.imageData, let nsImage = NSImage(data: imgData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                }

                Text(card.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                Text("\(card.cardNumber) · \(card.rarity)")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                if card.isHolo || card.isReverseHolo {
                    HStack(spacing: 8) {
                        if card.isHolo { Text("✨ Holo").font(.system(size: 11)).foregroundColor(.yellow) }
                        if card.isReverseHolo { Text("🔄 Rev.Holo").font(.system(size: 11)).foregroundColor(.yellow) }
                    }
                }
            }

            // Destination pickers
            VStack(spacing: 12) {
                Picker("Add to Box", selection: $selectedBoxID) {
                    Text("Select box...").tag(nil as UUID?)
                    ForEach(store.boxes) { box in
                        Text(box.name).tag(box.id as UUID?)
                    }
                }

                if let box = selectedBox {
                    Picker("Add to Pack", selection: $selectedPackID) {
                        Text("Select pack...").tag(nil as UUID?)
                        ForEach(box.packs.filter { !$0.isSold }) { pack in
                            Text("#\(pack.position) — \(pack.serialCode)").tag(pack.id as UUID?)
                        }
                    }
                }
            }
            .frame(width: 300)

            HStack(spacing: 12) {
                Button("Discard") {
                    onAdd(UUID(), UUID()) // won't match, sheet dismisses without adding
                }
                .foregroundColor(.red)

                Button("Add to Pack") {
                    if let boxID = selectedBoxID, let packID = selectedPackID {
                        onAdd(boxID, packID)
                    }
                }
                .keyboardShortcut(.return)
                .disabled(selectedBoxID == nil || selectedPackID == nil)
            }
        }
        .padding(30)
        .background(Color(red: 0.10, green: 0.10, blue: 0.14))
        .onAppear {
            selectedBoxID = store.selectedBoxID
            selectedPackID = store.selectedPackID
        }
    }
}
