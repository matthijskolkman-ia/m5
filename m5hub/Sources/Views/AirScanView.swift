import SwiftUI
import CoreBluetooth
import CoreNFC

// MARK: - BLE Device Model

struct BLEDeviceIOS: Identifiable {
    let id = UUID()
    var name: String = "Unknown"
    var identifier: String = ""
    var rssi: Int = 0
    var lastSeen: Date = Date()
}

// MARK: - NFC Tag Model

struct NFCTag: Identifiable {
    let id = UUID()
    var type: String = ""
    var serialNumber: String = ""
    var data: String = ""
    var timestamp: Date = Date()
}

// MARK: - BLE Scanner

class BLEScannerIOS: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var devices: [BLEDeviceIOS] = []
    @Published var isScanning = false
    @Published var bleState: String = "Unknown"

    private var central: CBCentralManager!
    private var deviceMap: [String: BLEDeviceIOS] = [:]

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
        var device = deviceMap[id] ?? BLEDeviceIOS()
        device.name = name; device.identifier = id; device.rssi = RSSI.intValue; device.lastSeen = Date()
        deviceMap[id] = device
    }
}

// MARK: - NFC Reader

class NFCReader: NSObject, ObservableObject, NFCNDEFReaderSessionDelegate {
    @Published var tags: [NFCTag] = []
    @Published var isReading = false
    @Published var statusMessage = ""
    @Published var isSupported = NFCNDEFReaderSession.readingAvailable

    private var session: NFCNDEFReaderSession?

    func startReading() {
        guard NFCNDEFReaderSession.readingAvailable else {
            statusMessage = "NFC not available on this device"
            return
        }
        isReading = true
        statusMessage = "Hold near NFC tag..."
        session = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near an NFC tag"
        session?.begin()
    }

    func stopReading() {
        session?.invalidate()
        isReading = false
        statusMessage = ""
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isReading = false
            self.statusMessage = "Session ended"
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        for message in messages {
            for record in message.records {
                var tag = NFCTag()
                tag.type = nfcTypeName(record.typeNameFormat)
                tag.serialNumber = record.identifier.map { String(format: "%02X", $0) }.joined()
                if let payload = String(data: record.payload, encoding: .utf8) {
                    tag.data = String(payload.dropFirst(3)) // Skip language code
                } else {
                    tag.data = record.payload.map { String(format: "%02X", $0) }.joined(separator: " ")
                }
                DispatchQueue.main.async {
                    self.tags.insert(tag, at: 0)
                    self.statusMessage = "Read: \(tag.type)"
                }
            }
        }
    }

    private func nfcTypeName(_ t: NFCTypeNameFormat) -> String {
        switch t {
        case .empty: return "Empty"
        case .nfcWellKnown: return "Well-Known"
        case .media: return "Media"
        case .absoluteURI: return "URI"
        case .nfcExternal: return "External"
        case .unknown: return "Unknown"
        @unknown default: return "Other"
        }
    }
}

// MARK: - View

struct AirScanView: View {
    @StateObject private var ble = BLEScannerIOS()
    @StateObject private var nfc = NFCReader()
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 14)).foregroundColor(.cyan)
                Text("AirScan").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Circle().fill(ble.isScanning || nfc.isReading ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 7, height: 7)
            }.padding(.horizontal, 16).padding(.vertical, 10)

            // Mode picker
            Picker("", selection: $selectedTab) {
                Text("BLE (\(ble.devices.count))").tag(0)
                Text("NFC (\(nfc.tags.count))").tag(1)
            }.pickerStyle(.segmented).padding(.horizontal, 16).padding(.bottom, 8)

            // RFID emulation note
            if selectedTab == 1 {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle").font(.system(size: 9))
                    Text("Reads NDEF tags (not RFID emulation — that needs Flipper hardware)")
                        .font(.system(size: 8))
                }
                .foregroundColor(.white.opacity(0.25))
                .padding(.horizontal, 16).padding(.bottom, 4)
            }

            Divider().background(Color.white.opacity(0.1))

            // Content
            if selectedTab == 0 {
                bleContent
            } else {
                nfcContent
            }

            Divider().background(Color.white.opacity(0.1))

            // Action button
            Button(action: {
                if selectedTab == 0 {
                    ble.isScanning ? ble.stopScan() : ble.startScan()
                } else {
                    nfc.isReading ? nfc.stopReading() : nfc.startReading()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: selectedTab == 0
                        ? (ble.isScanning ? "stop.fill" : "play.fill")
                        : (nfc.isReading ? "stop.fill" : "radiowaves.right"))
                    .font(.system(size: 12))
                    Text(selectedTab == 0
                        ? (ble.isScanning ? "Stop Scan" : "Scan BLE")
                        : (nfc.isReading ? "Stop Reading" : "Read NFC Tag"))
                    .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background((ble.isScanning || nfc.isReading) ? Color.red.opacity(0.8) : Color.cyan)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 10)
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.12))
    }

    var bleContent: some View {
        Group {
            if ble.devices.isEmpty && !ble.isScanning {
                VStack { Spacer()
                    Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 30)).foregroundColor(.gray.opacity(0.3))
                    Text("Tap Scan to discover BLE devices").font(.caption).foregroundColor(.gray)
                    Text("BLE State: \(ble.bleState)").font(.caption2).foregroundColor(.gray.opacity(0.5))
                    Spacer()
                }
            } else if ble.isScanning && ble.devices.isEmpty {
                VStack { Spacer(); ProgressView(); Text("Scanning...").font(.caption).foregroundColor(.gray); Spacer() }
            } else {
                List {
                    ForEach(ble.devices) { device in
                        HStack(spacing: 10) {
                            Image(systemName: rssiIcon(device.rssi))
                                .font(.system(size: 12)).foregroundColor(rssiColor(device.rssi))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(device.name).font(.system(size: 13)).foregroundColor(.white)
                                Text(device.identifier.prefix(16) + "...")
                                    .font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                            }
                            Spacer()
                            Text("\(device.rssi) dBm")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(rssiColor(device.rssi))
                        }.padding(.vertical, 2)
                    }
                }.listStyle(.plain)
            }
        }
    }

    var nfcContent: some View {
        Group {
            if !nfc.isSupported {
                VStack { Spacer()
                    Text("NFC not available").font(.caption).foregroundColor(.gray)
                    Spacer()
                }
            } else if nfc.tags.isEmpty {
                VStack { Spacer()
                    Image(systemName: "wave.3.right").font(.system(size: 30)).foregroundColor(.gray.opacity(0.3))
                    Text(nfc.statusMessage.isEmpty ? "Tap to read an NFC tag" : nfc.statusMessage)
                        .font(.caption).foregroundColor(.gray)
                    Spacer()
                }
            } else {
                List {
                    ForEach(nfc.tags) { tag in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(tag.type).font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.cyan).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.cyan.opacity(0.15)).cornerRadius(4)
                                Spacer()
                                Text(tag.timestamp, style: .time).font(.system(size: 8)).foregroundColor(.gray)
                            }
                            if !tag.serialNumber.isEmpty {
                                Text("ID: \(tag.serialNumber)").font(.system(size: 9, design: .monospaced)).foregroundColor(.gray)
                            }
                            Text(tag.data).font(.system(size: 10)).foregroundColor(.white.opacity(0.7)).lineLimit(3)
                        }.padding(.vertical, 4)
                    }
                }.listStyle(.plain)
            }
        }
    }

    func rssiColor(_ rssi: Int) -> Color {
        if rssi > -50 { return .green }
        if rssi > -70 { return .yellow }
        return .red.opacity(0.7)
    }

    func rssiIcon(_ rssi: Int) -> String {
        if rssi > -50 { return "antenna.radiowaves.left.and.right" }
        if rssi > -70 { return "dot.radiowaves.left.and.right" }
        return "dot.radiowaves.left.and.right"
    }
}
