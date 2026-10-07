import Foundation
import MultipeerConnectivity
import SwiftUI

// MARK: - Connectivity Manager (Mac Host)

@MainActor
class ConnectivityManager: NSObject, ObservableObject {
    @Published var isHosting = false
    @Published var connectedPeers: [MCPeerID] = []
    @Published var lastReceivedCard: ReceivedCard?
    @Published var statusMessage = "Not hosting"

    private let serviceType = "cardvault-xfer"
    private let myPeerID = MCPeerID(displayName: Host.current().localizedName ?? "Mac")
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?

    struct ReceivedCard: Identifiable {
        let id = UUID()
        let name: String
        let cardNumber: String
        let rarity: String
        let isHolo: Bool
        let isReverseHolo: Bool
        let condition: String
        let imageData: Data?
    }

    override init() {
        super.init()
    }

    func startHosting() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session?.delegate = self
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["app": "cardvault"], serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        isHosting = true
        statusMessage = "Waiting for iPhone..."
    }

    func stopHosting() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        session?.disconnect()
        session = nil
        isHosting = false
        connectedPeers.removeAll()
        statusMessage = "Not hosting"
    }

    func sendConfirmation(to peer: MCPeerID, cardName: String) {
        guard let session = session else { return }
        let msg = "✅ \(cardName) added!"
        if let data = msg.data(using: .utf8) {
            try? session.send(data, toPeers: [peer], with: .reliable)
        }
    }

    // MARK: Decode received card

    private func decodeCard(from data: Data) -> ReceivedCard? {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = dict["name"] as? String else { return nil }

        return ReceivedCard(
            name: name,
            cardNumber: dict["cardNumber"] as? String ?? "",
            rarity: dict["rarity"] as? String ?? "Common",
            isHolo: dict["isHolo"] as? Bool ?? false,
            isReverseHolo: dict["isReverseHolo"] as? Bool ?? false,
            condition: dict["condition"] as? String ?? "Mint",
            imageData: dict["imageBase64"] as? String != nil ? Data(base64Encoded: dict["imageBase64"] as! String) : nil
        )
    }
}

// MARK: - MCSessionDelegate

extension ConnectivityManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            if state == .connected {
                self.connectedPeers.append(peerID)
                self.statusMessage = "📱 \(peerID.displayName) connected"
            } else if state == .notConnected {
                self.connectedPeers.removeAll { $0 == peerID }
                self.statusMessage = self.connectedPeers.isEmpty ? "Waiting for iPhone..." : "📱 Connected"
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // decodeCard accesses no @Published state, safe to call here
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let name = dict["name"] as? String {
            let card = ReceivedCard(
                name: name,
                cardNumber: dict["cardNumber"] as? String ?? "",
                rarity: dict["rarity"] as? String ?? "Common",
                isHolo: dict["isHolo"] as? Bool ?? false,
                isReverseHolo: dict["isReverseHolo"] as? Bool ?? false,
                condition: dict["condition"] as? String ?? "Mint",
                imageData: (dict["imageBase64"] as? String).flatMap { Data(base64Encoded: $0) }
            )
            Task { @MainActor in
                self.lastReceivedCard = card
                self.sendConfirmation(to: peerID, cardName: card.name)
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension ConnectivityManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            invitationHandler(true, self.session)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            self.statusMessage = "Error: \(error.localizedDescription)"
        }
    }
}
