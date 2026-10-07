import SwiftUI

// MARK: - Sell Pack Sheet

struct SellPackSheet: View {
    @EnvironmentObject var store: CardStore
    @Binding var isPresented: Bool
    let pack: Pack
    let boxID: UUID

    @State private var price: String = ""
    @State private var buyer: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Sell Pack #\(pack.position)")
                .font(.title3.bold())
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text("Serial: \(pack.serialCode)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(pack.totalCards) cards in pack")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }

            VStack(spacing: 12) {
                HStack {
                    Text("€")
                        .foregroundColor(.white.opacity(0.5))
                    TextField("Price", text: $price)
                        .textFieldStyle(.roundedBorder)
                }
                TextField("Buyer name", text: $buyer)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(width: 280)

            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                Button("Confirm Sale") {
                    if let p = Double(price.replacingOccurrences(of: ",", with: ".")) {
                        store.sellPack(pack.id, in: boxID, price: p, buyer: buyer.isEmpty ? "Walk-in" : buyer)
                        isPresented = false
                    }
                }
                .keyboardShortcut(.return)
                .disabled(price.isEmpty)
            }
        }
        .padding(30)
        .background(Color(red: 0.10, green: 0.10, blue: 0.14))
    }
}

// MARK: - Sell Card Sheet

struct SellCardSheet: View {
    @EnvironmentObject var store: CardStore
    @Binding var isPresented: Bool
    let card: Card
    let packID: UUID
    let boxID: UUID

    @State private var price: String = ""
    @State private var buyer: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Sell Card")
                .font(.title3.bold())
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 6) {
                Text(card.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(card.rarityDisplay)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Text("Condition: \(card.condition.rawValue)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            VStack(spacing: 12) {
                HStack {
                    Text("€")
                        .foregroundColor(.white.opacity(0.5))
                    TextField("Price", text: $price)
                        .textFieldStyle(.roundedBorder)
                }
                TextField("Buyer name", text: $buyer)
                    .textFieldStyle(.roundedBorder)
            }
            .frame(width: 280)

            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                Button("Confirm Sale") {
                    if let p = Double(price.replacingOccurrences(of: ",", with: ".")) {
                        store.sellCard(card.id, in: packID, boxID: boxID, price: p, buyer: buyer.isEmpty ? "Walk-in" : buyer)
                        isPresented = false
                    }
                }
                .keyboardShortcut(.return)
                .disabled(price.isEmpty)
            }
        }
        .padding(30)
        .background(Color(red: 0.10, green: 0.10, blue: 0.14))
    }
}

// MARK: - Add Card Sheet

struct AddCardSheet: View {
    @EnvironmentObject var store: CardStore
    @Binding var isPresented: Bool
    let packID: UUID
    let boxID: UUID

    @State private var name = ""
    @State private var cardNumber = ""
    @State private var rarity: Card.Rarity = .common
    @State private var isHolo = false
    @State private var isReverseHolo = false
    @State private var condition: Card.Condition = .mint

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Card")
                .font(.title3.bold())
                .foregroundColor(.white)

            VStack(spacing: 12) {
                TextField("Card name", text: $name)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    TextField("Card number (e.g. 165/165)", text: $cardNumber)
                        .textFieldStyle(.roundedBorder)
                }

                Picker("Rarity", selection: $rarity) {
                    ForEach(Card.Rarity.allCases, id: \.self) { r in
                        Text(r.rawValue).tag(r)
                    }
                }

                Picker("Condition", selection: $condition) {
                    ForEach(Card.Condition.allCases, id: \.self) { c in
                        Text(c.rawValue).tag(c)
                    }
                }

                Toggle("Holo", isOn: $isHolo)
                Toggle("Reverse Holo", isOn: $isReverseHolo)
            }
            .frame(width: 300)

            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                Button("Add") {
                    let count = store.selectedPack?.cards.count ?? 0
                    let card = Card.standard(
                        name: name,
                        number: cardNumber,
                        rarity: rarity,
                        position: count + 1,
                        holo: isHolo,
                        reverseHolo: isReverseHolo
                    )
                    var c = card
                    c.condition = condition
                    store.addCard(to: packID, in: boxID, card: c)
                    isPresented = false
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty)
            }
        }
        .padding(30)
        .background(Color(red: 0.10, green: 0.10, blue: 0.14))
    }
}
