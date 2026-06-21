import SwiftUI

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
