//
//  SpeechTranscriptionClient.swift
//  anyapp
//

import Foundation

protocol SpeechTranscriptionClient: Sendable {
    func transcribe(audioFileURL: URL) async throws -> String
}
