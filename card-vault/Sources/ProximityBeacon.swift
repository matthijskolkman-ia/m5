import Foundation
import CoreBluetooth

// MARK: - BLE Proximity Beacon (Mac advertises; iPhone measures RSSI)

/// Shared Bluetooth service UUID — must match the iPhone app's `ProximityTracker`.
enum ProximityService {
    static let serviceUUID = CBUUID(string: "7A10D1B0-5E4C-4B3E-9A8D-2C1F0E4A6B7C")
}

@MainActor
final class ProximityBeacon: NSObject, ObservableObject {
    @Published var isAdvertising = false
    @Published var statusMessage = "Proximity beacon off"

    private var peripheralManager: CBPeripheralManager?

    func startAdvertising() {
        guard peripheralManager == nil else { return }
        statusMessage = "Starting proximity beacon..."
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func stopAdvertising() {
        peripheralManager?.stopAdvertising()
        peripheralManager = nil
        isAdvertising = false
        statusMessage = "Proximity beacon off"
    }
}

extension ProximityBeacon: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Task { @MainActor in
            switch peripheral.state {
            case .poweredOn:
                self.startAdvertising(peripheral)
            case .unauthorized:
                self.statusMessage = "Bluetooth not authorized"
            case .unsupported:
                self.statusMessage = "Bluetooth unsupported on this Mac"
            case .poweredOff:
                self.statusMessage = "Bluetooth is off"
            default:
                break
            }
        }
    }

    private func startAdvertising(_ peripheral: CBPeripheralManager) {
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [ProximityService.serviceUUID],
            CBAdvertisementDataLocalNameKey: "CardVault-Mac"
        ])
        isAdvertising = true
        statusMessage = "Proximity beacon on"
    }
}
