import SwiftUI

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
