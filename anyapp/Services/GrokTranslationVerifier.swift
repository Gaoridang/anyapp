//
//  GrokTranslationVerifier.swift
//  anyapp
//

import Foundation

struct ShadowingVerdict: Codable, Equatable, Sendable {
    let isCorrect: Bool
    let score: Int
    let feedback: String
    let suggestedTranslation: String?

    enum CodingKeys: String, CodingKey {
        case isCorrect
        case score
        case feedback
        case suggestedTranslation
    }

    init(isCorrect: Bool, score: Int, feedback: String, suggestedTranslation: String? = nil) {
        self.isCorrect = isCorrect
        self.score = score
        self.feedback = feedback
        self.suggestedTranslation = suggestedTranslation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isCorrect = try container.decode(Bool.self, forKey: .isCorrect)
        score = try container.decode(Int.self, forKey: .score)
        feedback = try container.decode(String.self, forKey: .feedback)
        let suggested = try container.decodeIfPresent(String.self, forKey: .suggestedTranslation)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        suggestedTranslation = suggested?.isEmpty == false ? suggested : nil
    }
}

struct GrokTranslationVerifier: Sendable {
    private static let endpoint = URL(string: "https://api.x.ai/v1/chat/completions")!
    private static let model = "grok-3-mini"

    private let session: URLSession
    private let apiKeyProvider: @Sendable () -> String?

    init(
        session: URLSession = .shared,
        apiKeyProvider: @escaping @Sendable () -> String? = { GrokAPIKeyStore.load() }
    ) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    func verify(korean: String, english: String) async throws -> ShadowingVerdict {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw VerifierError.missingAPIKey
        }

        let requestBody = ChatRequest(
            model: Self.model,
            temperature: 0.2,
            messages: [
                .init(
                    role: "system",
                    content: """
                    You evaluate whether an English sentence correctly translates a Korean sentence \
                    for language-learning shadowing practice. Respond with JSON only, no markdown. \
                    Use this schema exactly:
                    {"isCorrect":boolean,"score":number,"feedback":string,"suggestedTranslation":string|null}
                    score is 0-100. feedback must be in Korean and concise. \
                    suggestedTranslation is null when the English is already good enough.
                    """
                ),
                .init(
                    role: "user",
                    content: """
                    Korean: \(korean)
                    English: \(english)
                    """
                ),
            ]
        )

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw VerifierError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content else {
                throw VerifierError.invalidResponse
            }
            return try parseVerdict(from: content)
        case 401:
            throw VerifierError.unauthorized
        case 429:
            throw VerifierError.rateLimited
        default:
            throw VerifierError.httpError(httpResponse.statusCode)
        }
    }

    static func parseVerdict(from content: String) throws -> ShadowingVerdict {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let jsonString = extractJSON(from: trimmed)
        guard let data = jsonString.data(using: .utf8) else {
            throw VerifierError.invalidResponse
        }
        return try JSONDecoder().decode(ShadowingVerdict.self, from: data)
    }

    private static func extractJSON(from text: String) -> String {
        guard text.hasPrefix("```") else { return text }

        var lines = text.components(separatedBy: "\n")
        if lines.first?.hasPrefix("```") == true {
            lines.removeFirst()
        }
        if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```") == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private struct ChatRequest: Encodable {
        let model: String
        let temperature: Double
        let messages: [ChatMessage]
    }

    private struct ChatMessage: Encodable {
        let role: String
        let content: String
    }

    private struct ChatResponse: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message
        }

        struct Message: Decodable {
            let content: String
        }
    }

    enum VerifierError: LocalizedError, Equatable {
        case missingAPIKey
        case invalidResponse
        case unauthorized
        case rateLimited
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                "번역 검증을 위해 API 키를 설정해 주세요."
            case .invalidResponse:
                "번역 검증 응답을 처리할 수 없습니다."
            case .unauthorized:
                "API 키가 올바르지 않습니다."
            case .rateLimited:
                "요청이 너무 많습니다. 잠시 후 다시 시도해 주세요."
            case .httpError:
                "번역 검증에 실패했습니다."
            }
        }
    }
}
