import Foundation
import Combine

// MARK: - Card Store

class CardStore: ObservableObject {
    @Published var boxes: [Box] = []
    @Published var selectedBoxID: UUID?
    @Published var selectedPackID: UUID?

    private let saveURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = appSupport.appendingPathComponent("CardVault")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        saveURL = folder.appendingPathComponent("cardvault.json")
        load()
    }

    // MARK: Computed

    var selectedBox: Box? {
        boxes.first(where: { $0.id == selectedBoxID })
    }

    var selectedPack: Pack? {
        selectedBox?.packs.first(where: { $0.id == selectedPackID })
    }

    var totalInventoryValue: Double {
        var total: Double = 0
        for box in boxes {
            for pack in box.packs {
                if pack.isSold { total += pack.salePrice ?? 0 }
                for card in pack.cards where card.isSold {
                    total += card.salePrice ?? 0
                }
            }
        }
        return total
    }

    var totalSoldRevenue: Double {
        var total: Double = 0
        for box in boxes {
            for pack in box.packs where pack.isSold {
                total += pack.salePrice ?? 0
            }
            for pack in box.packs {
                for card in pack.cards where card.isSold {
                    total += card.salePrice ?? 0
                }
            }
        }
        return total
    }

    // MARK: Box operations

    func addBox(_ box: Box) {
        boxes.append(box)
        save()
    }

    func deleteBox(_ box: Box) {
        boxes.removeAll { $0.id == box.id }
        if selectedBoxID == box.id { selectedBoxID = nil }
        save()
    }

    // MARK: Pack operations

    func addPack(to boxID: UUID, pack: Pack) {
        guard let idx = boxes.firstIndex(where: { $0.id == boxID }) else { return }
        boxes[idx].packs.append(pack)
        save()
    }

    func deletePack(_ packID: UUID, from boxID: UUID) {
        guard let idx = boxes.firstIndex(where: { $0.id == boxID }) else { return }
        boxes[idx].packs.removeAll { $0.id == packID }
        if selectedPackID == packID { selectedPackID = nil }
        save()
    }

    // MARK: Card operations

    func addCard(to packID: UUID, in boxID: UUID, card: Card) {
        guard let boxIdx = boxes.firstIndex(where: { $0.id == boxID }),
              let packIdx = boxes[boxIdx].packs.firstIndex(where: { $0.id == packID }) else { return }
        boxes[boxIdx].packs[packIdx].cards.append(card)
        save()
    }

    func updateCard(_ card: Card, in packID: UUID, boxID: UUID) {
        guard let boxIdx = boxes.firstIndex(where: { $0.id == boxID }),
              let packIdx = boxes[boxIdx].packs.firstIndex(where: { $0.id == packID }),
              let cardIdx = boxes[boxIdx].packs[packIdx].cards.firstIndex(where: { $0.id == card.id }) else { return }
        boxes[boxIdx].packs[packIdx].cards[cardIdx] = card
        save()
    }

    func removeCard(_ cardID: UUID, from packID: UUID, in boxID: UUID) {
        guard let boxIdx = boxes.firstIndex(where: { $0.id == boxID }),
              let packIdx = boxes[boxIdx].packs.firstIndex(where: { $0.id == packID }) else { return }
        boxes[boxIdx].packs[packIdx].cards.removeAll { $0.id == cardID }
        save()
    }

    // MARK: Sell operations

    func sellPack(_ packID: UUID, in boxID: UUID, price: Double, buyer: String) {
        guard let boxIdx = boxes.firstIndex(where: { $0.id == boxID }),
              let packIdx = boxes[boxIdx].packs.firstIndex(where: { $0.id == packID }) else { return }
        boxes[boxIdx].packs[packIdx].isSold = true
        boxes[boxIdx].packs[packIdx].salePrice = price
        boxes[boxIdx].packs[packIdx].soldDate = Date()
        boxes[boxIdx].packs[packIdx].buyerName = buyer
        save()
    }

    func sellCard(_ cardID: UUID, in packID: UUID, boxID: UUID, price: Double, buyer: String) {
        guard let boxIdx = boxes.firstIndex(where: { $0.id == boxID }),
              let packIdx = boxes[boxIdx].packs.firstIndex(where: { $0.id == packID }),
              let cardIdx = boxes[boxIdx].packs[packIdx].cards.firstIndex(where: { $0.id == cardID }) else { return }
        boxes[boxIdx].packs[packIdx].cards[cardIdx].isSold = true
        boxes[boxIdx].packs[packIdx].cards[cardIdx].salePrice = price
        boxes[boxIdx].packs[packIdx].cards[cardIdx].soldDate = Date()
        boxes[boxIdx].packs[packIdx].cards[cardIdx].buyerName = buyer
        save()
    }

    func unsellPack(_ packID: UUID, in boxID: UUID) {
        guard let boxIdx = boxes.firstIndex(where: { $0.id == boxID }),
              let packIdx = boxes[boxIdx].packs.firstIndex(where: { $0.id == packID }) else { return }
        boxes[boxIdx].packs[packIdx].isSold = false
        boxes[boxIdx].packs[packIdx].salePrice = nil
        boxes[boxIdx].packs[packIdx].soldDate = nil
        boxes[boxIdx].packs[packIdx].buyerName = nil
        save()
    }

    func unsellCard(_ cardID: UUID, in packID: UUID, boxID: UUID) {
        guard let boxIdx = boxes.firstIndex(where: { $0.id == boxID }),
              let packIdx = boxes[boxIdx].packs.firstIndex(where: { $0.id == packID }),
              let cardIdx = boxes[boxIdx].packs[packIdx].cards.firstIndex(where: { $0.id == cardID }) else { return }
        boxes[boxIdx].packs[packIdx].cards[cardIdx].isSold = false
        boxes[boxIdx].packs[packIdx].cards[cardIdx].salePrice = nil
        boxes[boxIdx].packs[packIdx].cards[cardIdx].soldDate = nil
        boxes[boxIdx].packs[packIdx].cards[cardIdx].buyerName = nil
        save()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([Box].self, from: data) else { return }
        boxes = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(boxes) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    // MARK: Serial code generator

    static func generateSerial(boxName: String, packPosition: Int) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyMMdd"
        let date = dateFormatter.string(from: Date())
        let sanitized = boxName.prefix(3).uppercased().filter { $0.isLetter }
        return "\(sanitized)-\(date)-\(String(format: "%03d", packPosition))"
    }
}
