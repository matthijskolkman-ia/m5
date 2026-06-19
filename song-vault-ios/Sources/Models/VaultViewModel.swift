import SwiftUI
import Combine

@MainActor
final class VaultViewModel: ObservableObject {
    @Published var state: VaultState = .loading
    @Published var message: String?
    @Published var messageIsError = false
    @Published var isUnlocking = false

    let api = APIService()

    var remaining: Int {
        if case .locked(let r) = state { return r }
        return 0
    }

    var totalAuthorizations: Int {
        // This gets updated after first status check
        5
    }

    nonisolated init() {}

    func load() async {
        state = .loading
        do {
            let status = try await api.fetchStatus()
            if status.unlocked {
                let catalog = try await api.fetchCatalog()
                state = .unlocked(catalog: catalog)
            } else if status.remaining == 0 {
                state = .exhausted
            } else {
                state = .locked(remaining: status.remaining)
            }
        } catch APIError.unreachable {
            state = .error("Cannot reach server. Make sure your Mac is on the same Wi-Fi and the Flask app is running.")
        } catch {
            // If can't reach server, try to show locked state anyway
            state = .locked(remaining: 5)
            message = "Could not connect to server."
            messageIsError = true
        }
    }

    func unlock(code: String) async {
        isUnlocking = true
        message = nil
        do {
            let response = try await api.unlock(code: code)
            message = response.message
            messageIsError = false

            // Fetch the unlocked catalog
            let catalog = try await api.fetchCatalog()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                state = .unlocked(catalog: catalog)
                self.message = nil
            }
        } catch let error as APIError {
            message = error.localizedDescription
            messageIsError = true
            // Update remaining if it was an unlock response
            if case .unlockFailed = error { /* remaining updated on next load */ }
        } catch {
            message = error.localizedDescription
            messageIsError = true
        }
        isUnlocking = false
    }

    func reset() {
        state = .locked(remaining: 5)
        message = nil
        messageIsError = false
    }
}
