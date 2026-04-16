import Foundation

enum LLMClientError: Error, LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "The API base URL is invalid."
        case .invalidResponse:
            "The API response is invalid."
        case .emptyResponse:
            "The API returned an empty response."
        }
    }
}

final class LLMClient {
    private let configuration: LLMConfiguration

    init(configuration: LLMConfiguration) {
        self.configuration = configuration
    }

    func refine(_ text: String) async throws -> String {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return text
        }

        var request = try makeURLRequest()
        request.httpBody = try JSONEncoder().encode(ChatRequest(
            model: configuration.model.trimmingCharacters(in: .whitespacesAndNewlines),
            messages: [
                ChatMessage(role: "system", content: Self.systemPrompt),
                ChatMessage(role: "user", content: trimmedText)
            ],
            temperature: 0
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw LLMClientError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw LLMClientError.emptyResponse
        }

        let refined = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return refined.isEmpty ? text : refined
    }

    func test() async throws -> String {
        try await refine("今天我们用配森解析杰森。")
    }

    private func makeURLRequest() throws -> URLRequest {
        let base = configuration.apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/chat/completions") else {
            throw LLMClientError.invalidBaseURL
        }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private static let systemPrompt = """
You correct speech recognition output conservatively.

Rules:
- Only fix obvious speech recognition mistakes.
- Fix clear Chinese homophone mistakes when the intended words are obvious.
- Fix English technical terms that were phonetically converted to Chinese, such as 配森 -> Python and 杰森 -> JSON.
- Preserve language, wording, punctuation, order, and all content that appears correct.
- Never rewrite, polish, summarize, expand, translate, or remove content.
- If the input already looks correct, return it exactly as-is.
- Return only the corrected text, with no explanation.
"""
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

private struct ChatMessage: Codable {
    let role: String
    let content: String
}

private struct ChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ChatMessage
    }
}
