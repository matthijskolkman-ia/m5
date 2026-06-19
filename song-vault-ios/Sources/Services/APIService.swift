import Foundation

/// Talks to the Song Vault Flask server on your Mac.
/// Change `serverHost` to your Mac's local IP for iPhone testing.
final class APIService: ObservableObject {

    // MARK: - Configuration

    /// Your Mac's local IP address (find in System Settings → Network → Wi-Fi)
    /// For simulator, use "127.0.0.1". For real iPhone, use e.g. "192.168.1.5"
    #if targetEnvironment(simulator)
    static let serverHost = "127.0.0.1"
    #else
    static let serverHost = "192.168.1.253"  // ← Your M5 Mac's local IP
    #endif

    static let serverPort = 5050
    static var baseURL: String { "http://\(serverHost):\(serverPort)" }

    // MARK: - Endpoints

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        return URLSession(configuration: config)
    }()

    /// Fetch catalog metadata (only succeeds if unlocked)
    func fetchCatalog() async throws -> Catalog {
        let url = URL(string: "\(Self.baseURL)/api/catalog")!
        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if http.statusCode == 403 {
            throw APIError.notAuthorized
        }

        guard http.statusCode == 200 else {
            throw APIError.serverError(http.statusCode)
        }

        return try JSONDecoder().decode(Catalog.self, from: data)
    }

    /// Submit an unlock code
    func unlock(code: String) async throws -> UnlockResponse {
        let url = URL(string: "\(Self.baseURL)/api/unlock")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(UnlockRequest(code: code))

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(UnlockResponse.self, from: data)

        if !decoded.success {
            throw APIError.unlockFailed(decoded.message)
        }

        return decoded
    }

    /// Check vault status (locked/unlocked, remaining)
    func fetchStatus() async throws -> StatusResponse {
        let url = URL(string: "\(Self.baseURL)/api/status")!
        let (data, _) = try await session.data(from: url)
        return try JSONDecoder().decode(StatusResponse.self, from: data)
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidResponse
    case notAuthorized
    case serverError(Int)
    case unlockFailed(String)
    case unreachable

    var errorDescription: String? {
        switch self {
        case .invalidResponse:    return "Invalid response from server."
        case .notAuthorized:      return "Catalog is locked."
        case .serverError(let c): return "Server error (HTTP \(c))."
        case .unlockFailed(let m): return m
        case .unreachable:        return "Cannot reach the server. Is your Mac awake and on the same Wi-Fi?"
        }
    }
}
