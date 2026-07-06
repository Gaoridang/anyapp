//
//  GrokSTTClientTests.swift
//  anyappTests
//

import Foundation
import Testing
@testable import anyapp

struct GrokSTTClientTests {
    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    @Test func transcribeSuccessParsesText() async throws {
        MockURLProtocol.requestHandler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.absoluteString == "https://api.x.ai/v1/stt")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
            let contentType = request.value(forHTTPHeaderField: "Content-Type") ?? ""
            #expect(contentType.contains("multipart/form-data"))

            let body = request.httpBody ?? Data()
            let bodyString = String(decoding: body, as: UTF8.self)
            #expect(bodyString.contains("name=\"format\""))
            #expect(bodyString.contains("name=\"language\""))
            #expect(bodyString.contains("name=\"file\""))
            #expect(bodyString.contains("audio/mp4"))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = #"{"text":"안녕하세요","duration":1.2}"#.data(using: .utf8)!
            return (response, data)
        }

        let client = GrokSTTClient(
            session: makeSession(),
            apiKeyProvider: { "test-key" }
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sample.m4a")
        try Data([0x00, 0x01]).write(to: url)

        let text = try await client.transcribe(audioFileURL: url)
        #expect(text == "안녕하세요")
    }

    @Test func transcribeMissingAPIKeyThrows() async {
        let client = GrokSTTClient(
            session: makeSession(),
            apiKeyProvider: { nil }
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("empty.m4a")

        await #expect(throws: GrokSTTClient.STTError.missingAPIKey) {
            try await client.transcribe(audioFileURL: url)
        }
    }

    @Test func transcribeEnglishUsesLanguageField() async throws {
        MockURLProtocol.requestHandler = { request in
            let body = request.httpBody ?? Data()
            let bodyString = String(decoding: body, as: UTF8.self)
            #expect(bodyString.contains("name=\"language\""))
            #expect(bodyString.contains("en"))

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = #"{"text":"Hello"}"#.data(using: .utf8)!
            return (response, data)
        }

        let client = GrokSTTClient(
            session: makeSession(),
            language: "en",
            apiKeyProvider: { "test-key" }
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("english.m4a")
        try Data([0x00]).write(to: url)

        let text = try await client.transcribe(audioFileURL: url)
        #expect(text == "Hello")
    }

    @Test func transcribeUnauthorizedThrows() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let client = GrokSTTClient(
            session: makeSession(),
            apiKeyProvider: { "bad-key" }
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("auth.m4a")
        try? Data().write(to: url)

        await #expect(throws: GrokSTTClient.STTError.unauthorized) {
            try await client.transcribe(audioFileURL: url)
        }
    }
}
