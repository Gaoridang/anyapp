//
//  SpeechTranscriptionClient.swift
//  anyapp
//

import Foundation

protocol SpeechTranscriptionClient: Sendable {
    func transcribe(audioFileURL: URL, locale: Locale) async throws -> String
}

extension SpeechTranscriptionClient {
    func transcribe(audioFileURL: URL) async throws -> String {
        try await transcribe(audioFileURL: audioFileURL, locale: Locale(identifier: "ko-KR"))
    }
}
