import SwiftUI
import CoreBluetooth
import CoreWLAN
import UniformTypeIdentifiers

// MARK: - BLE Device

struct BLEDevice: Identifiable {
    let id = UUID()
    var name: String = "Unknown"
    var identifier: String = ""
    var rssi: Int = 0
    var services: [String] = []
    var lastSeen: Date = Date()
    var manufacturerData: String = ""
}

// MARK: - WiFi Network

struct WiFiNetwork: Identifiable {
    let id = UUID()
    var ssid: String = ""
    var bssid: String = ""
    var channel: Int = 0
    var rssi: Int = 0
    var security: String = ""
    var band: String = ""
}

// MARK: - BLE Scanner

class BLEScanner: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var devices: [BLEDevice] = []
    @Published var isScanning = false
    @Published var bleState: String = "Unknown"

    private var central: CBCentralManager!
    private var deviceMap: [String: BLEDevice] = [:]

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn: bleState = "Ready"
        case .poweredOff: bleState = "Off"
        case .unauthorized: bleState = "Unauthorized"
        case .unsupported: bleState = "Not supported"
        default: bleState = "Unknown"
        }
    }

    func startScan() {
        guard central.state == .poweredOn else { return }
        isScanning = true
        deviceMap.removeAll()
        devices.removeAll()
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        // Auto-stop after 15s
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { self.stopScan() }
    }

    func stopScan() {
        central.stopScan()
        isScanning = false
        devices = deviceMap.values.sorted { $0.rssi > $1.rssi }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        let id = peripheral.identifier.uuidString
        let rssi = RSSI.intValue
        var services: [String] = []
        if let srvUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            services = srvUUIDs.map { $0.uuidString }
        }
        var mfrData = ""
        if let mfr = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            mfrData = mfr.map { String(format: "%02X", $0) }.joined(separator: " ")
        }
        var device = deviceMap[id] ?? BLEDevice()
        device.name = name; device.identifier = id; device.rssi = rssi
        device.services = services; device.lastSeen = Date(); device.manufacturerData = mfrData
        deviceMap[id] = device
        // Update live list every ~1s
        if deviceMap.count % 5 == 0 {
            devices = deviceMap.values.sorted { $0.rssi > $1.rssi }
        }
    }
}

// MARK: - WiFi Scanner

class WiFiScanner: ObservableObject {
    @Published var networks: [WiFiNetwork] = []
    @Published var isScanning = false
    @Published var currentSSID: String = ""

    func scan() {
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async {
            let client = CWWiFiClient.shared()
            let iface = client.interface()

            var nets: [WiFiNetwork] = []
            if let current = iface?.ssid() { self.currentSSID = current }

            do {
                // Try scanning
                let scanResults = try? iface?.scanForNetworks(withName: nil)
                if let networks = scanResults {
                    for net in networks {
                        var n = WiFiNetwork()
                        n.ssid = net.ssid ?? "Hidden"
                        n.bssid = net.bssid ?? "—"
                        n.channel = net.wlanChannel?.channelNumber ?? 0
                        n.rssi = net.rssiValue
                        n.band = (net.wlanChannel?.channelNumber ?? 0) > 14 ? "5 GHz" : "2.4 GHz"
                        // Security
                        if net.supportsSecurity(.wpa3Enterprise) || net.supportsSecurity(.wpa3Personal) { n.security = "WPA3" }
                        else if net.supportsSecurity(.wpa2Enterprise) || net.supportsSecurity(.wpa2Personal) { n.security = "WPA2" }
                        else if net.supportsSecurity(.wpaEnterprise) || net.supportsSecurity(.wpaPersonal) { n.security = "WPA" }
                        else if net.supportsSecurity(.dynamicWEP) { n.security = "WEP" }
                        else { n.security = "Open" }
                        nets.append(n)
                    }
                }
            } catch {
                // Fallback: try airport command
                nets = self.airportScan()
            }

            if nets.isEmpty { nets = self.airportScan() }

            if !nets.isEmpty {
                nets.sort { $0.rssi > $1.rssi }
            }

            DispatchQueue.main.async {
                self.networks = nets
                self.isScanning = false
            }
        }
    }

    private func airportScan() -> [WiFiNetwork] {
        let task = Process()
        task.launchPath = "/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport"
        task.arguments = ["-s"]
        let pipe = Pipe(); task.standardOutput = pipe
        do {
            try task.run(); task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let str = String(data: data, encoding: .utf8) else { return [] }
            var nets: [WiFiNetwork] = []
            let lines = str.split(separator: "\n").dropFirst()
            for line in lines {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                guard parts.count >= 3 else { continue }
                var n = WiFiNetwork()
                n.ssid = String(parts[0])
                n.bssid = String(parts[1])
                n.rssi = Int(parts[2]) ?? 0
                if parts.count >= 4 { n.channel = Int(parts[3]) ?? 0 }
                if parts.count >= 6 { n.security = String(parts[5]) }
                nets.append(n)
            }
            return nets
        } catch { return [] }
    }
}

// MARK: - Export

func exportScanData(ble: [BLEDevice], wifi: [WiFiNetwork], format: String) {
    let panel = NSSavePanel()
    panel.allowedContentTypes = format == "csv" ? [UTType.commaSeparatedText] : [UTType.json]
    panel.nameFieldStringValue = "airscan.\(format)"
    panel.begin { resp in
        guard resp == .OK, let url = panel.url else { return }
        if format == "csv" {
            var s = "Type,Name,ID,BSSID,RSSI,Extra\n"
            for d in ble { s += "BLE,\(d.name),\(d.identifier),,\(d.rssi),\(d.services.joined(separator: ";"))\n" }
            for w in wifi { s += "WiFi,\(w.ssid),,\(w.bssid),\(w.rssi),\(w.security) CH\(w.channel)\n" }
            try? s.write(to: url, atomically: true, encoding: .utf8)
        } else {
            let data: [String: Any] = [
                "ble_devices": ble.map { ["name": $0.name, "id": $0.identifier, "rssi": $0.rssi, "services": $0.services] },
                "wifi_networks": wifi.map { ["ssid": $0.ssid, "bssid": $0.bssid, "rssi": $0.rssi, "channel": $0.channel, "security": $0.security] }
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted) {
                try? jsonData.write(to: url)
            }
        }
    }
}

// MARK: - View

struct ScannerView: View {
    @StateObject private var ble = BLEScanner()
    @StateObject private var wifi = WiFiScanner()
    @State private var selectedTab = 0
    @State private var exportFormat = "json"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 13)).foregroundColor(.cyan)
                Text("AirScanner").font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.8))
                Spacer()
                Text(ble.bleState).font(.system(size: 8)).foregroundColor(ble.bleState == "Ready" ? .green : .red)
                Circle().fill(ble.isScanning ? Color.green : Color.gray.opacity(0.3)).frame(width: 6, height: 6)
            }.padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(red: 0.06, green: 0.06, blue: 0.10))

            // Tab picker
            Picker("", selection: $selectedTab) {
                Text("BLE (\(ble.devices.count))").tag(0)
                Text("WiFi (\(wifi.networks.count))").tag(1)
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 12).padding(.vertical, 4)

            Divider().background(Color.white.opacity(0.05))

            // Device list
            if selectedTab == 0 {
                bleList
            } else {
                wifiList
            }

            Divider().background(Color.white.opacity(0.06))

            // Action bar
            HStack(spacing: 8) {
                Button(action: {
                    if ble.isScanning { ble.stopScan() } else { ble.startScan(); wifi.scan() }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: ble.isScanning ? "stop.fill" : "play.fill").font(.system(size: 9))
                        Text(ble.isScanning ? "Stop" : "Scan").font(.system(size: 10, weight: .medium))
                    }.foregroundColor(.black).padding(.horizontal, 14).padding(.vertical, 5)
                        .background(ble.isScanning ? Color.red.opacity(0.8) : Color.cyan).cornerRadius(5)
                }.buttonStyle(.plain)

                Picker("", selection: $exportFormat) {
                    Text("JSON").tag("json"); Text("CSV").tag("csv")
                }.pickerStyle(.segmented).labelsHidden().frame(width: 100)

                Button(action: { exportScanData(ble: ble.devices, wifi: wifi.networks, format: exportFormat) }) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 9)).foregroundColor(.white.opacity(0.5))
                }.buttonStyle(.plain)

                Spacer()
                Text("\(ble.devices.count) BLE · \(wifi.networks.count) WiFi")
                    .font(.system(size: 7)).foregroundColor(.white.opacity(0.2))
            }.padding(.horizontal, 12).padding(.vertical, 6)
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
    }

    var bleList: some View {
        Group {
            if ble.devices.isEmpty && !ble.isScanning {
                VStack { Spacer(); Text("Tap Scan to discover BLE devices").font(.caption).foregroundColor(.gray); Spacer() }
            } else if ble.isScanning && ble.devices.isEmpty {
                VStack { Spacer(); ProgressView(); Text("Scanning...").font(.caption).foregroundColor(.gray); Spacer() }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(ble.devices) { device in
                            bleRow(device)
                            Divider().background(Color.white.opacity(0.03)).padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    var wifiList: some View {
        Group {
            if wifi.networks.isEmpty && !wifi.isScanning {
                VStack { Spacer(); Text("Tap Scan to discover WiFi networks").font(.caption).foregroundColor(.gray); Spacer() }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(wifi.networks) { net in
                            wifiRow(net)
                            Divider().background(Color.white.opacity(0.03)).padding(.leading, 12)
                        }
                    }
                }
            }
        }
    }

    func bleRow(_ d: BLEDevice) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 8)).foregroundColor(rssiColor(d.rssi))
            VStack(alignment: .leading, spacing: 2) {
                Text(d.name).font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.85)).lineLimit(1)
                Text(d.identifier.prefix(16) + "...").font(.system(size: 7, design: .monospaced)).foregroundColor(.gray)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(d.rssi) dBm").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(rssiColor(d.rssi))
                if !d.services.isEmpty {
                    Text("\(d.services.count) svc").font(.system(size: 7)).foregroundColor(.cyan.opacity(0.5))
                }
            }
        }.padding(.horizontal, 12).padding(.vertical, 6)
    }

    func wifiRow(_ n: WiFiNetwork) -> some View {
        HStack(spacing: 8) {
            Image(systemName: n.security == "Open" ? "wifi" : "lock.wifi")
                .font(.system(size: 9)).foregroundColor(rssiColor(n.rssi))
            VStack(alignment: .leading, spacing: 2) {
                Text(n.ssid).font(.system(size: 10, weight: .medium)).foregroundColor(.white.opacity(0.85)).lineLimit(1)
                HStack(spacing: 4) {
                    Text(n.bssid).font(.system(size: 7, design: .monospaced)).foregroundColor(.gray)
                    Text("· CH\(n.channel)").font(.system(size: 7)).foregroundColor(.gray)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(n.rssi) dBm").font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundColor(rssiColor(n.rssi))
                Text(n.security).font(.system(size: 7)).foregroundColor(n.security == "Open" ? .orange : .green.opacity(0.6))
            }
        }.padding(.horizontal, 12).padding(.vertical, 6)
    }

    func rssiColor(_ rssi: Int) -> Color {
        if rssi > -50 { return .green }
        if rssi > -70 { return .yellow }
        return .red.opacity(0.7)
    }
}
