import SwiftUI

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject var store: CardStore
    @State private var showNewBoxSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Boxes", systemImage: "shippingbox")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Button(action: { showNewBoxSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Box list
            if store.boxes.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 32))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No boxes")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(maxHeight: .infinity)
            } else {
                List(selection: Binding<UUID?>(
                    get: { store.selectedBoxID },
                    set: { store.selectedBoxID = $0; store.selectedPackID = nil }
                )) {
                    ForEach(store.boxes) { box in
                        BoxRow(box: box).tag(box.id)
                    }
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }

            // Revenue footer
            VStack(spacing: 4) {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                HStack {
                    Text("Total revenue")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                    Spacer()
                    Text(String(format: "€%.2f", store.totalSoldRevenue))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(Color(red: 0.05, green: 0.05, blue: 0.08))
        .sheet(isPresented: $showNewBoxSheet) {
            NewBoxSheet(isPresented: $showNewBoxSheet)
        }
    }
}

// MARK: - Box Row

struct BoxRow: View {
    @EnvironmentObject var store: CardStore
    let box: Box

    var availablePacks: Int { box.packs.filter { !$0.isSold }.count }
    var availableCards: Int {
        var count = 0
        for pack in box.packs {
            count += pack.cards.filter { !$0.isSold && !$0.isQRCode }.count
        }
        return count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: boxIcon(box.boxType))
                    .font(.system(size: 12))
                    .foregroundColor(boxColor(box.boxType))
                Text(box.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer()
                Text("\(box.packCount)")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }

            HStack(spacing: 8) {
                Text(box.set)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
                if availablePacks > 0 {
                    Text("\(availablePacks) packs")
                        .font(.system(size: 10))
                        .foregroundColor(.blue.opacity(0.7))
                }
                if availableCards > 0 {
                    Text("\(availableCards) cards")
                        .font(.system(size: 10))
                        .foregroundColor(.green.opacity(0.7))
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Delete Box") { store.deleteBox(box) }
        }
    }

    func boxIcon(_ type: Box.BoxType) -> String {
        switch type {
        case .boosterBox: return "shippingbox.fill"
        case .eliteTrainerBox: return "cube.box.fill"
        case .blisterPack: return "bag.fill"
        case .tin: return "cylinder.fill"
        case .collectionBox: return "giftcard.fill"
        case .other: return "tray.full.fill"
        }
    }

    func boxColor(_ type: Box.BoxType) -> Color {
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

// MARK: - New Box Sheet

struct NewBoxSheet: View {
    @EnvironmentObject var store: CardStore
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var set = ""
    @State private var type: Box.BoxType = .boosterBox

    var body: some View {
        VStack(spacing: 20) {
            Text("New Box")
                .font(.title2.bold())
                .foregroundColor(.white)

            VStack(spacing: 12) {
                TextField("Box name", text: $name)
                    .textFieldStyle(.roundedBorder)
                TextField("Set (e.g. Scarlet & Violet – 151)", text: $set)
                    .textFieldStyle(.roundedBorder)
                Picker("Type", selection: $type) {
                    ForEach(Box.BoxType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .labelsHidden()
            }
            .frame(width: 300)

            HStack(spacing: 12) {
                Button("Cancel") { isPresented = false }
                Button("Create") {
                    let box = Box.new(name: name.isEmpty ? type.rawValue : name,
                                      set: set.isEmpty ? "Unknown Set" : set,
                                      type: type)
                    store.addBox(box)
                    store.selectedBoxID = box.id
                    isPresented = false
                }
                .keyboardShortcut(.return)
                .disabled(set.isEmpty)
            }
        }
        .padding(30)
        .background(Color(red: 0.10, green: 0.10, blue: 0.14))
    }
}
