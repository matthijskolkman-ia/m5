import SwiftUI
import Foundation
import UniformTypeIdentifiers


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



struct WeatherData {
    var temp: Double = 0
    var feelsLike: Double = 0
    var humidity: Int = 0
    var windSpeed: Double = 0
    var condition: String = "—"
    var icon: String = "cloud"
    var city: String = "—"
    var forecast: [ForecastDay] = []
}

struct ForecastDay: Identifiable {
    let id = UUID()
    var date: String = ""
    var tempMax: Double = 0
    var tempMin: Double = 0
    var condition: String = ""
}

class WeatherService: ObservableObject {
    @Published var weather = WeatherData()
    @Published var isLoading = false
    @Published var error: String?

    // Open-Meteo: free, no key, unlimited calls
    // Uses geocoding first to get coordinates, then weather

    func fetch(for city: String) {
        isLoading = true; error = nil
        // Geocode city → coordinates
        let geoURL = "https://geocoding-api.open-meteo.com/v1/search?name=\(city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city)&count=1"
        guard let url = URL(string: geoURL) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                  let results = json["results"] as? [[String:Any]],
                  let first = results.first,
                  let lat = first["latitude"] as? Double,
                  let lon = first["longitude"] as? Double,
                  let name = first["name"] as? String else {
                DispatchQueue.main.async { self?.isLoading = false; self?.error = "City not found" }; return
            }
            self.fetchWeather(lat: lat, lon: lon, city: name)
        }.resume()
    }

    private func fetchWeather(lat: Double, lon: Double, city: String) {
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=auto&forecast_days=5"
        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                  let current = json["current"] as? [String:Any],
                  let daily = json["daily"] as? [String:Any] else {
                DispatchQueue.main.async { self?.isLoading = false }; return
            }

            var w = WeatherData()
            w.city = city
            w.temp = current["temperature_2m"] as? Double ?? 0
            w.feelsLike = current["apparent_temperature"] as? Double ?? 0
            w.humidity = current["relative_humidity_2m"] as? Int ?? 0
            w.windSpeed = current["wind_speed_10m"] as? Double ?? 0
            w.condition = self.weatherDesc(current["weather_code"] as? Int ?? 0)

            // Forecast
            let dates = daily["time"] as? [String] ?? []
            let maxTemps = daily["temperature_2m_max"] as? [Double] ?? []
            let minTemps = daily["temperature_2m_min"] as? [Double] ?? []
            let codes = daily["weather_code"] as? [Int] ?? []
            w.forecast = (0..<min(5, dates.count)).map { i in
                ForecastDay(date: String(dates[i].suffix(5)), tempMax: maxTemps[i], tempMin: minTemps[i], condition: self.weatherDesc(codes[i]))
            }

            DispatchQueue.main.async { self.weather = w; self.isLoading = false }
        }.resume()
    }

    private func weatherDesc(_ code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1,2,3: return "Partly cloudy"
        case 45,48: return "Fog"
        case 51,53,55: return "Drizzle"
        case 61,63,65: return "Rain"
        case 71,73,75: return "Snow"
        case 80,81,82: return "Showers"
        case 95,96,99: return "Thunderstorm"
        default: return "Cloudy"
        }
    }
}



struct NewsItem: Identifiable {
    let id = UUID()
    var title: String = ""
    var source: String = ""
    var url: String = ""
    var publishedAt: String = ""
}

class NewsService: ObservableObject {
    @Published var articles: [NewsItem] = []
    @Published var isLoading = false
    @Published var error: String?

    private var apiKey: String {
        UserDefaults.standard.string(forKey: "newsapi_key") ?? ""
    }

    func fetch() {
        guard !apiKey.isEmpty else { error = "Set NewsAPI key in Settings"; return }
        isLoading = true; error = nil

        // Top headlines, US, 10 results
        guard let url = URL(string: "https://newsapi.org/v2/top-headlines?country=us&pageSize=10&apiKey=\(apiKey)") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
                  let articles = json["articles"] as? [[String:Any]] else {
                DispatchQueue.main.async { self?.isLoading = false; self?.error = "Failed to load news" }; return
            }
            let items: [NewsItem] = articles.prefix(10).map { a in
                NewsItem(
                    title: a["title"] as? String ?? "",
                    source: (a["source"] as? [String:Any])?["name"] as? String ?? "",
                    url: a["url"] as? String ?? "",
                    publishedAt: String((a["publishedAt"] as? String ?? "").prefix(10))
                )
            }
            DispatchQueue.main.async { self.articles = items; self.isLoading = false }
        }.resume()
    }
}



struct ContentView: View {
    @StateObject private var crypto = CryptoService()
    @StateObject private var weather = WeatherService()
    @StateObject private var news = NewsService()
    @State private var weatherCity = UserDefaults.standard.string(forKey: "weather_city") ?? "Amsterdam"
    @State private var showSettings = false
    @State private var newsKey = UserDefaults.standard.string(forKey: "newsapi_key") ?? ""

    var body: some View {
        TabView {
            OverviewView(crypto: crypto, weather: weather, news: news)
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Overview")
                }

            CryptoView(service: crypto)
                .tabItem {
                    Image(systemName: "bitcoinsign.circle.fill")
                    Text("Crypto")
                }

            WeatherView(service: weather, city: $weatherCity)
                .tabItem {
                    Image(systemName: "cloud.sun.fill")
                    Text("Weather")
                }

            NewsView(service: news)
                .tabItem {
                    Image(systemName: "newspaper.fill")
                    Text("News")
                }
        }
        .onAppear {
            weather.fetch(for: weatherCity)
            if !newsKey.isEmpty { news.fetch() }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape").font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(newsKey: $newsKey, weatherCity: $weatherCity, onSave: {
                UserDefaults.standard.set(newsKey, forKey: "newsapi_key")
                UserDefaults.standard.set(weatherCity, forKey: "weather_city")
                if !newsKey.isEmpty { news.fetch() }
                weather.fetch(for: weatherCity)
                showSettings = false
            })
        }
    }
}

struct SettingsView: View {
    @Binding var newsKey: String
    @Binding var weatherCity: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Settings").font(.headline).foregroundColor(.white)
            VStack(alignment: .leading, spacing: 8) {
                Text("Weather City").font(.caption).foregroundColor(.gray)
                TextField("City name", text: $weatherCity).textFieldStyle(.roundedBorder)
                Text("NewsAPI Key").font(.caption).foregroundColor(.gray)
                TextField("api key from newsapi.org", text: $newsKey).textFieldStyle(.roundedBorder)
                Text("Free: 100 requests/day").font(.caption2).foregroundColor(.gray)
            }
            HStack {
                Button("Cancel") { dismiss() }
                Button("Save", action: onSave).buttonStyle(.borderedProminent)
            }
        }.padding().frame(width: 300)
    }
}



struct OverviewView: View {
    @ObservedObject var crypto: CryptoService
    @ObservedObject var weather: WeatherService
    @ObservedObject var news: NewsService

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text("Dashboard").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    if let updated = crypto.lastUpdated {
                        Text("Updated \(updated.formatted(.relative(presentation: .numeric)))")
                            .font(.system(size: 8)).foregroundColor(.white.opacity(0.25))
                    }
                }.padding(.horizontal, 14).padding(.top, 10)

                // Crypto summary
                summaryCard(title: "Crypto", icon: "bitcoinsign.circle.fill", color: .orange) {
                    if crypto.coins.isEmpty {
                        Text("Loading...").font(.caption).foregroundColor(.gray)
                    } else {
                        ForEach(crypto.coins.prefix(5)) { coin in
                            HStack {
                                Text(coin.symbol).font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white).frame(width: 36, alignment: .leading)
                                Text(String(format: "$%.2f", coin.price))
                                    .font(.system(size: 11, design: .monospaced)).foregroundColor(.white)
                                Spacer()
                                Text(String(format: "%+.1f%%", coin.change24h))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(coin.change24h >= 0 ? .green : .red)
                            }
                        }
                    }
                }

                // Weather summary
                summaryCard(title: "Weather", icon: "cloud.sun.fill", color: .blue) {
                    if weather.weather.city == "—" {
                        Text("Loading...").font(.caption).foregroundColor(.gray)
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(weather.weather.city).font(.system(size: 12, weight: .medium)).foregroundColor(.white)
                                Text(weather.weather.condition).font(.system(size: 10)).foregroundColor(.gray)
                            }
                            Spacer()
                            Text(String(format: "%.0f°C", weather.weather.temp))
                                .font(.system(size: 22, weight: .light, design: .monospaced)).foregroundColor(.white)
                        }
                        // Forecast row
                        HStack(spacing: 8) {
                            ForEach(weather.weather.forecast) { day in
                                VStack(spacing: 2) {
                                    Text(day.date).font(.system(size: 7)).foregroundColor(.gray)
                                    Text(String(format: "%.0f°", day.tempMax))
                                        .font(.system(size: 9, weight: .medium)).foregroundColor(.white)
                                }
                            }
                        }.padding(.top, 4)
                    }
                }

                // News summary
                summaryCard(title: "News", icon: "newspaper.fill", color: .purple) {
                    if news.articles.isEmpty {
                        Text(news.error ?? "Set NewsAPI key in Settings").font(.caption).foregroundColor(.gray)
                    } else {
                        ForEach(news.articles.prefix(4)) { article in
                            Text(article.title)
                                .font(.system(size: 10)).foregroundColor(.white.opacity(0.7)).lineLimit(2)
                            if article.title != news.articles.prefix(4).last?.title {
                                Divider().background(Color.white.opacity(0.05))
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 12)
        }
    }

    func summaryCard<Content: View>(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11)).foregroundColor(color)
                Text(title).font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.6))
                Spacer()
            }
            content()
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
        .padding(.horizontal, 12)
    }
}



struct CryptoView: View {
    @ObservedObject var service: CryptoService

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "bitcoinsign.circle.fill").font(.system(size: 13)).foregroundColor(.orange)
                Text("Crypto").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                Spacer()
                if service.isLoading { ProgressView().scaleEffect(0.5).frame(width: 12, height: 12) }
                Button(action: { service.fetch() }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                }.buttonStyle(.plain)
            }.padding(.horizontal, 14).padding(.vertical, 8)

            Divider().background(Color.white.opacity(0.05))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(service.coins) { coin in
                        HStack(spacing: 10) {
                            Text(coin.symbol).font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white).frame(width: 38, height: 20)
                                .background(Color.orange.opacity(0.2)).cornerRadius(4)
                            Text(coin.name).font(.system(size: 11)).foregroundColor(.white.opacity(0.7))
                            Spacer()
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(String(format: "$%.2f", coin.price))
                                    .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundColor(.white)
                                Text(String(format: "%+.2f%%", coin.change24h))
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(coin.change24h >= 0 ? .green : .red)
                            }
                        }.padding(.horizontal, 14).padding(.vertical, 8)
                        Divider().background(Color.white.opacity(0.03)).padding(.leading, 14)
                    }
                }
            }
        }
    }
}



struct WeatherView: View {
    @ObservedObject var service: WeatherService
    @Binding var city: String
    @State private var cityInput: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "cloud.sun.fill").font(.system(size: 13)).foregroundColor(.blue)
                Text("Weather").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                Spacer()
                if service.isLoading { ProgressView().scaleEffect(0.5).frame(width: 12, height: 12) }
            }.padding(.horizontal, 14).padding(.vertical, 8)

            // City input
            HStack(spacing: 6) {
                TextField("City", text: $cityInput).textFieldStyle(.roundedBorder).font(.system(size: 10))
                    .onSubmit { city = cityInput; service.fetch(for: city) }
                Button("Go") { city = cityInput; service.fetch(for: city) }
                    .font(.system(size: 10)).buttonStyle(.borderedProminent).controlSize(.small)
            }.padding(.horizontal, 14).padding(.bottom, 6)

            Divider().background(Color.white.opacity(0.05))

            let w = service.weather
            if w.city != "—" {
                ScrollView {
                    VStack(spacing: 12) {
                        // Current
                        VStack(spacing: 4) {
                            Text(w.city).font(.system(size: 16, weight: .medium)).foregroundColor(.white)
                            Text(w.condition).font(.system(size: 12)).foregroundColor(.gray)
                            Text(String(format: "%.1f°C", w.temp))
                                .font(.system(size: 40, weight: .thin, design: .monospaced)).foregroundColor(.white)
                            HStack(spacing: 16) {
                                Label("Feels \(String(format: "%.0f°", w.feelsLike))", systemImage: "thermometer").font(.system(size: 9)).foregroundColor(.gray)
                                Label("\(w.humidity)%", systemImage: "humidity").font(.system(size: 9)).foregroundColor(.gray)
                                Label("\(String(format: "%.0f", w.windSpeed)) km/h", systemImage: "wind").font(.system(size: 9)).foregroundColor(.gray)
                            }
                        }.padding(12).background(Color.white.opacity(0.03)).cornerRadius(8).padding(.horizontal, 14)

                        // Forecast
                        VStack(alignment: .leading, spacing: 6) {
                            Text("5-Day Forecast").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.5))
                            ForEach(w.forecast) { day in
                                HStack {
                                    Text(day.date).font(.system(size: 11)).foregroundColor(.white.opacity(0.6)).frame(width: 50, alignment: .leading)
                                    Text(day.condition).font(.system(size: 10)).foregroundColor(.gray)
                                    Spacer()
                                    Text(String(format: "%.0f°", day.tempMin)).font(.system(size: 10, design: .monospaced)).foregroundColor(.white.opacity(0.4))
                                    Text("—").font(.system(size: 8)).foregroundColor(.gray)
                                    Text(String(format: "%.0f°", day.tempMax)).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundColor(.white)
                                }.padding(.horizontal, 14)
                            }
                        }
                    }.padding(.vertical, 8)
                }
            } else if let err = service.error {
                Text(err).font(.caption).foregroundColor(.red).padding()
            } else {
                Spacer()
                Text("Enter a city").font(.caption).foregroundColor(.gray)
                Spacer()
            }
        }
        .onAppear { cityInput = city }
    }
}



struct NewsView: View {
    @ObservedObject var service: NewsService

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "newspaper.fill").font(.system(size: 13)).foregroundColor(.purple)
                Text("News").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                Spacer()
                if service.isLoading { ProgressView().scaleEffect(0.5).frame(width: 12, height: 12) }
                Button(action: { service.fetch() }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.4))
                }.buttonStyle(.plain)
            }.padding(.horizontal, 14).padding(.vertical, 8)

            Divider().background(Color.white.opacity(0.05))

            if let err = service.error {
                VStack(spacing: 8) {
                    Text(err).font(.caption).foregroundColor(.orange).padding(.top, 20)
                    Text("Get a free key at newsapi.org").font(.caption2).foregroundColor(.gray)
                }
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(service.articles) { article in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(article.title)
                                .font(.system(size: 11, weight: .medium)).foregroundColor(.white.opacity(0.85)).lineLimit(3)
                            HStack {
                                Text(article.source).font(.system(size: 8)).foregroundColor(.purple.opacity(0.6))
                                Text("·").foregroundColor(.gray)
                                Text(article.publishedAt).font(.system(size: 8)).foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        Divider().background(Color.white.opacity(0.03)).padding(.leading, 14)
                    }
                }
            }
        }
    }
}


