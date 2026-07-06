//
//  GrokTranslationVerifierTests.swift
//  anyappTests
//

import Foundation
import Testing
@testable import anyapp

struct GrokTranslationVerifierTests {
    @Test func parseVerdictFromPlainJSON() throws {
        let json = """
        {"isCorrect":true,"score":92,"feedback":"의미가 정확합니다.","suggestedTranslation":null}
        """
        let verdict = try GrokTranslationVerifier.parseVerdict(from: json)
        #expect(verdict.isCorrect)
        #expect(verdict.score == 92)
        #expect(verdict.feedback == "의미가 정확합니다.")
        #expect(verdict.suggestedTranslation == nil)
    }

    @Test func parseVerdictStripsMarkdownFence() throws {
        let json = """
        ```json
        {"isCorrect":false,"score":61,"feedback":"뉘앙스가 조금 달라요.","suggestedTranslation":"It is a nice day today."}
        ```
        """
        let verdict = try GrokTranslationVerifier.parseVerdict(from: json)
        #expect(!verdict.isCorrect)
        #expect(verdict.score == 61)
        #expect(verdict.suggestedTranslation == "It is a nice day today.")
    }

    @Test func verifySuccessUsesChatCompletions() async throws {
        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://api.x.ai/v1/chat/completions")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")

            let body = request.httpBody ?? Data()
            let bodyString = String(decoding: body, as: UTF8.self)
            #expect(bodyString.contains("grok-3-mini"))
            #expect(bodyString.contains("Korean:"))
            #expect(bodyString.contains("English:"))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let payload = """
            {"choices":[{"message":{"content":"{\\"isCorrect\\":true,\\"score\\":95,\\"feedback\\":\\"좋아요\\",\\"suggestedTranslation\\":null}"}}]}
            """
            return (response, Data(payload.utf8))
        }

        let verifier = GrokTranslationVerifier(
            session: makeSession(),
            apiKeyProvider: { "test-key" }
        )

        let verdict = try await verifier.verify(korean: "오늘 날씨가 좋아요", english: "The weather is nice today")
        #expect(verdict.isCorrect)
        #expect(verdict.score == 95)
    }

    @Test func verifyMissingAPIKeyThrows() async {
        let verifier = GrokTranslationVerifier(
            session: makeSession(),
            apiKeyProvider: { nil }
        )

        await #expect(throws: GrokTranslationVerifier.VerifierError.missingAPIKey) {
            try await verifier.verify(korean: "안녕", english: "Hello")
        }
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }
}
