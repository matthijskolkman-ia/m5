import Foundation

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

struct ChatChoice: Codable {
    let message: ChatMessage
}

struct ChatResponse: Codable {
    let choices: [ChatChoice]?
    let error: ChatError?
}

struct ChatError: Codable {
    let message: String
}

enum APIError: LocalizedError {
    case badURL, noData, rateLimited, badKey, serverError(Int), unknown(String)

    var errorDescription: String? {
        switch self {
        case .badURL: return "Bad URL"
        case .noData: return "No data from server"
        case .rateLimited: return "Rate limited — wait a moment"
        case .badKey: return "Invalid API key"
        case .serverError(let code): return "Server error (HTTP \(code))"
        case .unknown(let msg): return msg
        }
    }
}

class DeepSeekService {
    var apiKey: String
    var model: String

    init(apiKey: String, model: String = "deepseek-chat") {
        self.apiKey = apiKey
        self.model = model
    }

    func send(messages: [ChatMessage], systemPrompt: String) async throws -> String {
        guard let url = URL(string: "https://api.deepseek.com/v1/chat/completions") else {
            throw APIError.badURL
        }

        var allMessages = [ChatMessage(role: "system", content: systemPrompt)]
        allMessages.append(contentsOf: messages)

        let body = ChatRequest(model: model, messages: allMessages, temperature: 0.7, max_tokens: 4096)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(body)
        req.timeoutInterval = 120

        let (data, resp) = try await URLSession.shared.data(for: req)

        if let httpResp = resp as? HTTPURLResponse {
            switch httpResp.statusCode {
            case 200: break
            case 401: throw APIError.badKey
            case 429: throw APIError.rateLimited
            default: throw APIError.serverError(httpResp.statusCode)
            }
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        if let err = decoded.error {
            throw APIError.unknown(err.message)
        }
        guard let content = decoded.choices?.first?.message.content else {
            throw APIError.noData
        }
        return content
    }
}
