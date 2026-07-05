//
//  SemanticComparator.swift
//  anyapp
//

import Foundation

struct SemanticAnalysisResult: Equatable, Sendable {
    let semanticScore: Int
    let summary: String
    let synonyms: [SynonymPair]
    let issues: [SemanticIssue]

    struct SynonymPair: Equatable, Sendable {
        let expected: String
        let spoken: String
        let acceptable: Bool
        let feedback: String?
    }

    struct SemanticIssue: Equatable, Sendable {
        let type: String
        let expected: String?
        let spoken: String?
        let feedback: String
    }
}

struct SemanticComparator {
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

    func analyze(
        korean: String,
        expectedEnglish: String,
        spokenEnglish: String
    ) async throws -> SemanticAnalysisResult {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw GrokSTTClient.STTError.missingAPIKey
        }

        let prompt = """
        Compare the learner's spoken English against the expected English translation of a Korean sentence.

        Korean source:
        \(korean)

        Expected English:
        \(expectedEnglish)

        Learner's spoken English:
        \(spokenEnglish)

        Return JSON only with this schema:
        {
          "semantic_score": 0-100 integer,
          "summary": "Korean one-sentence encouragement or guidance",
          "synonyms": [
            {"expected": "word", "spoken": "word", "acceptable": true, "feedback": "Korean note or null"}
          ],
          "issues": [
            {"type": "mismatch|missing|extra|grammar", "expected": "word or null", "spoken": "word or null", "feedback": "Korean note"}
          ]
        }
        """

        let body = ChatRequest(
            model: "grok-3-mini",
            messages: [
                .init(role: "system", content: "You evaluate English speaking practice. Respond with valid JSON only."),
                .init(role: "user", content: prompt),
            ],
            temperature: 0.1
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
            guard let content = decoded.choices.first?.message.content else {
                throw GrokSTTClient.STTError.invalidResponse
            }
            return try parseAnalysis(from: content)
        case 401:
            throw GrokSTTClient.STTError.unauthorized
        case 429:
            throw GrokSTTClient.STTError.rateLimited
        default:
            throw GrokSTTClient.STTError.httpError(httpResponse.statusCode)
        }
    }

    private func parseAnalysis(from content: String) throws -> SemanticAnalysisResult {
        let trimmed = content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = trimmed.data(using: .utf8) else {
            throw GrokSTTClient.STTError.invalidResponse
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return SemanticAnalysisResult(
            semanticScore: min(max(payload.semanticScore, 0), 100),
            summary: payload.summary,
            synonyms: payload.synonyms.map {
                SemanticAnalysisResult.SynonymPair(
                    expected: $0.expected,
                    spoken: $0.spoken,
                    acceptable: $0.acceptable,
                    feedback: $0.feedback
                )
            },
            issues: payload.issues.map {
                SemanticAnalysisResult.SemanticIssue(
                    type: $0.type,
                    expected: $0.expected,
                    spoken: $0.spoken,
                    feedback: $0.feedback
                )
            }
        )
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

    private struct Payload: Decodable {
        let semanticScore: Int
        let summary: String
        let synonyms: [SynonymPayload]
        let issues: [IssuePayload]

        enum CodingKeys: String, CodingKey {
            case semanticScore = "semantic_score"
            case summary
            case synonyms
            case issues
        }
    }

    private struct SynonymPayload: Decodable {
        let expected: String
        let spoken: String
        let acceptable: Bool
        let feedback: String?
    }

    private struct IssuePayload: Decodable {
        let type: String
        let expected: String?
        let spoken: String?
        let feedback: String
    }
}