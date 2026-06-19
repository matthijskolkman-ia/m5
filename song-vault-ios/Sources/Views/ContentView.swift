import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = VaultViewModel()

    var body: some View {
        ZStack {
            Color(hex: "0a0a0f").ignoresSafeArea()

            switch viewModel.state {
            case .loading:
                ProgressView()
                    .tint(.purple)
                    .scaleEffect(1.2)

            case .locked, .exhausted:
                UnlockView(viewModel: viewModel)

            case .unlocked(let catalog):
                CatalogListView(
                    catalog: catalog,
                    remaining: catalog.remaining,
                    total: catalog.maxAuthorizations
                )

            case .error(let msg):
                VStack(spacing: 16) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text(msg)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") {
                        Task { await viewModel.load() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

// MARK: - Hex Color Helper

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        _ = scanner.scanString("#")
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
