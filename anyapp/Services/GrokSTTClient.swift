//
//  GrokSTTClient.swift
//  anyapp
//

import Foundation

struct GrokSTTClient: SpeechTranscriptionClient {
    private static let endpoint = URL(string: "https://api.x.ai/v1/stt")!

    private let session: URLSession
    private let apiKeyProvider: @Sendable () -> String?

    init(
        session: URLSession = .shared,
        apiKeyProvider: @escaping @Sendable () -> String? = { GrokAPIKeyStore.load() }
    ) {
        self.session = session
        self.apiKeyProvider = apiKeyProvider
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        guard let apiKey = apiKeyProvider(), !apiKey.isEmpty else {
            throw STTError.missingAPIKey
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        let body = try buildMultipartBody(for: audioFileURL, boundary: boundary)

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoded = try JSONDecoder().decode(STTResponse.self, from: data)
            return decoded.text
        case 401:
            throw STTError.unauthorized
        case 429:
            throw STTError.rateLimited
        default:
            throw STTError.httpError(httpResponse.statusCode)
        }
    }

    private func buildMultipartBody(for audioFileURL: URL, boundary: String) throws -> Data {
        var body = Data()
        let lineBreak = "\r\n"

        func appendField(name: String, value: String) {
            body.append(Data("--\(boundary)\(lineBreak)".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"\(name)\"\(lineBreak)\(lineBreak)".utf8))
            body.append(Data("\(value)\(lineBreak)".utf8))
        }

        appendField(name: "format", value: "true")
        appendField(name: "language", value: "ko")

        let audioData = try Data(contentsOf: audioFileURL)
        body.append(Data("--\(boundary)\(lineBreak)".utf8))
        body.append(Data(
            "Content-Disposition: form-data; name=\"file\"; filename=\"\(audioFileURL.lastPathComponent)\"\(lineBreak)"
                .utf8
        ))
        body.append(Data("Content-Type: audio/mp4\(lineBreak)\(lineBreak)".utf8))
        body.append(audioData)
        body.append(Data("\(lineBreak)--\(boundary)--\(lineBreak)".utf8))
        return body
    }

    private struct STTResponse: Decodable {
        let text: String
    }

    enum STTError: LocalizedError, Equatable {
        case missingAPIKey
        case invalidResponse
        case unauthorized
        case rateLimited
        case httpError(Int)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                "API 키를 설정해 주세요."
            case .invalidResponse:
                "음성 변환 응답을 처리할 수 없습니다."
            case .unauthorized:
                "API 키가 올바르지 않습니다."
            case .rateLimited:
                "요청이 너무 많습니다. 잠시 후 다시 시도해 주세요."
            case .httpError:
                "음성 변환에 실패했습니다."
            }
        }
    }
}
