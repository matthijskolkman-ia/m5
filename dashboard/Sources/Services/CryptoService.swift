import Foundation

// MARK: - Models

struct Coin: Identifiable {
    let id: String; let symbol: String; let name: String
    var price: Double = 0; var change24h: Double = 0; var marketCap: Double = 0
}

// MARK: - Service

class CryptoService: ObservableObject {
    @Published var coins: [Coin] = []
    @Published var isLoading = false
    @Published var lastUpdated: Date?

    private let ids = ["bitcoin","ethereum","solana","ripple","cardano","dogecoin","polkadot","chainlink","avalanche-2","uniswap"]
    private let names = ["Bitcoin","Ethereum","Solana","XRP","Cardano","Dogecoin","Polkadot","Chainlink","Avalanche","Uniswap"]
    private let symbols = ["BTC","ETH","SOL","XRP","ADA","DOGE","DOT","LINK","AVAX","UNI"]

    init() { fetch(); Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in self.fetch() } }

    func fetch() {
        isLoading = true
        let idsStr = ids.joined(separator: ",")
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(idsStr)&vs_currencies=usd&include_24hr_change=true&include_market_cap=true") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String:[String:Double]] else {
                DispatchQueue.main.async { self?.isLoading = false }; return
            }
            let coins: [Coin] = self.ids.enumerated().map { i, id in
                var c = Coin(id: id, symbol: self.symbols[i], name: self.names[i])
                if let v = json[id] { c.price = v["usd"] ?? 0; c.change24h = v["usd_24h_change"] ?? 0; c.marketCap = v["usd_market_cap"] ?? 0 }
                return c
            }
            DispatchQueue.main.async { self.coins = coins; self.lastUpdated = Date(); self.isLoading = false }
        }.resume()
    }
}
