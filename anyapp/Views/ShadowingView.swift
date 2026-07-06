//
//  ShadowingView.swift
//  anyapp
//

import SwiftUI

struct ShadowingView: View {
    @Binding var selectedTab: RootTab
    @State private var session = ShadowingSessionModel()
    @State private var showAPIKeySettings = false
    @State private var shakeVerification = false

    var body: some View {
        NavigationStack {
            scrollContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.automatic, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        TopSegmentNavigator(selection: $selectedTab, style: .navigationBar)
                    }
                }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection

                ShadowingStepCard(
                    stepNumber: 1,
                    title: "한국어",
                    subtitle: "먼저 한국어 문장을 말해 보세요",
                    icon: "character.bubble",
                    isActive: session.activeStep == .korean,
                    isCompleted: session.koreanText != nil,
                    transcribedText: session.koreanText,
                    duration: session.koreanDuration,
                    isRecording: session.isRecording && session.recordingLanguage == .korean,
                    showsRecordingUI: session.showsRecordingUI && session.recordingLanguage == .korean,
                    elapsedTime: session.recorder.elapsedTime,
                    isPlaying: session.audioPlayer.isPlaying && session.playingLanguage == .korean,
                    canInteract: session.canRecordKorean || session.koreanText != nil,
                    canRecord: session.canRecordKorean,
                    isRecorderReady: session.recorder.isPrepared && session.recorder.canRecord,
                    onToggleRecording: { session.toggleRecording(for: .korean) },
                    onTogglePlayback: { session.togglePlayback(for: .korean) }
                )
                .accessibilityIdentifier("koreanStepCard")

                ShadowingStepCard(
                    stepNumber: 2,
                    title: "English",
                    subtitle: "같은 의미로 영어로 말해 보세요",
                    icon: "globe",
                    isActive: session.activeStep == .english,
                    isCompleted: session.englishText != nil,
                    transcribedText: session.englishText,
                    duration: session.englishDuration,
                    isRecording: session.isRecording && session.recordingLanguage == .english,
                    showsRecordingUI: session.showsRecordingUI && session.recordingLanguage == .english,
                    elapsedTime: session.recorder.elapsedTime,
                    isPlaying: session.audioPlayer.isPlaying && session.playingLanguage == .english,
                    canInteract: session.canRecordEnglish || session.englishText != nil,
                    canRecord: session.canRecordEnglish,
                    isRecorderReady: session.recorder.isPrepared && session.recorder.canRecord,
                    onToggleRecording: { session.toggleRecording(for: .english) },
                    onTogglePlayback: { session.togglePlayback(for: .english) }
                )
                .accessibilityIdentifier("englishStepCard")

                verificationCard

                if session.koreanText != nil || session.englishText != nil {
                    Button(action: session.resetSession) {
                        Label("다시 하기", systemImage: "arrow.counterclockwise")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("resetShadowingButton")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .safeAreaPadding(.bottom)
        .background(Color(.systemGroupedBackground))
        .task {
            await session.prepare()
        }
        .onDisappear(perform: session.teardown)
        .sheet(isPresented: $showAPIKeySettings) {
            APIKeySettingsView()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: session.activeStep)
        .animation(.easeInOut(duration: 0.25), value: session.phase)
        .animation(.easeInOut(duration: 0.25), value: session.showsRecordingUI)
        .onChange(of: session.phase) { _, newPhase in
            if case .result(let verdict) = newPhase, !verdict.isCorrect {
                triggerShake()
            }
        }
        .overlay(alignment: .top) {
            if case .failed(let message) = session.phase,
               session.activeStep != .verification {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.92), in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("영어 쉐도잉")
                .font(.title2.weight(.bold))
            Text("한국어로 말하고, 영어로 따라 말한 뒤 번역이 맞는지 확인해 보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var verificationCard: some View {
        let isActive = session.activeStep == .verification
        let isVerifying: Bool = {
            if case .verifying = session.phase { return true }
            return false
        }()

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                stepBadge(number: 3, isActive: isActive, isCompleted: session.verdict != nil)

                VStack(alignment: .leading, spacing: 2) {
                    Text("번역 검증")
                        .font(.headline)
                    Text("Grok이 의미가 맞는지 확인합니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if isVerifying {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Group {
                if let verdict = session.verdict {
                    verificationResult(verdict)
                } else if isVerifying {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("번역 검증 중…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else if session.englishText != nil {
                    Text("영어 녹음이 끝나면 자동으로 검증합니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("한국어와 영어 녹음을 모두 완료하면 검증이 시작됩니다.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.leading, 38)

            if case .failed(let message) = session.phase {
                HStack(spacing: 8) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)

                    if message.contains("API 키") {
                        Button("설정") {
                            showAPIKeySettings = true
                        }
                        .font(.caption.weight(.semibold))
                    } else if session.koreanText != nil, session.englishText != nil {
                        Button("다시 시도") {
                            session.retryVerification()
                        }
                        .font(.caption.weight(.semibold))
                    }
                }
                .padding(.leading, 38)
            }
        }
        .padding(16)
        .background(cardBackground(isActive: isActive, isCompleted: session.verdict?.isCorrect == true))
        .overlay(cardBorder(isActive: isActive, highlightColor: session.verdict?.isCorrect == true ? .green : .accentColor))
        .opacity(isActive || session.verdict != nil || isVerifying ? 1 : 0.5)
        .scaleEffect(isActive ? 1.02 : 1)
        .modifier(ShakeEffect(animatableData: shakeVerification ? 1 : 0))
        .accessibilityIdentifier("verificationStepCard")
    }

    @ViewBuilder
    private func verificationResult(_ verdict: ShadowingVerdict) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: verdict.isCorrect ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(verdict.isCorrect ? .green : .orange)
                    .symbolEffect(.bounce, value: verdict.isCorrect)

                Text(verdict.isCorrect ? "잘 맞아요!" : "조금 더 다듬어 볼까요?")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 0)

                Text("\(verdict.score)점")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (verdict.isCorrect ? Color.green : Color.orange).opacity(0.15),
                        in: Capsule()
                    )
            }

            Text(verdict.feedback)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if let suggested = verdict.suggestedTranslation {
                VStack(alignment: .leading, spacing: 4) {
                    Text("추천 표현")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(suggested)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .accessibilityIdentifier("verificationResult")
    }

    private func stepBadge(number: Int, isActive: Bool, isCompleted: Bool) -> some View {
        ZStack {
            Circle()
                .fill(isCompleted ? Color.green.opacity(0.18) : (isActive ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill)))
                .frame(width: 28, height: 28)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
            } else {
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
            }
        }
    }

    private func cardBackground(isActive: Bool, isCompleted: Bool) -> some ShapeStyle {
        if isCompleted {
            return AnyShapeStyle(Color.green.opacity(0.06))
        }
        if isActive {
            return AnyShapeStyle(Color.accentColor.opacity(0.06))
        }
        return AnyShapeStyle(Color(.secondarySystemGroupedBackground))
    }

    private func cardBorder(isActive: Bool, highlightColor: Color) -> some View {
        RoundedRectangle(cornerRadius: 18)
            .strokeBorder(
                isActive ? highlightColor.opacity(0.55) : Color.primary.opacity(0.06),
                lineWidth: isActive ? 2 : 1
            )
    }

    private func triggerShake() {
        shakeVerification = false
        withAnimation(.default) {
            shakeVerification = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            shakeVerification = false
        }
    }
}

// MARK: - Step Card

private struct ShadowingStepCard: View {
    let stepNumber: Int
    let title: String
    let subtitle: String
    let icon: String
    let isActive: Bool
    let isCompleted: Bool
    let transcribedText: String?
    let duration: TimeInterval?
    let isRecording: Bool
    let showsRecordingUI: Bool
    let elapsedTime: TimeInterval
    let isPlaying: Bool
    let canInteract: Bool
    let canRecord: Bool
    let isRecorderReady: Bool
    let onToggleRecording: () -> Void
    let onTogglePlayback: () -> Void

    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                stepBadge

                VStack(alignment: .leading, spacing: 2) {
                    Label(title, systemImage: icon)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            if let transcribedText {
                Text(transcribedText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 12) {
                if duration != nil {
                    Button(action: onTogglePlayback) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canInteract || isRecording)
                }

                if showsRecordingUI {
                    Text(formattedDuration(elapsedTime))
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }

                Spacer(minLength: 0)

                Button(action: onToggleRecording) {
                    Image(systemName: showsRecordingUI ? "stop.fill" : "mic.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(showsRecordingUI ? .white : .primary)
                        .frame(width: 40, height: 40)
                        .background {
                            ZStack {
                                if showsRecordingUI {
                                    Circle()
                                        .stroke(Color.red.opacity(0.35), lineWidth: 3)
                                        .scaleEffect(pulse ? 1.18 : 1)
                                        .opacity(pulse ? 0.2 : 0.7)
                                }
                                Circle()
                                    .fill(showsRecordingUI ? Color.red.opacity(0.92) : Color(.secondarySystemFill))
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(!canRecord && !showsRecordingUI)
                .opacity(canRecord || showsRecordingUI ? (isRecorderReady || showsRecordingUI ? 1 : 0.45) : 0.35)
                .accessibilityLabel(showsRecordingUI ? "녹음 중지" : "녹음 시작")
                .onAppear {
                    startPulseIfNeeded()
                }
                .onChange(of: showsRecordingUI) { _, _ in
                    startPulseIfNeeded()
                }
            }
            .padding(.leading, 38)
        }
        .padding(16)
        .background(cardBackground)
        .overlay(cardBorder)
        .opacity(canInteract ? 1 : 0.45)
        .scaleEffect(isActive ? 1.02 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isActive)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isCompleted)
    }

    private var stepBadge: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? Color.green.opacity(0.18) : (isActive ? Color.accentColor.opacity(0.18) : Color(.tertiarySystemFill)))
                .frame(width: 28, height: 28)

            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.green)
            } else {
                Text("\(stepNumber)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
            }
        }
    }

    private var cardBackground: AnyShapeStyle {
        if isCompleted {
            return AnyShapeStyle(Color.green.opacity(0.06))
        }
        if isActive {
            return AnyShapeStyle(Color.accentColor.opacity(0.06))
        }
        return AnyShapeStyle(Color(.secondarySystemGroupedBackground))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 18)
            .strokeBorder(
                isActive ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.06),
                lineWidth: isActive ? 2 : 1
            )
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func startPulseIfNeeded() {
        guard showsRecordingUI else {
            pulse = false
            return
        }
        pulse = false
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

// MARK: - Shake

private struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 6 * sin(animatableData * .pi * 4)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

#Preview {
    ShadowingView(selectedTab: .constant(.shadowing))
}
