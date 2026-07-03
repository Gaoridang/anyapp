//
//  ItemDetailView.swift
//  anyapp
//

import AVFoundation
import SwiftData
import SwiftUI
import UIKit

struct ItemDetailView: View {
    enum TranscriptionState: Equatable {
        case idle
        case transcribing
        case failed(String)
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var item: Item
    @State private var recorder = AudioRecorder()

    @State private var pendingRecordingFileName: String?
    @State private var draftText = ""
    @State private var hasUnsavedChanges = false
    @State private var showSaveConfirmation = false
    @State private var saveErrorMessage: String?
    @State private var recordingErrorMessage: String?
    @State private var showsRecordingUI = false
    @State private var isHandlingRecordingTap = false

    @State private var audioPlayer = AudioPlayer()
    @State private var transcriptionState: TranscriptionState = .idle
    @State private var transcriptionTask: Task<Void, Never>?
    @State private var sttRouter = STTRouter()
    @State private var activeTranscriptionProvider: STTProvider?

    @FocusState private var isTextFieldFocused: Bool

    private var isTranscribing: Bool {
        if case .transcribing = transcriptionState { return true }
        return false
    }

    private var transcribingStatusText: String {
        switch activeTranscriptionProvider {
        case .grok:
            "Grok 변환 중…"
        case .onDevice:
            "기기 변환 중…"
        case nil:
            "변환 중…"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    micButton
                        .padding(.top, 120)

                    belowMicSlot

                    savedNoteSection

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: geometry.size.height, alignment: .top)
                .contentShape(Rectangle())
                .onTapGesture(perform: dismissKeyboard)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        if value.translation.height > 30 {
                            dismissKeyboard()
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .bottom) {
            bottomHint
                .onTapGesture(perform: dismissKeyboard)
        }
        .navigationTitle(item.timestamp.formatted(.dateTime.day().month().year().hour().minute()))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            inputToolbar
        }
        .overlay(alignment: .top) { topBanner }
        .animation(.easeInOut(duration: 0.2), value: showSaveConfirmation)
        .animation(.easeInOut(duration: 0.2), value: recordingErrorMessage)
        .animation(.easeInOut(duration: 0.2), value: transcriptionState)
        .alert("저장 실패", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(saveErrorMessage ?? "")
        }
        .task {
            await recorder.prepare()
            resumePendingTranscriptionIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                recorder.refreshPermissionState()
            }
        }
        .onChange(of: draftText) {
            hasUnsavedChanges = !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .onDisappear(perform: teardown)
    }

    // MARK: - Subviews

    private var micButton: some View {
        Button(action: toggleRecording) {
            Image(systemName: showsRecordingUI ? "stop.fill" : "mic")
                .font(.system(size: 30, weight: .light))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(showsRecordingUI ? .white : .primary)
                .frame(width: 88, height: 88)
                .background {
                    Circle()
                        .fill(showsRecordingUI ? Color.red.opacity(0.88) : Color(.secondarySystemFill))
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("micButton")
        .accessibilityLabel(showsRecordingUI ? "녹음 중지" : "녹음 시작")
        .accessibilityHint(recorder.canRecord ? "" : "마이크 권한이 필요합니다")
        .disabled(!recorder.isPrepared || isHandlingRecordingTap || isTranscribing)
        .opacity(recorder.isPrepared && (recorder.canRecord || showsRecordingUI) && !isTranscribing ? 1 : 0.45)
        .animation(nil, value: showsRecordingUI)
    }

    @ViewBuilder
    private var belowMicSlot: some View {
        Group {
            if showsRecordingUI {
                Text(formattedDuration(recorder.elapsedTime))
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("recordingTimer")
            } else if isTranscribing {
                Text(transcribingStatusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("transcribingLabel")
            } else if let duration = item.audioDuration {
                playbackControls(duration: duration)
            } else {
                Color.clear
            }
        }
        .frame(height: 60)
        .animation(nil, value: showsRecordingUI)
    }

    @ViewBuilder
    private var savedNoteSection: some View {
        if !item.textNote.isEmpty {
            Text(item.textNote)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
                .padding(.horizontal, 20)
                .textSelection(.enabled)
        }
    }

    private func playbackControls(duration: TimeInterval) -> some View {
        let displayDuration = playbackDisplayDuration(totalDuration: duration)

        return HStack(spacing: 16) {
            Button(action: togglePlayback) {
                Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("playbackButton")
            .disabled(showsRecordingUI || recorder.isRecording || isHandlingRecordingTap || isTranscribing)
            .opacity(showsRecordingUI || recorder.isRecording || isTranscribing ? 0.45 : 1)

            Text(formattedDuration(displayDuration))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .accessibilityLabel(audioPlayer.isPlaying ? "남은 시간" : "총 길이")
        }
    }

    private var inputToolbar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("생각을 적어보세요", text: $draftText, axis: .vertical)
                .focused($isTextFieldFocused)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))

            Button("저장", action: saveMemo)
                .font(.body.weight(.semibold))
                .buttonStyle(.plain)
                .padding(.bottom, 10)
                .disabled(!hasUnsavedChanges)
                .accessibilityIdentifier("saveMemoButton")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Rectangle()
                .fill(.bar)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private var bottomHint: some View {
        if let recordingErrorMessage {
            hintText(recordingErrorMessage)
        } else if case .failed(let message) = transcriptionState {
            VStack(spacing: 8) {
                hintText(message)
                Button("다시 시도", action: retryTranscription)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.bottom, 100)
        } else if case .permissionDenied = recorder.state {
            hintText("마이크를 사용할 수 없습니다.\n아래 입력창으로 메모를 작성하세요.")
        }
    }

    private func hintText(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .padding(.bottom, 100)
    }

    @ViewBuilder
    private var topBanner: some View {
        if showSaveConfirmation {
            Text("저장됨")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        } else if case .error(let message) = recorder.state {
            banner(message)
        }
    }

    private func banner(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.top, 8)
    }

    // MARK: - Recording

    private static let recordingUITransitionDelay: Duration = .milliseconds(120)

    private func toggleRecording() {
        dismissKeyboard()
        guard !isHandlingRecordingTap else { return }

        if recorder.isRecording {
            triggerRecordingHaptic(isStarting: false)
            finishRecording()
            return
        }
        triggerRecordingHaptic(isStarting: true)
        startRecording()
    }

    private func triggerRecordingHaptic(isStarting: Bool) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = isStarting ? .medium : .rigid
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func startRecording() {
        isHandlingRecordingTap = true

        Task { @MainActor in
            defer {
                if !recorder.isRecording {
                    isHandlingRecordingTap = false
                }
            }

            if !recorder.canRecord {
                await recorder.prepare()
                guard recorder.canRecord else {
                    await flashRecordingError(
                        recorder.lastErrorMessage ?? "마이크 권한이 필요합니다. 설정에서 허용해 주세요."
                    )
                    return
                }
            }

            recordingErrorMessage = nil
            recorder.clearErrorState()
            audioPlayer.stop()
            recorder.deactivatePlaybackSession()

            await ensureTranscriptionCompleteBeforeReplacingAudio()

            item.deleteAudioFile()

            let url = AudioFileStore.newRecordingURL()
            pendingRecordingFileName = url.lastPathComponent

            do {
                try recorder.startRecording(to: url)
                try await Task.sleep(for: Self.recordingUITransitionDelay)
                showsRecordingUI = true
                isHandlingRecordingTap = false
            } catch {
                pendingRecordingFileName = nil
                try? FileManager.default.removeItem(at: url)
                showsRecordingUI = false
                let message = recorder.lastErrorMessage
                    ?? (error as? LocalizedError)?.errorDescription
                    ?? "녹음을 시작할 수 없습니다."
                await flashRecordingError(message)
            }
        }
    }

    /// Stops recording and persists audio metadata. STT runs asynchronously afterward.
    private func finishRecording() {
        guard recorder.isRecording else { return }

        isHandlingRecordingTap = true

        let pending = pendingRecordingFileName
        pendingRecordingFileName = nil

        let duration = recorder.stopRecording()

        Task { @MainActor in
            defer { isHandlingRecordingTap = false }

            try? await Task.sleep(for: Self.recordingUITransitionDelay)

            guard let duration, duration > 0, let pending else {
                showsRecordingUI = false
                if let pending {
                    let url = AudioFileStore.documentsDirectory.appendingPathComponent(pending)
                    try? FileManager.default.removeItem(at: url)
                }
                await flashRecordingError("녹음된 오디오가 없습니다. 다시 시도해 주세요.")
                return
            }

            showsRecordingUI = false
            item.audioFileName = pending
            item.audioDuration = duration
            try? modelContext.save()

            startTranscription(for: pending)
        }
    }

    // MARK: - Transcription

    private func startTranscription(for fileName: String) {
        let url = AudioFileStore.documentsDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        transcriptionTask?.cancel()
        transcriptionTask = Task { @MainActor in
            await transcribeAudio(fileName: fileName, fileURL: url)
        }
    }

    private func retryTranscription() {
        guard let fileName = item.audioFileName else { return }
        startTranscription(for: fileName)
    }

    private func resumePendingTranscriptionIfNeeded() {
        guard item.needsTranscription, let fileName = item.audioFileName else { return }
        startTranscription(for: fileName)
    }

    @MainActor
    private func ensureTranscriptionCompleteBeforeReplacingAudio() async {
        if let transcriptionTask {
            await transcriptionTask.value
        }

        guard item.needsTranscription,
              let fileName = item.audioFileName,
              let url = item.audioFileURL else {
            return
        }

        await transcribeAudio(fileName: fileName, fileURL: url)
    }

    @MainActor
    private func transcribeAudio(fileName: String, fileURL: URL) async {
        guard fileName != item.lastTranscribedAudioFileName else {
            transcriptionState = .idle
            activeTranscriptionProvider = nil
            return
        }

        let provider = sttRouter.resolvedProvider()
        activeTranscriptionProvider = provider
        transcriptionState = .transcribing

        do {
            let text = try await sttRouter.transcribe(audioFileURL: fileURL)
            guard !Task.isCancelled else { return }

            item.appendTextEntry(text)
            item.lastTranscribedAudioFileName = fileName
            try modelContext.save()
            transcriptionState = .idle
            activeTranscriptionProvider = nil
        } catch is CancellationError {
            transcriptionState = .idle
            activeTranscriptionProvider = nil
        } catch {
            transcriptionState = .failed(error.localizedDescription)
            activeTranscriptionProvider = nil
        }
    }

    // MARK: - Playback

    private func togglePlayback() {
        dismissKeyboard()
        guard let url = item.audioFileURL else { return }

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

    private func playbackDisplayDuration(totalDuration: TimeInterval) -> TimeInterval {
        if audioPlayer.isPlaying {
            return AudioPlayer.remainingTime(
                total: audioPlayer.duration > 0 ? audioPlayer.duration : totalDuration,
                elapsed: audioPlayer.currentTime
            )
        }
        return totalDuration
    }

    // MARK: - Notes

    private func saveMemo() {
        dismissKeyboard()
        appendDraftToNote()

        do {
            try modelContext.save()
        } catch {
            saveErrorMessage = error.localizedDescription
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            showSaveConfirmation = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 0.2)) {
                showSaveConfirmation = false
            }
        }
    }

    private func appendDraftToNote() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        item.appendTextEntry(trimmed)
        draftText = ""
        hasUnsavedChanges = false
    }

    // MARK: - Lifecycle

    private func teardown() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        recorder.stopRecording()
        showsRecordingUI = false
        isHandlingRecordingTap = false
        audioPlayer.stop()
        recorder.deactivatePlaybackSession()
        if hasUnsavedChanges {
            appendDraftToNote()
            try? modelContext.save()
        }
    }

    // MARK: - Helpers

    private func dismissKeyboard() {
        isTextFieldFocused = false
    }

    @MainActor
    private func flashRecordingError(_ message: String) async {
        recordingErrorMessage = message
        try? await Task.sleep(for: .seconds(3))
        recordingErrorMessage = nil
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

/// Lightweight AVAudioPlayer wrapper that keeps `isPlaying` in sync with playback,
/// including automatic reset when playback finishes.
@Observable
@MainActor
final class AudioPlayer {
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var delegate: PlayerDelegate?
    private var tickTask: Task<Void, Never>?

    static func remainingTime(total: TimeInterval, elapsed: TimeInterval) -> TimeInterval {
        max(0, total - elapsed)
    }

    func play(url: URL) throws {
        stop()
        let player = try AVAudioPlayer(contentsOf: url)
        let delegate = PlayerDelegate { [weak self] in
            self?.handlePlaybackFinished()
        }
        player.delegate = delegate
        self.player = player
        self.delegate = delegate
        duration = player.duration
        currentTime = 0
        player.play()
        isPlaying = true
        startTick()
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
        player?.stop()
        player = nil
        delegate = nil
        isPlaying = false
        currentTime = 0
    }

    private func handlePlaybackFinished() {
        tickTask?.cancel()
        tickTask = nil
        isPlaying = false
        currentTime = duration
    }

    private func startTick() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self, let player = self.player, player.isPlaying else { break }
                self.currentTime = player.currentTime
            }
        }
    }

    private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            Task { @MainActor in onFinish() }
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: Item(timestamp: .now))
    }
    .modelContainer(for: Item.self, inMemory: true)
}
