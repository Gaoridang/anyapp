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

    nonisolated static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    nonisolated static func transcribe(url: URL) async throws -> String {
        guard await requestAuthorization() else {
            throw TranscriptionError.notAuthorized
        }

        guard let recognizer = preferredRecognizer(), recognizer.isAvailable else {
            throw TranscriptionError.recognizerUnavailable
        }

        let session = RecognitionSession()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                session.begin(continuation)

                let request = SFSpeechURLRecognitionRequest(url: url)
                request.shouldReportPartialResults = false

                // The completion handler is invoked on a background queue owned by the
                // Speech framework. All access to the recognition task and the
                // continuation must be funneled through RecognitionSession so that the
                // task reference is never mutated concurrently from two threads.
                let task = recognizer.recognitionTask(with: request) { result, error in
                    if let error {
                        session.complete(.failure(error))
                        return
                    }

                    guard let result, result.isFinal else { return }

                    let text = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    session.complete(text.isEmpty ? .failure(TranscriptionError.emptyResult) : .success(text))
                }

                session.store(task)
            }
        } onCancel: {
            session.cancel()
        }
    }

    private nonisolated static func preferredRecognizer() -> SFSpeechRecognizer? {
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

/// Thread-safe coordinator for a single `SFSpeechRecognitionTask`.
///
/// The Speech framework invokes recognition callbacks on its own background queue,
/// while the task is created and stored from the caller's context. Guarding every
/// access with a lock prevents the concurrent mutation of the task reference (a data
/// race that could over-release the task and crash), and guarantees the checked
/// continuation is resumed exactly once.
private final class RecognitionSession: @unchecked Sendable {
    private let lock = NSLock()
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Error>?

    func begin(_ continuation: CheckedContinuation<String, Error>) {
        lock.lock()
        defer { lock.unlock() }
        self.continuation = continuation
    }

    /// Stores the recognition task, or cancels it immediately if the session has
    /// already finished (e.g. the callback fired before the task was assigned).
    func store(_ task: SFSpeechRecognitionTask) {
        lock.lock()
        defer { lock.unlock() }
        if continuation == nil {
            task.cancel()
        } else {
            self.task = task
        }
    }

    /// Called from the Speech framework's recognition callback. Never cancel the
    /// task here — canceling the task from inside its own handler crashes.
    func complete(_ result: Result<String, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        self.task = nil
        lock.unlock()

        continuation?.resume(with: result)
    }

    /// Called from task cancellation outside the recognition callback.
    func cancel() {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        let task = self.task
        self.task = nil
        lock.unlock()

        task?.cancel()
        continuation?.resume(throwing: CancellationError())
    }
}
