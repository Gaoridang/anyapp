//
//  ShadowingSessionModel.swift
//  anyapp
//

import Foundation
import Observation
import UIKit

enum ShadowingActiveStep: Equatable {
    case korean
    case english
    case verification
}

enum ShadowingPhase: Equatable {
    case idle
    case recording(ShadowingSpeechLanguage)
    case transcribing(ShadowingSpeechLanguage)
    case verifying
    case result(ShadowingVerdict)
    case failed(String)
}

@Observable
@MainActor
final class ShadowingSessionModel {
    private(set) var phase: ShadowingPhase = .idle
    private(set) var koreanText: String?
    private(set) var englishText: String?
    private(set) var verdict: ShadowingVerdict?
    private(set) var koreanAudioURL: URL?
    private(set) var englishAudioURL: URL?
    private(set) var koreanDuration: TimeInterval?
    private(set) var englishDuration: TimeInterval?
    private(set) var recordingLanguage: ShadowingSpeechLanguage?
    private(set) var playingLanguage: ShadowingSpeechLanguage?
    private(set) var isHandlingRecordingTap = false
    private(set) var showsRecordingUI = false

    var recorder = AudioRecorder()
    var audioPlayer = AudioPlayer()

    private var pendingRecordingFileName: String?
    private var transcriptionTask: Task<Void, Never>?
    private var verificationTask: Task<Void, Never>?

    private let sttRouter: ShadowingSTTRouter
    private let verifier: GrokTranslationVerifier

    init(
        sttRouter: ShadowingSTTRouter = ShadowingSTTRouter(),
        verifier: GrokTranslationVerifier = GrokTranslationVerifier()
    ) {
        self.sttRouter = sttRouter
        self.verifier = verifier
    }

    var activeStep: ShadowingActiveStep {
        if koreanText == nil {
            return .korean
        }
        if englishText == nil {
            return .english
        }
        return .verification
    }

    var isRecording: Bool {
        recorder.isRecording
    }

    var canRecordKorean: Bool {
        activeStep == .korean && !isBusy
    }

    var canRecordEnglish: Bool {
        activeStep == .english && !isBusy
    }

    var isBusy: Bool {
        switch phase {
        case .recording, .transcribing, .verifying:
            true
        case .idle, .result, .failed:
            false
        }
    }

    var canReset: Bool {
        koreanText != nil
            || englishText != nil
            || verdict != nil
            || isRecording
            || showsRecordingUI
            || isBusy
    }

    var statusMessage: String? {
        switch phase {
        case .idle:
            nil
        case .recording(let language):
            "\(language.displayName) 녹음 중…"
        case .transcribing(let language):
            "\(language.displayName) 변환 중…"
        case .verifying:
            "번역 검증 중…"
        case .result:
            nil
        case .failed(let message):
            message
        }
    }

    func prepare() async {
        await recorder.prepare()
    }

    func toggleRecording(for language: ShadowingSpeechLanguage) {
        guard !isHandlingRecordingTap else { return }

        if recorder.isRecording {
            guard recordingLanguage == language else { return }
            triggerRecordingHaptic(isStarting: false)
            finishRecording()
            return
        }

        switch language {
        case .korean:
            guard canRecordKorean else { return }
        case .english:
            guard canRecordEnglish else { return }
        }

        startRecording(for: language)
    }

    func togglePlayback(for language: ShadowingSpeechLanguage) {
        let url: URL?
        switch language {
        case .korean:
            url = koreanAudioURL
        case .english:
            url = englishAudioURL
        }

        guard let url else { return }

        if audioPlayer.isPlaying, playingLanguage == language {
            audioPlayer.stop()
            playingLanguage = nil
            recorder.deactivatePlaybackSession()
            return
        }

        audioPlayer.stop()
        recorder.deactivatePlaybackSession()
        do {
            try recorder.activatePlaybackSession()
            try audioPlayer.play(url: url)
            playingLanguage = language
        } catch {
            playingLanguage = nil
            phase = .failed(error.localizedDescription)
        }
    }

    func retryVerification() {
        guard let koreanText, let englishText else { return }
        startVerification(korean: koreanText, english: englishText)
    }

    func resetSession() {
        transcriptionTask?.cancel()
        verificationTask?.cancel()
        transcriptionTask = nil
        verificationTask = nil

        recorder.stopRecording()
        audioPlayer.stop()
        playingLanguage = nil
        recorder.deactivatePlaybackSession()

        deleteAudio(at: koreanAudioURL)
        deleteAudio(at: englishAudioURL)

        koreanText = nil
        englishText = nil
        verdict = nil
        koreanAudioURL = nil
        englishAudioURL = nil
        koreanDuration = nil
        englishDuration = nil
        recordingLanguage = nil
        pendingRecordingFileName = nil
        showsRecordingUI = false
        isHandlingRecordingTap = false
        phase = .idle
    }

    func teardown() {
        transcriptionTask?.cancel()
        verificationTask?.cancel()
        recorder.stopRecording()
        audioPlayer.stop()
        playingLanguage = nil
        recorder.deactivatePlaybackSession()
    }

    // MARK: - Recording

    private static let recordingUITransitionDelay: Duration = .milliseconds(120)

    private func startRecording(for language: ShadowingSpeechLanguage) {
        isHandlingRecordingTap = true
        recordingLanguage = language

        Task { @MainActor in
            defer {
                if !recorder.isRecording {
                    isHandlingRecordingTap = false
                    recordingLanguage = nil
                }
            }

            if !recorder.canRecord {
                await recorder.prepare()
                guard recorder.canRecord else {
                    phase = .failed(recorder.lastErrorMessage ?? "마이크 권한이 필요합니다. 설정에서 허용해 주세요.")
                    return
                }
            }

            recorder.clearErrorState()
            if case .failed = phase {
                phase = .idle
            }
            audioPlayer.stop()
            recorder.deactivatePlaybackSession()
            await ensureTranscriptionComplete()

            let prefix = language == .korean ? "shadowing-ko" : "shadowing-en"
            let url = AudioFileStore.newRecordingURL(prefix: prefix)
            pendingRecordingFileName = url.lastPathComponent

            do {
                try recorder.startRecording(to: url)
                phase = .recording(language)
                triggerRecordingHaptic(isStarting: true)
                try await Task.sleep(for: Self.recordingUITransitionDelay)
                showsRecordingUI = true
                isHandlingRecordingTap = false
            } catch {
                pendingRecordingFileName = nil
                recordingLanguage = nil
                showsRecordingUI = false
                phase = .failed(recorder.lastErrorMessage ?? error.localizedDescription)
            }
        }
    }

    private func finishRecording() {
        guard recorder.isRecording, let language = recordingLanguage else { return }

        isHandlingRecordingTap = true
        let pending = pendingRecordingFileName
        pendingRecordingFileName = nil

        let duration = recorder.stopRecording()

        Task { @MainActor in
            defer { isHandlingRecordingTap = false }

            try? await Task.sleep(for: Self.recordingUITransitionDelay)
            showsRecordingUI = false
            recordingLanguage = nil

            guard let pending, let duration, duration > 0 else {
                phase = .failed("녹음된 오디오가 없습니다. 다시 시도해 주세요.")
                return
            }

            let url = AudioFileStore.documentsDirectory.appendingPathComponent(pending)
            switch language {
            case .korean:
                deleteAudio(at: koreanAudioURL)
                koreanAudioURL = url
                koreanDuration = duration
                koreanText = nil
            case .english:
                deleteAudio(at: englishAudioURL)
                englishAudioURL = url
                englishDuration = duration
                englishText = nil
            }

            verdict = nil
            phase = .idle
            startTranscription(for: language, fileName: pending)
        }
    }

    // MARK: - Transcription

    private func startTranscription(for language: ShadowingSpeechLanguage, fileName: String) {
        let url = AudioFileStore.documentsDirectory.appendingPathComponent(fileName)
        transcriptionTask?.cancel()
        transcriptionTask = Task { @MainActor in
            await transcribe(language: language, fileURL: url)
        }
    }

    private func ensureTranscriptionComplete() async {
        if let transcriptionTask {
            await transcriptionTask.value
        }
        if let verificationTask {
            await verificationTask.value
        }
    }

    private func transcribe(language: ShadowingSpeechLanguage, fileURL: URL) async {
        phase = .transcribing(language)

        do {
            let text = try await sttRouter.transcribe(audioFileURL: fileURL, language: language)
            guard !Task.isCancelled else { return }

            switch language {
            case .korean:
                koreanText = text
            case .english:
                englishText = text
            }

            phase = .idle

            if language == .english, let koreanText, let englishText {
                startVerification(korean: koreanText, english: englishText)
            }
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: - Verification

    private func startVerification(korean: String, english: String) {
        verificationTask?.cancel()
        verificationTask = Task { @MainActor in
            phase = .verifying
            do {
                let result = try await verifier.verify(korean: korean, english: english)
                guard !Task.isCancelled else { return }
                verdict = result
                phase = .result(result)
                UINotificationFeedbackGenerator().notificationOccurred(result.isCorrect ? .success : .warning)
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers

    private func triggerRecordingHaptic(isStarting: Bool) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = isStarting ? .medium : .light
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func deleteAudio(at url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
