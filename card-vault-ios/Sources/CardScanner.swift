import SwiftUI
@preconcurrency import Vision

// MARK: - Card Scanner (Vision OCR + Pokémon TCG API)

@MainActor
class CardScanner: ObservableObject {
    @Published var isScanning = false
    @Published var scannedResult: ScannedCard?
    @Published var errorMessage: String?
    @Published var debugOCRText: String?
    @Published var verification: CardVerification?

    struct ScannedCard: Identifiable {
        let id = UUID()
        let name: String
        let cardNumber: String
        let set: String
        let rarity: String
        let isHolo: Bool
        let marketPrice: Double?
        let imageURL: String?
    }

    func scanCard(from image: UIImage) {
        isScanning = true
        errorMessage = nil
        scannedResult = nil
        verification = nil

        guard let cgImage = image.cgImage else {
            errorMessage = "Could not process image"
            isScanning = false
            return
        }

        // Step 1: Vision OCR
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self,
                  let observations = request.results as? [VNRecognizedTextObservation],
                  !observations.isEmpty else {
                Task { @MainActor in
                    self?.errorMessage = "No text found — try a clearer photo"
                    self?.verification = CardVerification(verdict: .notACard, confidence: 0.1, details: "No text detected")
                    self?.isScanning = false
                }
                return
            }

            // Extract all recognized text with positions (Vision coords: origin bottom-left)
            var textBlocks: [(text: String, y: CGFloat, x: CGFloat)] = []
            for obs in observations {
                guard let top = obs.topCandidates(1).first else { continue }
                let midY = obs.boundingBox.origin.y + obs.boundingBox.height / 2
                let midX = obs.boundingBox.origin.x + obs.boundingBox.width / 2
                textBlocks.append((top.string, midY, midX))
            }

            // Sort top to bottom (Vision y=0 is bottom, y=1 is top)
            textBlocks.sort { $0.y > $1.y }

            let allTexts = textBlocks.map { "\($0.text) [y:\(String(format: "%.2f", $0.y))]" }
            print("🔤 ALL OCR (\(textBlocks.count) blocks): \(allTexts.joined(separator: " | "))")

            // Take top 30% of text blocks — that's where the card name lives
            let topCutoff = textBlocks.first?.y ?? 0
            let bottomCutoff = topCutoff - 0.30
            let topBlocks = textBlocks.filter { $0.y >= bottomCutoff }

            print("📋 Top region (\(topBlocks.count) blocks): \(topBlocks.map(\.text).joined(separator: " | "))")

            let cardName = self.extractCardName(from: topBlocks.map(\.text), all: textBlocks.map(\.text))
            let cardNumber = self.extractCardNumber(from: textBlocks.map(\.text))
            let setName = self.extractSetName(from: textBlocks.map(\.text))

            print("🎯 RESULT: name=\(cardName ?? "?"), number=\(cardNumber ?? "?"), set=\(setName ?? "?")")

            // Store debug info
            Task { @MainActor in
                self.debugOCRText = allTexts.joined(separator: "\n")
            }

            // Verify the photo looks like a card / Pokémon card
            let verification = Self.computeVerification(cgImage: cgImage, ocrText: allTexts)
            Task { @MainActor in
                self.verification = verification
            }

            // Step 2: Try API enrichment, but ALWAYS use OCR name as baseline
            let ocrName = cardName ?? "Unknown Card"
            let ocrNumber = cardNumber ?? ""

            // Populate OCR result immediately as fallback, then try API
            let fallback = ScannedCard(
                name: ocrName,
                cardNumber: ocrNumber,
                set: setName ?? "",
                rarity: "● Common",
                isHolo: false,
                marketPrice: nil,
                imageURL: nil
            )

            Task { @MainActor in
                self.scannedResult = fallback
                self.isScanning = false
                self.errorMessage = nil
            }

            // Try API enrichment in background (won't block the user)
            if let name = cardName {
                self.enrichFromAPI(name: name, number: cardNumber)
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    // MARK: OCR Heuristics

    private func extractCardName(from topLines: [String], all: [String]) -> String? {
        // Card names are always the FIRST prominent text from the top.
        // Pokémon card layout (top → bottom):
        //   1. Card name ← WE WANT THIS
        //   2. HP / Type / Stage label
        //   3. Artwork (no text)
        //   4. Attack names + descriptions (LONG text blocks)
        //   5. Flavor text / bottom info
        //
        // Strategy: scan top-to-bottom, return the FIRST line that isn't
        // a type label, isn't too long (attack text), and isn't a number.

        let typeLabels: Set<String> = [
            "trainer", "supporter", "item", "tool", "stadium",
            "basic", "stage 1", "stage 2", "restored"
        ]

        let commonWords: Set<String> = [
            "hp", "no.", "pokemon", "pokémon", "evolves", "evolve",
            "weakness", "resistance", "retreat", "switch"
        ]

        for line in topLines {
            let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = cleaned.lowercased()

            // Skip too short or too long (attack descriptions are long)
            guard cleaned.count >= 3 && cleaned.count <= 25 else { continue }

            // Skip type labels
            if typeLabels.contains(lower) { continue }
            if commonWords.contains(lower) { continue }

            // Skip numeric patterns: HP, set numbers, card numbers
            if cleaned.range(of: #"^\d+"#, options: .regularExpression) != nil { continue }
            if cleaned.range(of: #"\d+\s*HP"#, options: .regularExpression) != nil { continue }
            if cleaned.range(of: #"^\d+/\d+"#, options: .regularExpression) != nil { continue }
            if cleaned.range(of: #"^NO\.\s*\d+"#, options: .regularExpression) != nil { continue }
            if cleaned.range(of: #"^[A-Z]{2,4}\d*$"#, options: .regularExpression) != nil { continue }

            // Skip copyright / legal text
            if cleaned.contains("©") || cleaned.contains("Nintendo") || cleaned.contains("GAME FREAK") || cleaned.contains("Creatures") { continue }

            // Skip known game terms that appear as standalone text
            if lower == "put" || lower == "your" || lower == "all" || lower == "you" || lower == "may" { continue }

            // This is the first eligible line from the top — it's the card name!
            print("🎯 Name pick (first eligible from top): \"\(cleaned)\"")
            return cleaned
        }

        return nil
    }

    private func extractCardNumber(from lines: [String]) -> String? {
        for line in lines {
            let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // Match "165/165" or "#165" patterns
            if let range = cleaned.range(of: #"\d{1,3}/\d{1,3}"#, options: .regularExpression) {
                return String(cleaned[range])
            }
            if let range = cleaned.range(of: #"#\d{1,3}"#, options: .regularExpression) {
                return String(cleaned[range].dropFirst())
            }
        }
        return nil
    }

    private func extractSetName(from lines: [String]) -> String? {
        let setKeywords = ["Scarlet", "Violet", "Sword", "Shield", "Paldea", "Galar", "Crown", "Zenith",
                           "Obsidian", "Flames", "Paradox", "Rift", "Temporal", "Forces", "Twilight",
                           "Masquerade", "Shrouded", "Fable", "Stellar", "Surging", "Sparks",
                           "Prismatic", "Evolutions", "Destined", "Rivals", "Journey", "Together",
                           "151", "Paldean", "Fates", "Base", "Fusion", "Strike", "Brilliant",
                           "Stars", "Astral", "Radiance", "Lost", "Origin", "Silver", "Tempest"]
        for line in lines {
            for keyword in setKeywords {
                if line.lowercased().contains(keyword.lowercased()) {
                    return keyword
                }
            }
        }
        return nil
    }

    // MARK: APIs — enrich OCR result with card data + pricing

    private let pcApiKey = "24569ccfc068c147f5c319286270606b359afb33"

    private func enrichFromAPI(name: String, number: String?) {
        // Run both APIs in parallel
        fetchFromPokemonTCG(name: name, number: number)
        fetchFromPriceCharting(name: name, number: number)
    }

    // MARK: Pokémon TCG API (free — for rarity, set, subtypes)

    private func fetchFromPokemonTCG(name: String, number: String?) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        var query = "name:\"\(encoded)\""
        if let num = number {
            let cleanNum = num.split(separator: "/").first.map(String.init) ?? num
            query += " number:\(cleanNum)"
        }

        let urlString = "https://api.pokemontcg.io/v2/cards?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)&pageSize=3"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cards = json["data"] as? [[String: Any]],
                  !cards.isEmpty,
                  let first = cards.first else {
                print("⚠️ Pokémon TCG: no match")
                return
            }

            Task { @MainActor in
                var updated = self.scannedResult ?? ScannedCard(name: name, cardNumber: number ?? "", set: "", rarity: "● Common", isHolo: false, marketPrice: nil, imageURL: nil)

                if let r = first["rarity"] as? String {
                    updated = ScannedCard(name: updated.name, cardNumber: updated.cardNumber, set: updated.set, rarity: CardScanner.mapRarityStatic(r), isHolo: updated.isHolo, marketPrice: updated.marketPrice, imageURL: updated.imageURL)
                }
                if let subtypes = first["subtypes"] as? [String] {
                    let holo = subtypes.contains { $0.lowercased().contains("holo") }
                    updated = ScannedCard(name: updated.name, cardNumber: updated.cardNumber, set: updated.set, rarity: updated.rarity, isHolo: holo, marketPrice: updated.marketPrice, imageURL: updated.imageURL)
                }
                if let set = first["set"] as? [String: Any], let setName = set["name"] as? String {
                    updated = ScannedCard(name: updated.name, cardNumber: updated.cardNumber, set: setName, rarity: updated.rarity, isHolo: updated.isHolo, marketPrice: updated.marketPrice, imageURL: updated.imageURL)
                }
                self.scannedResult = updated
                print("✅ Pokémon TCG enriched: \(updated.name) | \(updated.rarity)")
            }
        }.resume()
    }

    // MARK: PriceCharting API (paid — for accurate market prices)

    private func fetchFromPriceCharting(name: String, number: String?) {
        let searchTerm: String
        if let num = number {
            let cleanNum = num.split(separator: "/").first.map(String.init) ?? num
            searchTerm = "\(name) \(cleanNum)"
        } else {
            searchTerm = name
        }

        let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
        let urlString = "https://www.pricecharting.com/api/product?t=\(pcApiKey)&q=\(encoded)"
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self,
                  let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["status"] as? String == "success" else {
                print("⚠️ PriceCharting: no match for \(searchTerm)")
                return
            }

            let priceCents = json["loose-price"] as? Int
            let priceDollars = priceCents.map { Double($0) / 100.0 }
            let productName = json["product-name"] as? String
            let consoleName = json["console-name"] as? String

            Task { @MainActor in
                var updated = self.scannedResult ?? ScannedCard(name: name, cardNumber: number ?? "", set: "", rarity: "● Common", isHolo: false, marketPrice: nil, imageURL: nil)

                if let pn = productName {
                    updated = ScannedCard(name: pn, cardNumber: updated.cardNumber, set: consoleName ?? updated.set, rarity: updated.rarity, isHolo: updated.isHolo, marketPrice: priceDollars, imageURL: updated.imageURL)
                } else if let pd = priceDollars {
                    updated = ScannedCard(name: updated.name, cardNumber: updated.cardNumber, set: updated.set, rarity: updated.rarity, isHolo: updated.isHolo, marketPrice: pd, imageURL: updated.imageURL)
                }
                self.scannedResult = updated
                print("💰 PriceCharting: \(updated.name) = $\(String(format: "%.2f", priceDollars ?? 0))")
            }
        }.resume()
    }

    private func mapRarity(_ apiRarity: String) -> String {
        Self.mapRarityStatic(apiRarity)
    }

    // MARK: Card / Pokémon verification

    nonisolated private static func computeVerification(cgImage: CGImage?, ocrText: [String]) -> CardVerification {
        // 1) Card-shaped rectangle detection
        var cardShaped = false
        if let cg = cgImage {
            let rectRequest = VNDetectRectanglesRequest()
            rectRequest.minimumAspectRatio = 0.5
            rectRequest.maximumAspectRatio = 0.9
            rectRequest.minimumSize = 0.25
            rectRequest.minimumConfidence = 0.4
            rectRequest.maximumObservations = 8
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try? handler.perform([rectRequest])
            if let results = rectRequest.results {
                cardShaped = results.contains { obs in
                    obs.confidence >= 0.5 &&
                    obs.boundingBox.width >= 0.25 &&
                    obs.boundingBox.height >= 0.25
                }
            }
        }

        // 2) Pokémon text markers
        let joined = ocrText.joined(separator: " ")
        let lower = joined.lowercased()

        let hasHP = lower.range(of: #"\bhp\b"#, options: .regularExpression) != nil
        let hasCardNumber = joined.range(of: #"\d{1,3}\s*/\s*\d{1,3}"#, options: .regularExpression) != nil
        let hasCopyright = joined.contains("©") ||
            ["pokémon", "pokemon", "nintendo", "game freak", "creatures", "gamefreak"].contains { lower.contains($0) }
        let hasPokemonTerms = ["weakness", "resistance", "retreat", "trainer", "stage 1", "stage 2",
                               "basic", "energy", "evolves", "attached", "discard"].contains { lower.contains($0) }

        var score = 0
        var reasons: [String] = []
        if cardShaped { score += 1; reasons.append("card-shaped rectangle") }
        if hasHP { score += 2; reasons.append("HP stat") }
        if hasCardNumber { score += 1; reasons.append("card number (x/y)") }
        if hasCopyright { score += 2; reasons.append("Pokémon copyright") }
        if hasPokemonTerms { score += 1; reasons.append("Pokémon keywords") }

        let verdict: CardVerification.Verdict
        if score >= 3 {
            verdict = .pokemonCard
        } else if score == 2 {
            verdict = .maybeCard
        } else {
            verdict = .notACard
        }

        let confidence = min(1.0, 0.35 + Double(score) * 0.12)
        let details = reasons.isEmpty ? "No card features detected" : reasons.joined(separator: ", ")

        return CardVerification(verdict: verdict, confidence: confidence, details: details)
    }

    nonisolated private static func mapRarityStatic(_ apiRarity: String) -> String {
        switch apiRarity.lowercased() {
        case "common": return "● Common"
        case "uncommon": return "◆ Uncommon"
        case "rare": return "★ Rare"
        case "rare holo": return "★ Rare"
        case "double rare": return "★★ Double Rare"
        case "ultra rare": return "💎 Ultra Rare"
        case "illustration rare": return "🎨 Illustration Rare"
        case "special illustration rare": return "🌟 Special Illustration Rare"
        case "hyper rare": return "🌈 Hyper Rare"
        case "promo": return "⭐ Promo"
        default: return "● Common"
        }
    }
}

// MARK: - Card Verification Result

struct CardVerification: Equatable {
    enum Verdict: String {
        case pokemonCard = "Looks like a Pokémon card"
        case maybeCard = "Looks like a card, but not sure it's Pokémon"
        case notACard = "Doesn't look like a Pokémon card"
    }

    let verdict: Verdict
    let confidence: Double
    let details: String
}
