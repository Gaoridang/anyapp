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
    @State private var recorder: AudioRecorder

    init(item: Item, injectedRecorder: AudioRecorder? = nil) {
        self.item = item
        _recorder = State(initialValue: injectedRecorder ?? AudioRecorder())
    }
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var pendingRecordingFileName: String?
    @State private var draftText = ""
    @State private var hasUnsavedChanges = false
    @State private var showSaveConfirmation = false
    @State private var saveErrorMessage: String?
    @State private var transcriptionErrorMessage: String?
    @State private var recordingErrorMessage: String?
    @State private var processingStatus: ProcessingStatus?
    @State private var transcriptionTask: Task<Void, Never>?
    @FocusState private var isTextFieldFocused: Bool

    private enum ProcessingStatus {
        case transcribing
        case correcting

        var label: String {
            switch self {
            case .transcribing: "음성을 텍스트로 변환 중..."
            case .correcting: "텍스트 보정 중..."
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                micButton
                    .padding(.top, 120)

                belowMicSlot

                savedNoteSection

                if let processingStatus {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text(processingStatus.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

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
        .overlay(alignment: .bottom) {
            if let recordingErrorMessage {
                Text(recordingErrorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 100)
            } else if case .permissionDenied = recorder.state {
                Text("마이크를 사용할 수 없습니다.\n아래 입력창으로 메모를 작성하세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 100)
            }
        }
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
        .overlay(alignment: .top) {
            if showSaveConfirmation {
                Text("저장됨")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let transcriptionErrorMessage {
                Text(transcriptionErrorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 8)
            } else if case .error(let message) = recorder.state {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 8)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSaveConfirmation)
        .animation(.easeInOut(duration: 0.2), value: transcriptionErrorMessage)
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
        .task {
            _ = await SpeechTranscriber.requestAuthorization()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                recorder.refreshPermissionState()
            }
        }
        .onChange(of: draftText) {
            hasUnsavedChanges = !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        .onDisappear {
            transcriptionTask?.cancel()
            transcriptionTask = nil
            finishRecordingIfNeeded()
            stopPlayback()
            if hasUnsavedChanges {
                appendDraftToNote()
                try? modelContext.save()
            }
        }
        #if DEBUG
        .task(id: ProcessInfo.processInfo.environment["FINISH_SMOKE"]) {
            if let mode = ProcessInfo.processInfo.environment["FINISH_SMOKE"] {
                await runIntegratedFinishSmoke(mode: mode)
            }
        }
        #endif
    }

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
        .disabled(!recorder.isPrepared || (processingStatus != nil && !recorder.isRecording))
        .opacity(recorder.isPrepared && (recorder.canRecord || recorder.isRecording) && (processingStatus == nil || recorder.isRecording) ? 1 : 0.45)
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
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
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

    private func toggleRecording() {
        if recorder.isRecording {
            finishRecordingIfNeeded()
            return
        }

        Task { @MainActor in
            if !recorder.canRecord {
                await recorder.prepare()
                guard recorder.canRecord else {
                    recordingErrorMessage = recorder.lastErrorMessage
                        ?? "마이크 권한이 필요합니다. 설정에서 허용해 주세요."
                    try? await Task.sleep(for: .seconds(3))
                    recordingErrorMessage = nil
                    return
                }
            }

            recordingErrorMessage = nil
            recorder.clearErrorState()
            stopPlayback()
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
                recordingErrorMessage = message
                try? await Task.sleep(for: .seconds(3))
                recordingErrorMessage = nil
            }
        }
    }

    private func finishRecordingIfNeeded() {
        fputs("ItemDetailView.finishRecordingIfNeeded: entered isRecording=\(recorder.isRecording)\n", stderr)
        fflush(stderr)

        guard recorder.isRecording else { return }

        let pending = pendingRecordingFileName
        pendingRecordingFileName = nil

        let duration = recorder.stopRecording()
        if let duration, duration > 0, let pending {
            item.audioFileName = pending
            item.audioDuration = duration
            fputs(
                "ItemDetailView.finishRecordingIfNeeded: persisted fileName=\(pending) duration=\(duration)\n",
                stderr
            )
            fflush(stderr)
            try? modelContext.save()

            let isSmoke = ProcessInfo.processInfo.environment["FINISH_SMOKE"] != nil
            if !isSmoke, let savedURL = item.audioFileURL {
                transcriptionTask?.cancel()
                transcriptionTask = Task { @MainActor in
                    // Defer so stop UI + audio session teardown finish before Speech runs.
                    await Task.yield()
                    try? await Task.sleep(for: .milliseconds(300))
                    guard !Task.isCancelled else { return }
                    await processTranscription(from: savedURL)
                }
            }
        } else if let fileName = pending {
            let url = AudioFileStore.documentsDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
            fputs("ItemDetailView.finishRecordingIfNeeded: empty recording file=\(fileName)\n", stderr)
            fflush(stderr)
            recordingErrorMessage = "녹음된 오디오가 없습니다. 다시 시도해 주세요."
            if ProcessInfo.processInfo.environment["FINISH_SMOKE"] == nil {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    recordingErrorMessage = nil
                }
            }
        }
    }

    #if DEBUG
    private func runIntegratedFinishSmoke(mode: String) async {
        if mode != "mock" {
            await recorder.prepare()
            guard recorder.canRecord else {
                fputs("INTEGRATED_SKIP: microphone permission not granted\n", stderr)
                fflush(stderr)
                exit(0)
            }
        } else {
            await recorder.prepare()
        }

        let url = AudioFileStore.newRecordingURL()
        pendingRecordingFileName = url.lastPathComponent

        do {
            try recorder.startRecording(to: url)
        } catch {
            fputs("FAIL: startRecording \(error)\n", stderr)
            fflush(stderr)
            exit(1)
        }

        fputs("start: state=\(recorder.state) isRecording=\(recorder.isRecording)\n", stderr)
        fflush(stderr)

        guard recorder.isRecording else {
            fputs("FAIL: expected .recording after start\n", stderr)
            fflush(stderr)
            exit(1)
        }

        let sleepMs: UInt64 = mode == "live" ? 500 : 150
        try? await Task.sleep(for: .milliseconds(sleepMs))

        finishRecordingIfNeeded()

        if let fileName = item.audioFileName,
           let duration = item.audioDuration, duration > 0 {
            var pass = true
            if mode == "live" {
                let exists = FileManager.default.fileExists(atPath: url.path)
                let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64) ?? 0
                fputs("live-check: exists=\(exists) size=\(size)\n", stderr)
                fflush(stderr)
                pass = exists && size > 0
            }
            if pass {
                fputs(mode == "live" ? "LIVE_INTEGRATED_PASS\n" : "INTEGRATED_PASS\n", stderr)
                fflush(stderr)
                exit(0)
            }
        }

        fputs("FAIL: integrated smoke persist\n", stderr)
        fflush(stderr)
        exit(1)
    }
    #endif

    private func processTranscription(from url: URL) async {
        guard !Task.isCancelled else { return }

        transcriptionErrorMessage = nil
        processingStatus = .transcribing

        // 녹음 파일이 디스크에 완전히 기록될 때까지 잠시 대기
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else {
            processingStatus = nil
            return
        }

        do {
            let rawText = try await SpeechTranscriber.transcribe(url: url)
            guard !Task.isCancelled else {
                processingStatus = nil
                return
            }

            processingStatus = .correcting
            let corrected = await TextCorrector.correct(rawText)
            guard !Task.isCancelled else {
                processingStatus = nil
                return
            }

            if item.textNote.isEmpty {
                item.textNote = corrected
            } else {
                item.textNote += "\n" + corrected
            }
            try modelContext.save()
        } catch {
            guard !Task.isCancelled else {
                processingStatus = nil
                return
            }

            transcriptionErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "음성을 텍스트로 변환하지 못했습니다."
            try? await Task.sleep(for: .seconds(3))
            transcriptionErrorMessage = nil
        }

        processingStatus = nil
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

    private func togglePlayback() {
        guard let url = item.audioFileURL else { return }

        if isPlaying {
            stopPlayback()
            return
        }

        do {
            try recorder.activatePlaybackSession()
            player = try AVAudioPlayer(contentsOf: url)
            player?.play()
            isPlaying = true
        } catch {
            stopPlayback()
        }
    }

    private func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
        recorder.deactivatePlaybackSession()
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#if DEBUG
final class FinishSmokePermissionProvider: MicrophonePermissionProviding, @unchecked Sendable {
    var recordPermission: AVAudioApplication.recordPermission = .granted

    func requestRecordPermission() async -> Bool {
        recordPermission = .granted
        return true
    }
}

final class FinishSmokeSessionConfigurator: AudioSessionConfiguring, @unchecked Sendable {
    func deactivateSession() throws {}
    func configureForRecording() throws {}
}

final class FinishSmokeCapture: RecordingCapturing, @unchecked Sendable {
    var currentTime: TimeInterval = 0
    var isMeteringEnabled = false

    func prepareToRecord() -> Bool { true }
    func record() -> Bool { true }
    func stop() {}
}

final class FinishSmokeCaptureMaker: RecordingCaptureMaking, @unchecked Sendable {
    func makeRecorder(url: URL, settings: [String: Any]) throws -> any RecordingCapturing {
        FinishSmokeCapture()
    }
}
#endif

#Preview {
    NavigationStack {
        ItemDetailView(item: Item(timestamp: .now))
    }
    .modelContainer(for: Item.self, inMemory: true)
}
