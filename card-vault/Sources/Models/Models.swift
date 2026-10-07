import Foundation

// MARK: - Box

struct Box: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var set: String          // e.g. "Scarlet & Violet – 151"
    var setName: String      // e.g. "SV 151"
    var boxType: BoxType
    var packs: [Pack]
    var createdAt: Date
    var notes: String

    enum BoxType: String, CaseIterable, Codable {
        case boosterBox = "Booster Box"
        case eliteTrainerBox = "Elite Trainer Box"
        case blisterPack = "Blister Pack"
        case tin = "Tin"
        case collectionBox = "Collection Box"
        case other = "Other"
    }

    var packCount: Int { packs.count }
    var soldPacks: Int { packs.filter(\.isSold).count }
    var totalCards: Int { packs.reduce(0) { $0 + $1.cards.count } }
    var soldCards: Int { packs.reduce(0) { $0 + $1.cards.filter(\.isSold).count } }

    static func new(name: String, set: String, type: BoxType) -> Box {
        Box(name: name, set: set, setName: set, boxType: type, packs: [], createdAt: Date(), notes: "")
    }
}

// MARK: - Pack

struct Pack: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var serialCode: String
    var position: Int           // Position in the box (1-based)
    var cards: [Card]           // Ordered as they appear in the pack
    var isSold: Bool
    var salePrice: Double?
    var soldDate: Date?
    var buyerName: String?
    var openedDate: Date

    var soldCards: Int { cards.filter(\.isSold).count }
    var totalCards: Int { cards.count }
    var isFullySold: Bool { isSold || cards.allSatisfy(\.isSold) }

    static func new(serial: String, position: Int) -> Pack {
        Pack(
            serialCode: serial,
            position: position,
            cards: [Card.qrCode(position: 1)],
            isSold: false,
            openedDate: Date()
        )
    }
}

// MARK: - Card

struct Card: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var cardNumber: String     // e.g. "165/165"
    var rarity: Rarity
    var isQRCode: Bool
    var isHolo: Bool
    var isReverseHolo: Bool
    var condition: Condition
    var position: Int          // Position in the pack (1-based)
    var isSold: Bool
    var salePrice: Double?
    var soldDate: Date?
    var buyerName: String?
    var notes: String
    var imageData: Data? = nil

    enum Rarity: String, CaseIterable, Codable {
        case common = "● Common"
        case uncommon = "◆ Uncommon"
        case rare = "★ Rare"
        case doubleRare = "★★ Double Rare"
        case ultraRare = "★★★ Ultra Rare"
        case illustrationRare = "☆ Illustration Rare"
        case specialIllustrationRare = "☆☆ Special Illustration Rare"
        case hyperRare = "◇ Hyper Rare"
        case promo = "P Promo"
        case energy = "⚡ Energy"
        case trainer = "🏷 Trainer"
    }

    enum Condition: String, CaseIterable, Codable {
        case mint = "Mint"
        case nearMint = "Near Mint"
        case excellent = "Excellent"
        case good = "Good"
        case played = "Played"
    }

    var rarityDisplay: String {
        if isQRCode { return "QR Code" }
        var r = rarity.rawValue
        if isHolo { r += " Holo" }
        if isReverseHolo { r += " Rev.Holo" }
        return r
    }

    static func qrCode(position: Int) -> Card {
        Card(name: "QR Code Card", cardNumber: "QR", rarity: .common, isQRCode: true,
             isHolo: false, isReverseHolo: false, condition: .mint, position: position,
             isSold: false, notes: "")
    }

    static func standard(name: String, number: String, rarity: Rarity, position: Int,
                         holo: Bool = false, reverseHolo: Bool = false) -> Card {
        Card(name: name, cardNumber: number, rarity: rarity, isQRCode: false,
             isHolo: holo, isReverseHolo: reverseHolo, condition: .mint,
             position: position, isSold: false, notes: "")
    }
}
