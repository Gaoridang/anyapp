//
//  ItemDetailView.swift
//  anyapp
//

import AVFoundation
import SwiftData
import SwiftUI

struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item
    @State private var recorder = AudioRecorder()
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var pendingRecordingFileName: String?
    @State private var draftText = ""
    @State private var hasUnsavedChanges = false
    @State private var showSaveConfirmation = false
    @State private var processingStatus: ProcessingStatus?
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
        .contentShape(Rectangle())
        .onTapGesture {
            isTextFieldFocused = false
        }
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
            if case .permissionDenied = recorder.state {
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
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSaveConfirmation)
        .task {
            draftText = item.textNote
            await recorder.prepare()
            _ = await SpeechTranscriber.requestAuthorization()
        }
        .onChange(of: draftText) {
            hasUnsavedChanges = draftText != item.textNote
        }
        .onDisappear {
            finishRecordingIfNeeded()
            stopPlayback()
            if hasUnsavedChanges {
                item.textNote = draftText
                try? modelContext.save()
            }
        }
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
        .disabled(!recorder.canRecord || processingStatus != nil)
        .opacity(recorder.canRecord && processingStatus == nil ? 1 : 0.45)
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
                    .contentTransition(.numericText())
            } else if let duration = item.audioDuration {
                playbackControls(duration: duration)
            } else {
                Color.clear
            }
        }
        .frame(height: 60)
    }

    private func playbackControls(duration: TimeInterval) -> some View {
        HStack(spacing: 16) {
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)

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

        stopPlayback()
        item.deleteAudioFile()

        let url = AudioFileStore.newRecordingURL()
        pendingRecordingFileName = url.lastPathComponent

        do {
            try recorder.startRecording(to: url)
        } catch {
            pendingRecordingFileName = nil
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func finishRecordingIfNeeded() {
        guard recorder.isRecording else { return }

        var savedURL: URL?

        if let duration = recorder.stopRecording() {
            item.audioFileName = pendingRecordingFileName
            item.audioDuration = duration
            savedURL = item.audioFileURL
        } else if let fileName = pendingRecordingFileName {
            let url = AudioFileStore.documentsDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }

        pendingRecordingFileName = nil

        if let savedURL {
            Task { await processTranscription(from: savedURL) }
        }
    }

    private func processTranscription(from url: URL) async {
        processingStatus = .transcribing

        do {
            let rawText = try await SpeechTranscriber.transcribe(url: url)
            processingStatus = .correcting
            let corrected = await TextCorrector.correct(rawText)

            if draftText.isEmpty {
                draftText = corrected
            } else {
                draftText += "\n" + corrected
            }
            hasUnsavedChanges = draftText != item.textNote
        } catch {
            // 음성 인식 실패 시 오디오만 유지
        }

        processingStatus = nil
    }

    private func saveMemo() {
        item.textNote = draftText
        try? modelContext.save()
        hasUnsavedChanges = false

        showSaveConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            showSaveConfirmation = false
        }
    }

    private func togglePlayback() {
        guard let url = item.audioFileURL else { return }

        if isPlaying {
            stopPlayback()
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)

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
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: Item(timestamp: .now))
    }
    .modelContainer(for: Item.self, inMemory: true)
}
