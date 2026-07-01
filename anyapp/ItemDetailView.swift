//
//  ItemDetailView.swift
//  anyapp
//

import AVFoundation
import SwiftData
import SwiftUI

struct ItemDetailView: View {
    @Bindable var item: Item
    @State private var recorder = AudioRecorder()
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var pendingRecordingFileName: String?
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            micButton

            if recorder.isRecording {
                Text(formattedDuration(recorder.elapsedTime))
                    .font(.system(.title3, design: .rounded, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            } else if let duration = item.audioDuration {
                playbackControls(duration: duration)
            }

            if case .permissionDenied = recorder.state {
                Text("마이크를 사용할 수 없습니다.\n아래 입력창으로 메모를 작성하세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(item.timestamp.formatted(.dateTime.day().month().year().hour().minute()))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            inputToolbar
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            await recorder.prepare()
        }
        .onDisappear {
            finishRecordingIfNeeded()
            stopPlayback()
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
        .disabled(!recorder.canRecord)
        .opacity(recorder.canRecord ? 1 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)
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
            TextField("생각을 적어보세요", text: $item.textNote, axis: .vertical)
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

        if let duration = recorder.stopRecording() {
            item.audioFileName = pendingRecordingFileName
            item.audioDuration = duration
        } else if let fileName = pendingRecordingFileName {
            let url = AudioFileStore.documentsDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }

        pendingRecordingFileName = nil
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
