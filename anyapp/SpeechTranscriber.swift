//
//  SpeechTranscriber.swift
//  anyapp
//

import Speech

enum SpeechTranscriber {
    enum TranscriptionError: Error {
        case notAuthorized
        case recognizerUnavailable
        case emptyResult
    }

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    static func transcribe(url: URL) async throws -> String {
        guard await requestAuthorization() else {
            throw TranscriptionError.notAuthorized
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR")),
              recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false

            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let result, result.isFinal else { return }

                let text = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if text.isEmpty {
                    continuation.resume(throwing: TranscriptionError.emptyResult)
                } else {
                    continuation.resume(returning: text)
                }
            }
        }
    }
}
