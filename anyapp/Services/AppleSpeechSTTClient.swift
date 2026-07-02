//
//  AppleSpeechSTTClient.swift
//  anyapp
//

import Foundation
import Speech

protocol SpeechAuthorizationProviding: Sendable {
    func authorizationStatus() -> SFSpeechRecognizerAuthorizationStatus
    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus
}

protocol OnDeviceSpeechTranscribing: Sendable {
    var isOnDeviceAvailable: Bool { get }
    func transcribe(audioFileURL: URL) async throws -> String
}

struct SystemSpeechAuthorizationProvider: SpeechAuthorizationProviding {
    func authorizationStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    func requestAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}

struct SystemOnDeviceSpeechTranscriber: OnDeviceSpeechTranscribing {
    private let localeIdentifier: String

    init(localeIdentifier: String = "ko-KR") {
        self.localeIdentifier = localeIdentifier
    }

    var isOnDeviceAvailable: Bool {
        guard let recognizer = makeRecognizer() else { return false }
        return recognizer.isAvailable && recognizer.supportsOnDeviceRecognition
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        guard let recognizer = makeRecognizer() else {
            throw AppleSpeechSTTClient.STTError.onDeviceNotAvailable
        }
        guard recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            throw AppleSpeechSTTClient.STTError.onDeviceNotAvailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        let taskBox = RecognitionTaskBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                var didResume = false

                let finish: (Result<String, Error>) -> Void = { result in
                    guard !didResume else { return }
                    didResume = true
                    switch result {
                    case .success(let text):
                        continuation.resume(returning: text)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }

                taskBox.task = recognizer.recognitionTask(with: request) { result, error in
                    if let error {
                        finish(.failure(error))
                        return
                    }
                    guard let result, result.isFinal else { return }

                    let text = result.bestTranscription.formattedString
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if text.isEmpty {
                        finish(.failure(AppleSpeechSTTClient.STTError.emptyResult))
                    } else {
                        finish(.success(text))
                    }
                }

                if taskBox.task == nil {
                    finish(.failure(AppleSpeechSTTClient.STTError.recognitionFailed))
                }
            }
        } onCancel: {
            taskBox.task?.cancel()
        }
    }

    private func makeRecognizer() -> SFSpeechRecognizer? {
        SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
    }
}

private final class RecognitionTaskBox: @unchecked Sendable {
    var task: SFSpeechRecognitionTask?
}

struct AppleSpeechSTTClient: SpeechTranscriptionClient {
    private let authorizationProvider: any SpeechAuthorizationProviding
    private let transcriber: any OnDeviceSpeechTranscribing

    init(
        authorizationProvider: any SpeechAuthorizationProviding = SystemSpeechAuthorizationProvider(),
        transcriber: any OnDeviceSpeechTranscribing = SystemOnDeviceSpeechTranscriber()
    ) {
        self.authorizationProvider = authorizationProvider
        self.transcriber = transcriber
    }

    static var isOnDeviceAvailable: Bool {
        SystemOnDeviceSpeechTranscriber().isOnDeviceAvailable
    }

    func transcribe(audioFileURL: URL) async throws -> String {
        let status = await resolvedAuthorizationStatus()
        guard status == .authorized else {
            throw STTError.authorizationDenied
        }
        guard transcriber.isOnDeviceAvailable else {
            throw STTError.onDeviceNotAvailable
        }
        return try await transcriber.transcribe(audioFileURL: audioFileURL)
    }

    private func resolvedAuthorizationStatus() async -> SFSpeechRecognizerAuthorizationStatus {
        let current = authorizationProvider.authorizationStatus()
        guard current == .notDetermined else { return current }
        return await authorizationProvider.requestAuthorization()
    }

    enum STTError: LocalizedError, Equatable {
        case authorizationDenied
        case onDeviceNotAvailable
        case emptyResult
        case recognitionFailed

        var errorDescription: String? {
            switch self {
            case .authorizationDenied:
                "음성 인식 권한이 필요합니다. 설정에서 허용해 주세요."
            case .onDeviceNotAvailable:
                "기기 음성 인식을 사용할 수 없습니다. 설정 > 일반 > 키보드 > 받아쓰기에서 한국어를 설치해 주세요."
            case .emptyResult:
                "인식된 내용이 없습니다. 다시 녹음해 주세요."
            case .recognitionFailed:
                "기기 음성 인식에 실패했습니다."
            }
        }
    }
}
