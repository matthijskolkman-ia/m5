import Foundation
import CoreBluetooth

// MARK: - BLE Proximity Tracker (iPhone measures RSSI from Mac beacon)

/// Shared Bluetooth service UUID — must match the Mac app's `ProximityBeacon`.
enum ProximityService {
    static let serviceUUID = CBUUID(string: "7A10D1B0-5E4C-4B3E-9A8D-2C1F0E4A6B7C")
}

@MainActor
final class ProximityTracker: NSObject, ObservableObject {
    @Published var rssi: Int?
    @Published var distanceMeters: Double?

    private var centralManager: CBCentralManager?

    var distanceText: String {
        guard let d = distanceMeters else { return "" }
        if d < 1.0 {
            return String(format: "%.0f cm", d * 100)
        } else {
            return String(format: "%.1f m", d)
        }
    }

    func start() {
        guard centralManager == nil else { return }
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func stop() {
        centralManager?.stopScan()
        centralManager = nil
        rssi = nil
        distanceMeters = nil
    }

    // Rough distance from RSSI using the log-distance path-loss model.
    nonisolated static func estimateDistance(rssi: Int, txPower: Int) -> Double {
        let pathLossExponent = 2.0
        let distance = pow(10.0, (Double(txPower) - Double(rssi)) / (10.0 * pathLossExponent))
        return max(0.0, distance)
    }
}

extension ProximityTracker: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            if central.state == .poweredOn {
                central.scanForPeripherals(
                    withServices: [ProximityService.serviceUUID],
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
                )
            } else {
                self.rssi = nil
                self.distanceMeters = nil
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        let rssi = RSSI.intValue
        let txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue ?? -59
        let distance = Self.estimateDistance(rssi: rssi, txPower: txPower)

        Task { @MainActor in
            self.rssi = rssi
            self.distanceMeters = distance
        }
    }
}
