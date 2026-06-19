import Foundation

final class DeepSeekService {
    static let shared = DeepSeekService()

    private let baseURL = "https://api.deepseek.com/v1"
    private let session = URLSession.shared

    struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    struct ChatRequest: Codable {
        let model: String
        let messages: [ChatMessage]
        let temperature: Double
        let max_tokens: Int
    }

    struct ChatResponse: Codable {
        struct Choice: Codable {
            struct Msg: Codable { let role: String; let content: String }
            let message: Msg
        }
        let choices: [Choice]
    }

    func send(messages: [ChatMessage], apiKey: String, model: String = "deepseek-chat") async throws -> String {
        guard !apiKey.isEmpty else { throw APIError.noAPIKey }
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw APIError.invalidURL
        }

        let body = ChatRequest(model: model, messages: messages, temperature: 0.7, max_tokens: 4096)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)

        let (data, resp) = try await session.data(for: req)

        guard let http = resp as? HTTPURLResponse else {
            throw APIError.httpError(0, "No HTTP response")
        }

        guard (200...299).contains(http.statusCode) else {
            let rawBody = String(data: data, encoding: .utf8) ?? ""
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any] {
                let msg = error["message"] as? String ?? rawBody
                throw APIError.httpError(http.statusCode, msg)
            }
            throw APIError.httpError(http.statusCode, rawBody)
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        return decoded.choices.first?.message.content ?? ""
    }
}

enum APIError: LocalizedError {
    case noAPIKey
    case invalidURL
    case httpError(Int, String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:   return "API key not set"
        case .invalidURL: return "Invalid API URL"
        case .httpError(let code, let msg):
            switch code {
            case 429: return "Rate limited — slow down (\(msg))"
            case 401: return "Invalid API key"
            case 402: return "Insufficient balance"
            case 503: return "DeepSeek overloaded — retry soon"
            default:  return "[\(code)] \(msg)"
            }
        }
    }
}
