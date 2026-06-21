import SwiftUI
import UniformTypeIdentifiers

// MARK: - Models

struct Coin: Identifiable {
    let id: String
    let symbol: String
    let name: String
    var price: Double = 0
    var change24h: Double = 0
    var marketCap: Double = 0
    var volume24h: Double = 0
    var high24h: Double = 0
    var low24h: Double = 0
}

// MARK: - API Service

class CoinService: ObservableObject {
    @Published var coins: [Coin] = []
    @Published var lastUpdated: Date?
    @Published var isLoading = false
    @Published var error: String?
    @Published var currency: String = "usd"

    private let defaultIds = ["bitcoin","ethereum","solana","ripple","cardano","dogecoin","polkadot","chainlink","avalanche-2","uniswap"]
    private let names = ["Bitcoin","Ethereum","Solana","XRP","Cardano","Dogecoin","Polkadot","Chainlink","Avalanche","Uniswap"]
    private let symbols = ["BTC","ETH","SOL","XRP","ADA","DOGE","DOT","LINK","AVAX","UNI"]

    private var timer: Timer?

    init() { fetch(); timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in self.fetch() } }

    func fetch() {
        isLoading = true
        let ids = defaultIds.joined(separator: ",")
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=\(currency)&include_24hr_change=true&include_24hr_vol=true&include_market_cap=true") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, err in
            guard let self, let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Double]] else {
                DispatchQueue.main.async { self?.isLoading = false }
                return
            }
            var updated: [Coin] = []
            for (i, id) in self.defaultIds.enumerated() {
                var c = Coin(id: id, symbol: self.symbols[i], name: self.names[i])
                if let vals = json[id] {
                    c.price = vals["\(self.currency)"] ?? 0
                    c.change24h = vals["\(self.currency)_24h_change"] ?? 0
                    c.marketCap = vals["\(self.currency)_market_cap"] ?? 0
                    c.volume24h = vals["\(self.currency)_24h_vol"] ?? 0
                }
                updated.append(c)
            }
            DispatchQueue.main.async {
                self.coins = updated
                self.lastUpdated = Date()
                self.isLoading = false
                self.error = nil
            }
        }.resume()
    }
}

// MARK: - Export Helpers

enum ExportFormat: String, CaseIterable {
    case csv, json, excel
    var label: String { rawValue.uppercased() }
}

func exportData(coins: [Coin], format: ExportFormat) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = {
        switch format {
        case .csv: return [UTType.commaSeparatedText]
        case .json: return [UTType.json]
        case .excel: return [UTType(filenameExtension: "xlsx") ?? .commaSeparatedText]
        }
    }()
    panel.nameFieldStringValue = "crypto_prices.\(format == .excel ? "xlsx" : format.rawValue)"
    panel.begin { resp in
        guard resp == .OK, let url = panel.url else { return }
        let content: String
        switch format {
        case .csv:
            content = csvString(coins)
        case .json:
            content = jsonString(coins)
        case .excel:
            content = csvString(coins) // XLSX would need a lib; CSV-compatible export
        }
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }
}

func csvString(_ coins: [Coin]) -> String {
    var s = "Symbol,Name,Price (USD),24h Change %,Market Cap,Volume 24h\n"
    let df = NumberFormatter(); df.maximumFractionDigits = 2
    let mf = NumberFormatter(); mf.maximumFractionDigits = 0
    for c in coins {
        s += "\(c.symbol),\(c.name),\(df.string(from: NSNumber(value: c.price)) ?? ""),\(String(format: "%.2f", c.change24h)),\(mf.string(from: NSNumber(value: c.marketCap)) ?? ""),\(mf.string(from: NSNumber(value: c.volume24h)) ?? "")\n"
    }
    return s
}

func jsonString(_ coins: [Coin]) -> String {
    let arr = coins.map { c -> [String: Any] in
        ["symbol": c.symbol, "name": c.name, "price_usd": c.price, "change_24h_pct": c.change24h, "market_cap": c.marketCap, "volume_24h": c.volume24h]
    }
    if let data = try? JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted) {
        return String(data: data, encoding: .utf8) ?? "[]"
    }
    return "[]"
}

// GraphQL-style JSON export
func graphQLJSON(_ coins: [Coin]) -> String {
    let items = coins.map { c -> String in
        """
            {
              "symbol": "\(c.symbol)",
              "name": "\(c.name)",
              "price": \(c.price),
              "change24h": \(String(format: "%.2f", c.change24h)),
              "marketCap": \(Int64(c.marketCap)),
              "volume24h": \(Int64(c.volume24h))
            }
            """
    }.joined(separator: ",\n")
    return """
    {
      "data": {
        "cryptoPrices": [
    \(items)
        ]
      }
    }
    """
}

// MARK: - View

struct PriceView: View {
    @StateObject private var service = CoinService()
    @State private var selectedExport: ExportFormat = .csv
    @State private var showGraphQL = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 14)).foregroundColor(.orange)
                Text("CoinWatch")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                Spacer()
                if service.isLoading {
                    ProgressView().scaleEffect(0.5).frame(width: 12, height: 12)
                }
                Button(action: { service.fetch() }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(red: 0.06, green: 0.06, blue: 0.10))

            Divider().background(Color.white.opacity(0.06))

            // Price list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(service.coins) { coin in
                        CoinRow(coin: coin)
                        Divider().background(Color.white.opacity(0.03))
                    }
                }
            }

            // Last updated
            if let updated = service.lastUpdated {
                HStack {
                    Text("Updated \(updated.formatted(.relative(presentation: .numeric)))")
                        .font(.system(size: 8)).foregroundColor(.white.opacity(0.2))
                    Spacer()
                }.padding(.horizontal, 12).padding(.vertical, 3)
            }

            Divider().background(Color.white.opacity(0.06))

            // Export bar
            HStack(spacing: 6) {
                Picker("", selection: $selectedExport) {
                    ForEach(ExportFormat.allCases, id: \.self) { f in
                        Text(f.label).tag(f)
                    }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 200)

                Button(action: { exportData(coins: service.coins, format: selectedExport) }) {
                    HStack(spacing: 3) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 9))
                        Text("Export").font(.system(size: 9, weight: .medium))
                    }
                    .foregroundColor(.black).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color.orange.opacity(0.9)).cornerRadius(4)
                }.buttonStyle(.plain)

                Button(action: {
                    let str = graphQLJSON(service.coins)
                    let panel = NSSavePanel()
                    panel.allowedContentTypes = [UTType.json]
                    panel.nameFieldStringValue = "crypto_graphql.json"
                    panel.begin { resp in
                        if resp == .OK, let url = panel.url {
                            try? str.write(to: url, atomically: true, encoding: .utf8)
                        }
                    }
                }) {
                    Text("GQL").font(.system(size: 8, weight: .bold))
                        .foregroundColor(.pink.opacity(0.8)).padding(.horizontal, 6).padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.pink.opacity(0.3), lineWidth: 1))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
    }
}

struct CoinRow: View {
    let coin: Coin

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Text(coin.symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 20)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(4)

            VStack(alignment: .leading, spacing: 1) {
                Text(coin.name).font(.system(size: 11)).foregroundColor(.white.opacity(0.8))
                Text("MCap: \(shortNum(coin.marketCap))").font(.system(size: 8)).foregroundColor(.white.opacity(0.2))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "$%.2f", coin.price))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                Text(String(format: "%+.2f%%", coin.change24h))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(coin.change24h >= 0 ? .green : .red)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }

    func shortNum(_ n: Double) -> String {
        if n >= 1_000_000_000_000 { return String(format: "%.1fT", n/1e12) }
        if n >= 1_000_000_000 { return String(format: "%.1fB", n/1e9) }
        if n >= 1_000_000 { return String(format: "%.1fM", n/1e6) }
        return String(format: "%.0f", n)
    }
}
