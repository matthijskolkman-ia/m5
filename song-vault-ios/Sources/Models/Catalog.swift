import Foundation

// MARK: - Catalog (matches Flask JSON)

struct Catalog: Codable, Equatable {
    let catalogName: String
    let owner: String
    let totalTracks: Int
    let maxAuthorizations: Int
    let authorizationsUsed: Int
    let tracks: [Track]

    enum CodingKeys: String, CodingKey {
        case catalogName = "catalog_name"
        case owner
        case totalTracks = "total_tracks"
        case maxAuthorizations = "max_authorizations"
        case authorizationsUsed = "authorizations_used"
        case tracks
    }

    var remaining: Int { maxAuthorizations - authorizationsUsed }
    var isExhausted: Bool { remaining <= 0 }
}

struct Track: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let artist: String
    let album: String
    let year: Int
    let genre: String
    let duration: String
    let bpm: Int
    let key: String
}

// MARK: - Unlock

struct UnlockRequest: Codable {
    let code: String
}

struct UnlockResponse: Codable {
    let success: Bool
    let message: String
    let remaining: Int
}

struct StatusResponse: Codable {
    let unlocked: Bool
    let remaining: Int
    let total: Int
}

// MARK: - App State

enum VaultState: Equatable {
    case locked(remaining: Int)
    case unlocked(catalog: Catalog)
    case exhausted
    case loading
    case error(String)
}
