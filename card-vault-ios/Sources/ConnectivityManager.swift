import Foundation
import MultipeerConnectivity

// MARK: - iOS Connectivity Manager (Client)

@MainActor
class iOSConnectivity: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var statusMessage = "Searching for Mac..."
    @Published var lastConfirmation: String?

    private let serviceType = "cardvault-xfer"
    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var session: MCSession?
    private var browser: MCNearbyServiceBrowser?

    override init() {
        super.init()
        startBrowsing()
    }

    func startBrowsing() {
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none)
        session?.delegate = self
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        statusMessage = "Searching for Mac..."
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        isConnected = false
        statusMessage = "Disconnected"
    }

    func sendCard(name: String, cardNumber: String, rarity: String, isHolo: Bool, isReverseHolo: Bool, condition: String, imageData: Data?) {
        guard let session = session, let peer = session.connectedPeers.first else {
            statusMessage = "Not connected to Mac"
            return
        }

        var dict: [String: Any] = [
            "name": name,
            "cardNumber": cardNumber,
            "rarity": rarity,
            "isHolo": isHolo,
            "isReverseHolo": isReverseHolo,
            "condition": condition
        ]

        if let img = imageData {
            dict["imageBase64"] = img.base64EncodedString()
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: dict) else { return }
        do {
            try session.send(jsonData, toPeers: [peer], with: .reliable)
            statusMessage = "Card sent!"
        } catch {
            statusMessage = "Send failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - MCSessionDelegate

extension iOSConnectivity: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.isConnected = (state == .connected)
            self.statusMessage = state == .connected ? "📡 Connected to Mac" : "Searching for Mac..."
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let msg = String(data: data, encoding: .utf8) {
            Task { @MainActor in
                self.lastConfirmation = msg
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self.lastConfirmation == msg { self.lastConfirmation = nil }
                }
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate

extension iOSConnectivity: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            self.statusMessage = "Found Mac: \(peerID.displayName)"
            browser.invitePeer(peerID, to: self.session!, withContext: nil, timeout: 30)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.statusMessage = "Mac lost — searching..."
            self.isConnected = false
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.statusMessage = "Error: \(error.localizedDescription)"
        }
    }
}
