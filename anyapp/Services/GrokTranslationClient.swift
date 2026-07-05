//
//  GrokTranslationClient.swift
//  anyapp
//

import Foundation

struct GrokTranslationClient: TranslationClient {
    private static let endpoint = URL(string: "https://api.x.ai/v1/chat/completions")!

    private let session: URLSession
    private let apiKeyProvider: @Sendable () -> String?

    init(
        session: URLSession = .shared,
        apiKeyProvider: @escaping @Sendable () -> String? = { GrokAPIKeyStore.load() }
    ) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    func translateKoreanToEnglish(_ text: String) async throws -> String {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw GrokSTTClient.STTError.missingAPIKey
        }

        let body = ChatRequest(
            model: "grok-3-mini",
            messages: [
                .init(
                    role: "system",
                    content: "Translate Korean to natural spoken English. Return only the translation without quotes."
                ),
                .init(role: "user", content: text),
            ],
            temperature: 0.2
        )

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GrokSTTClient.STTError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !content.isEmpty else {
                throw GrokSTTClient.STTError.invalidResponse
            }
            return content
        case 401:
            throw GrokSTTClient.STTError.unauthorized
        case 429:
            throw GrokSTTClient.STTError.rateLimited
        default:
            throw GrokSTTClient.STTError.httpError(httpResponse.statusCode)
        }
    }

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private struct ChatResponse: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message
        }

        struct Message: Decodable {
            let content: String?
        }
    }
}