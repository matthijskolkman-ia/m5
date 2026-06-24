import SwiftUI

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

            M5View()
                .tabItem {
                    Image(systemName: "cpu.fill")
                    Text("M5")
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
