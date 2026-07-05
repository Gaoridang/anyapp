//
//  SpeakingPracticeView.swift
//  anyapp
//

import SwiftUI

struct SpeakingPracticeView: View {
    @State private var session = SpeakingPracticeSession()
    @State private var recorder = AudioRecorder()
    @State private var audioPlayer = AudioPlayer()

    @State private var pendingRecordingURL: URL?
    @State private var activeRecordStep: SpeakingPracticeSession.Step?
    @State private var isHandlingRecordingTap = false

    private static let recordingUITransitionDelay: Duration = .milliseconds(120)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PracticeStepIndicator(step: session.step)

                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("말하기 연습")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) {
                if let errorMessage = session.errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .padding(.bottom, 12)
                }
            }
            .task {
                await recorder.prepare()
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch session.step {
        case .korean:
            PracticeRecordStepView(
                title: "한국어로 말해 보세요",
                subtitle: "평소 말하듯 자연스럽게 녹음해 주세요.",
                referenceTitle: nil,
                referenceText: nil,
                phase: recorder.isRecording && activeRecordStep == .korean ? .recording : session.koreanPhase,
                draftText: $session.koreanTextDraft,
                elapsedTime: recorder.elapsedTime,
                isRecorderReady: recorder.isPrepared,
                isInteractionEnabled: !isHandlingRecordingTap && session.englishPhase != .transcribing,
                providerLabel: session.aiStatusLabel,
                onToggleRecording: { toggleRecording(for: .korean) },
                onRetake: {
                    session.resetForKoreanRetake()
                    activeRecordStep = nil
                },
                onContinue: session.advanceFromKorean,
                continueTitle: "다음"
            )
        case .english:
            PracticeRecordStepView(
                title: "영어로 말해 보세요",
                subtitle: "위 한국어 문장을 영어로 말해 보세요.",
                referenceTitle: "한국어 원문",
                referenceText: session.koreanText,
                phase: recorder.isRecording && activeRecordStep == .english ? .recording : session.englishPhase,
                draftText: $session.englishTextDraft,
                elapsedTime: recorder.elapsedTime,
                isRecorderReady: recorder.isPrepared,
                isInteractionEnabled: !isHandlingRecordingTap,
                providerLabel: session.aiStatusLabel,
                onToggleRecording: { toggleRecording(for: .english) },
                onRetake: {
                    session.resetForEnglishRetake()
                    activeRecordStep = nil
                },
                onContinue: {
                    Task { await session.runAnalysis() }
                },
                continueTitle: "비교하기"
            )
        case .result:
            resultContent
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if session.analysisPhase.isAnalyzing {
            AnalysisProgressView(phase: session.analysisPhase)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if case .failed(let message) = session.analysisPhase {
            ContentUnavailableView(
                "비교에 실패했어요",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("처음부터 다시", action: session.resetAll)
                }
            }
        } else if let result = session.comparisonResult {
            ComparisonResultView(
                result: result,
                showsSemanticFallbackNotice: session.showsSemanticFallbackNotice,
                koreanAudioURL: session.koreanAudioURL,
                englishAudioURL: session.englishAudioURL,
                onReplayKorean: { playAudio(at: session.koreanAudioURL) },
                onReplayEnglish: { playAudio(at: session.englishAudioURL) },
                onRestart: session.resetAll,
                onFinish: session.resetAll
            )
        } else {
            ProgressView("결과를 불러오는 중…")
        }
    }

    private func toggleRecording(for step: SpeakingPracticeSession.Step) {
        guard !isHandlingRecordingTap else { return }

        if recorder.isRecording {
            PracticeRecordButton.triggerHaptic(isStarting: false)
            finishRecording(for: step)
            return
        }

        startRecording(for: step)
    }

    private func startRecording(for step: SpeakingPracticeSession.Step) {
        isHandlingRecordingTap = true
        activeRecordStep = step
        setRecordPhase(.idle, for: step)

        Task { @MainActor in
            defer {
                if !recorder.isRecording {
                    isHandlingRecordingTap = false
                }
            }

            if !recorder.canRecord {
                await recorder.prepare()
                guard recorder.canRecord else {
                    session.errorMessage = recorder.lastErrorMessage
                        ?? "마이크 권한이 필요합니다. 설정에서 허용해 주세요."
                    activeRecordStep = nil
                    return
                }
            }

            session.errorMessage = nil
            recorder.clearErrorState()
            audioPlayer.stop()
            recorder.deactivatePlaybackSession()

            let url = AudioFileStore.newRecordingURL()
            pendingRecordingURL = url

            do {
                try recorder.startRecording(to: url)
                setRecordPhase(.recording, for: step)
                PracticeRecordButton.triggerHaptic(isStarting: true)
                try await Task.sleep(for: Self.recordingUITransitionDelay)
                isHandlingRecordingTap = false
            } catch {
                pendingRecordingURL = nil
                try? FileManager.default.removeItem(at: url)
                setRecordPhase(.idle, for: step)
                activeRecordStep = nil
                session.errorMessage = recorder.lastErrorMessage
                    ?? (error as? LocalizedError)?.errorDescription
                    ?? "녹음을 시작할 수 없습니다."
            }
        }
    }

    private func finishRecording(for step: SpeakingPracticeSession.Step) {
        guard recorder.isRecording else { return }

        isHandlingRecordingTap = true
        let pendingURL = pendingRecordingURL
        pendingRecordingURL = nil
        let duration = recorder.stopRecording()
        activeRecordStep = nil

        Task { @MainActor in
            defer { isHandlingRecordingTap = false }
            try? await Task.sleep(for: Self.recordingUITransitionDelay)
            setRecordPhase(.idle, for: step)

            guard let pendingURL, let duration, duration > 0 else {
                if let pendingURL {
                    try? FileManager.default.removeItem(at: pendingURL)
                }
                session.errorMessage = "녹음된 오디오가 없습니다. 다시 시도해 주세요."
                return
            }

            await session.handleRecordingFinished(url: pendingURL, duration: duration, for: step)
        }
    }

    private func setRecordPhase(_ phase: SpeakingPracticeSession.RecordPhase, for step: SpeakingPracticeSession.Step) {
        switch step {
        case .korean:
            session.koreanPhase = phase
        case .english:
            session.englishPhase = phase
        case .result:
            break
        }
    }

    private func playAudio(at url: URL?) {
        guard let url else { return }

        if audioPlayer.isPlaying {
            audioPlayer.stop()
            recorder.deactivatePlaybackSession()
            return
        }

        do {
            try recorder.activatePlaybackSession()
            try audioPlayer.play(url: url)
        } catch {
            audioPlayer.stop()
            recorder.deactivatePlaybackSession()
        }
    }
}

#Preview {
    SpeakingPracticeView()
}