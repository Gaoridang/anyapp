//
//  SpeechTranscriber.swift
//  anyapp
//

import Speech

enum SpeechTranscriber {
    enum TranscriptionError: LocalizedError {
        case notAuthorized
        case recognizerUnavailable
        case emptyResult

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                "음성 인식 권한이 필요합니다. 설정에서 허용해 주세요."
            case .recognizerUnavailable:
                "음성 인식을 사용할 수 없습니다. 네트워크 연결을 확인해 주세요."
            case .emptyResult:
                "인식된 음성이 없습니다."
            }
        }
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

        guard let recognizer = preferredRecognizer(), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false

            final class ResumeGuard: @unchecked Sendable {
                private let lock = NSLock()
                private var resumed = false

                func resumeOnce(_ action: () -> Void) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !resumed else { return }
                    resumed = true
                    action()
                }
            }

            let guard_ = ResumeGuard()
            var recognitionTask: SFSpeechRecognitionTask?

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    guard_.resumeOnce {
                        recognitionTask?.cancel()
                        recognitionTask = nil
                        continuation.resume(throwing: error)
                    }
                    return
                }

                guard let result, result.isFinal else { return }

                let text = result.bestTranscription.formattedString
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                guard_.resumeOnce {
                    recognitionTask = nil
                    if text.isEmpty {
                        continuation.resume(throwing: TranscriptionError.emptyResult)
                    } else {
                        continuation.resume(returning: text)
                    }
                }
            }
        }
    }

    private static func preferredRecognizer() -> SFSpeechRecognizer? {
        let preferredLocales = [
            Locale(identifier: "ko-KR"),
            Locale.current,
            Locale(identifier: "en-US"),
        ]

        for locale in preferredLocales {
            if let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable {
                return recognizer
            }
        }

        return SFSpeechRecognizer()
    }
}
