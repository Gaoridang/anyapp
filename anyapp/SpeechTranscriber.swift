//
//  SpeechTranscriber.swift
//  anyapp
//

import Speech

/// On-device/served speech-to-text for a finished audio file.
///
/// This never touches the audio session — it operates purely on a file URL that
/// has already been written and closed by `AudioRecorder`. Crash safety around
/// the Speech framework's background callbacks is handled by `RecognitionSession`.
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

                // This handler runs on a Speech-owned background queue. All access to
                // the task/continuation must go through RecognitionSession so the task
                // reference is never mutated concurrently and the continuation resumes
                // exactly once.
                let task = recognizer.recognitionTask(with: request) { result, error in
                    if let error {
                        session.complete(.failure(error))
                        return
                    }

                    guard let result, result.isFinal else { return }

                    let text = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    session.complete(text.isEmpty
                        ? .failure(TranscriptionError.emptyResult)
                        : .success(text))
                }

                session.store(task)
            }
        } onCancel: {
            session.cancel()
        }
    }

    private nonisolated static func preferredRecognizer() -> SFSpeechRecognizer? {
        let locales = [
            Locale(identifier: "ko-KR"),
            Locale.current,
            Locale(identifier: "en-US"),
        ]

        for locale in locales {
            if let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable {
                return recognizer
            }
        }

        return SFSpeechRecognizer()
    }
}

/// Thread-safe coordinator for a single `SFSpeechRecognitionTask`.
///
/// The Speech framework invokes recognition callbacks on its own background queue
/// while the task is created/stored from the caller's context. Every access is
/// guarded by a lock so the task reference can never be mutated concurrently (a
/// data race that could over-release the task and crash), and the checked
/// continuation is guaranteed to resume exactly once.
private final class RecognitionSession: @unchecked Sendable {
    private let lock = NSLock()
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Error>?

    func begin(_ continuation: CheckedContinuation<String, Error>) {
        lock.lock()
        defer { lock.unlock() }
        self.continuation = continuation
    }

    /// Stores the task, or cancels it immediately if the session already finished
    /// (e.g. the callback fired before the task was assigned).
    func store(_ task: SFSpeechRecognitionTask) {
        lock.lock()
        let alreadyFinished = continuation == nil
        if !alreadyFinished { self.task = task }
        lock.unlock()

        if alreadyFinished { task.cancel() }
    }

    /// Called from the Speech recognition callback. Never cancel the task here —
    /// canceling a task from inside its own handler crashes.
    func complete(_ result: Result<String, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        self.task = nil
        lock.unlock()

        continuation?.resume(with: result)
    }

    /// Called from cooperative cancellation outside the recognition callback.
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
