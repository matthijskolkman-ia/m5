import SwiftUI
import Network

// MARK: - Bonjour Scanner

final class HomeScanner: NSObject, ObservableObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @Published var devices: [HomeDevice] = []
    @Published var isScanning = false
    @Published var status = "Ready"

    private var browser: NetServiceBrowser?
    private var resolving: Set<NetService> = []

    struct HomeDevice: Identifiable {
        let id = UUID()
        let name: String
        let type: String
        var hostname: String?
        var ip: String?
        var port: Int?
        var brand: String
    }

    func start() {
        devices = []
        status = "Scanning…"
        isScanning = true
        browser = NetServiceBrowser()
        browser?.delegate = self
        // HomeKit: _hap._tcp, also scan _http._tcp for web devices
        browser?.searchForServices(ofType: "_hap._tcp", inDomain: "local.")
    }

    func stop() {
        browser?.stop()
        isScanning = false
        status = "\(devices.count) devices"
    }

    // MARK: - Browser Delegate

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        service.resolve(withTimeout: 5)
        resolving.insert(service)
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        devices.removeAll { $0.name == service.name }
        status = "\(devices.count) devices"
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        isScanning = false
    }

    // MARK: - Resolve Delegate

    func netServiceDidResolveAddress(_ sender: NetService) {
        resolving.remove(sender)

        var ip: String?
        var hostname: String?
        if let addr = sender.addresses?.first {
            var h = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            addr.withUnsafeBytes { buf in
                _ = buf.baseAddress?.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    getnameinfo(sa, socklen_t(addr.count), &h, socklen_t(h.count), nil, 0, NI_NUMERICHOST)
                }
            }
            ip = String(cString: h)
            hostname = ip
        }

        let brand = detectBrand(sender.name)
        let device = HomeDevice(
            name: sender.name,
            type: sender.type,
            hostname: sender.hostName,
            ip: ip,
            port: sender.port,
            brand: brand
        )

        if !devices.contains(where: { $0.name == sender.name }) {
            devices.append(device)
            status = "\(devices.count) devices"
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        resolving.remove(sender)
    }

    private func detectBrand(_ name: String) -> String {
        let n = name.lowercased()
        if n.contains("ikea") || n.contains("tradfri") { return "IKEA" }
        if n.contains("hue") || n.contains("philips") { return "Philips" }
        if n.contains("eve") { return "Eve" }
        if n.contains("nanoleaf") { return "Nanoleaf" }
        if n.contains("aqara") { return "Aqara" }
        if n.contains("meross") { return "Meross" }
        if n.contains("wemo") { return "Wemo" }
        if n.contains("homepod") { return "Apple" }
        if n.contains("appletv") { return "Apple" }
        return "Generic"
    }
}

// MARK: - Main View

struct HomeScanView: View {
    @StateObject private var scanner = HomeScanner()
    let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "house.fill")
                    .font(.system(size: 11)).foregroundColor(.orange.opacity(0.7))
                Text("HomeScan")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Circle()
                    .fill(scanner.isScanning ? .green : .white.opacity(0.15))
                    .frame(width: 5, height: 5)
                    .shadow(color: scanner.isScanning ? .green : .clear, radius: 3)
                Text(scanner.status)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.white.opacity(0.25))
            }.padding(.horizontal, 10).padding(.vertical, 6)

            Divider().background(Color.white.opacity(0.06))

            // Device list
            ScrollView {
                VStack(spacing: 0) {
                    if scanner.devices.isEmpty && !scanner.isScanning {
                        VStack(spacing: 8) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 24)).foregroundColor(.white.opacity(0.08))
                            Text("No HomeKit devices found")
                                .font(.system(size: 10)).foregroundColor(.white.opacity(0.2))
                        }.padding(.top, 40)
                    }
                    ForEach(scanner.devices) { device in
                        DeviceRow(device: device)
                        Divider().padding(.leading, 36).background(Color.white.opacity(0.04))
                    }
                }
            }

            Spacer()

            // Controls
            HStack {
                Button(action: scanner.start) {
                    Label("Scan", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }.buttonStyle(.plain)
                Spacer()
                Text("HomeKit · _hap._tcp")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.white.opacity(0.15))
            }.padding(.horizontal, 10).padding(.bottom, 5)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.08))
        .preferredColorScheme(.dark)
        .onAppear { scanner.start() }
        .onReceive(timer) { _ in scanner.start() }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: HomeScanner.HomeDevice

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(brandColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7)).lineLimit(1)
                HStack(spacing: 4) {
                    Text(device.brand)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(brandColor.opacity(0.7))
                    if let ip = device.ip {
                        Text("· \(ip)")
                            .font(.system(size: 7, design: .monospaced))
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
            }
            Spacer()
            if let port = device.port {
                Text(":\(port)")
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(.white.opacity(0.15))
            }
        }.padding(.horizontal, 10).padding(.vertical, 6)
    }

    var icon: String {
        switch device.brand {
        case "IKEA": return "lamp.table.fill"
        case "Philips": return "lightbulb.fill"
        case "Apple": return "apple.logo"
        case "Eve": return "leaf.fill"
        default: return "square.grid.3x3.fill"
        }
    }

    var brandColor: Color {
        switch device.brand {
        case "IKEA": return .yellow
        case "Philips": return .purple
        case "Apple": return .white
        case "Eve": return .green
        default: return .blue.opacity(0.6)
        }
    }
}
