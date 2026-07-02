//
//  ItemDetailView.swift
//  anyapp
//

import AVFoundation
import SwiftData
import SwiftUI

struct ItemDetailView: View {
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

    @State private var audioPlayer = AudioPlayer()

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                micButton
                    .padding(.top, 120)

                belowMicSlot

                savedNoteSection

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 30 {
                        isTextFieldFocused = false
                    }
                }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .bottom) { bottomHint }
        .navigationTitle(item.timestamp.formatted(.dateTime.day().month().year().hour().minute()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장", action: saveMemo)
                    .disabled(!hasUnsavedChanges)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            inputToolbar
        }
        .overlay(alignment: .top) { topBanner }
        .animation(.easeInOut(duration: 0.2), value: showSaveConfirmation)
        .animation(.easeInOut(duration: 0.2), value: recordingErrorMessage)
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
            Image(systemName: recorder.isRecording ? "stop.fill" : "mic")
                .font(.system(size: 30, weight: .light))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(recorder.isRecording ? .white : .primary)
                .frame(width: 88, height: 88)
                .background {
                    Circle()
                        .fill(recorder.isRecording ? Color.red.opacity(0.88) : Color(.secondarySystemFill))
                }
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.06), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("micButton")
        .accessibilityLabel(recorder.isRecording ? "녹음 중지" : "녹음 시작")
        .accessibilityHint(recorder.canRecord ? "" : "마이크 권한이 필요합니다")
        .disabled(!recorder.isPrepared)
        .opacity(recorder.isPrepared && (recorder.canRecord || recorder.isRecording) ? 1 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
    }

    @ViewBuilder
    private var belowMicSlot: some View {
        Group {
            if recorder.isRecording {
                Text(formattedDuration(recorder.elapsedTime))
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("recordingTimer")
            } else if let duration = item.audioDuration {
                playbackControls(duration: duration)
            } else {
                Color.clear
            }
        }
        .frame(height: 60)
    }

    @ViewBuilder
    private var savedNoteSection: some View {
        if !item.textNote.isEmpty {
            Text(item.textNote)
                .font(.body)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .textSelection(.enabled)
        }
    }

    private func playbackControls(duration: TimeInterval) -> some View {
        HStack(spacing: 16) {
            Button(action: togglePlayback) {
                Image(systemName: audioPlayer.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("playbackButton")
            .disabled(recorder.isRecording)
            .opacity(recorder.isRecording ? 0.45 : 1)

            Text(formattedDuration(duration))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
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

    private func toggleRecording() {
        if recorder.isRecording {
            finishRecording()
            return
        }
        startRecording()
    }

    private func startRecording() {
        Task { @MainActor in
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
            item.deleteAudioFile()

            let url = AudioFileStore.newRecordingURL()
            pendingRecordingFileName = url.lastPathComponent

            do {
                try recorder.startRecording(to: url)
            } catch {
                pendingRecordingFileName = nil
                try? FileManager.default.removeItem(at: url)
                let message = recorder.lastErrorMessage
                    ?? (error as? LocalizedError)?.errorDescription
                    ?? "녹음을 시작할 수 없습니다."
                await flashRecordingError(message)
            }
        }
    }

    /// Stops recording and persists audio metadata. No speech or async follow-up work.
    private func finishRecording() {
        guard recorder.isRecording else { return }

        let pending = pendingRecordingFileName
        pendingRecordingFileName = nil

        let duration = recorder.stopRecording()

        guard let duration, duration > 0, let pending else {
            if let pending {
                let url = AudioFileStore.documentsDirectory.appendingPathComponent(pending)
                try? FileManager.default.removeItem(at: url)
            }
            Task { await flashRecordingError("녹음된 오디오가 없습니다. 다시 시도해 주세요.") }
            return
        }

        item.audioFileName = pending
        item.audioDuration = duration
        try? modelContext.save()
    }

    // MARK: - Playback

    private func togglePlayback() {
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

    // MARK: - Notes

    private func saveMemo() {
        isTextFieldFocused = false
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
        if item.textNote.isEmpty {
            item.textNote = trimmed
        } else {
            item.textNote += "\n" + trimmed
        }
        draftText = ""
        hasUnsavedChanges = false
    }

    // MARK: - Lifecycle

    private func teardown() {
        recorder.stopRecording()
        audioPlayer.stop()
        recorder.deactivatePlaybackSession()
        if hasUnsavedChanges {
            appendDraftToNote()
            try? modelContext.save()
        }
    }

    // MARK: - Helpers

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
    private var player: AVAudioPlayer?
    private var delegate: PlayerDelegate?

    func play(url: URL) throws {
        stop()
        let player = try AVAudioPlayer(contentsOf: url)
        let delegate = PlayerDelegate { [weak self] in
            self?.isPlaying = false
        }
        player.delegate = delegate
        self.player = player
        self.delegate = delegate
        player.play()
        isPlaying = true
    }

    func stop() {
        player?.stop()
        player = nil
        delegate = nil
        isPlaying = false
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
