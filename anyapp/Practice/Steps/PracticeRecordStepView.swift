//
//  PracticeRecordStepView.swift
//  anyapp
//

import SwiftUI

struct PracticeRecordStepView: View {
    let title: String
    let subtitle: String
    let referenceTitle: String?
    let referenceText: String?
    let phase: SpeakingPracticeSession.RecordPhase
    let draftText: Binding<String>
    let elapsedTime: TimeInterval
    let isRecorderReady: Bool
    let isInteractionEnabled: Bool
    let providerLabel: String?
    let onToggleRecording: () -> Void
    let onRetake: () -> Void
    let onContinue: () -> Void
    let continueTitle: String

    @State private var showsReference = true

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                if let referenceTitle, let referenceText, !referenceText.isEmpty {
                    referenceCard(title: referenceTitle, text: referenceText)
                }

                recordingSection

                if phase == .review || !draftText.wrappedValue.isEmpty {
                    transcriptCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .animation(.easeInOut(duration: 0.25), value: phase)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let providerLabel {
                Text(providerLabel)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
        }
    }

    private func referenceCard(title: String, text: String) -> some View {
        DisclosureGroup(isExpanded: $showsReference) {
            Text(text)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
        } label: {
            Label(title, systemImage: "character.bubble")
                .font(.subheadline.weight(.medium))
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var recordingSection: some View {
        VStack(spacing: 12) {
            PracticeRecordButton(
                isRecording: phase == .recording,
                isEnabled: isInteractionEnabled && isRecorderReady && phase != .transcribing,
                action: onToggleRecording
            )

            if phase == .recording {
                Text(formattedDuration(elapsedTime))
                    .font(.system(.title3, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("practiceRecordingTimer")
            } else if phase == .transcribing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("음성 변환 중…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("인식된 텍스트")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            TextEditor(text: draftText)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .disabled(phase == .transcribing)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("재녹음", action: onRetake)
                .buttonStyle(.bordered)
                .disabled(phase == .recording || phase == .transcribing)

            Button(continueTitle, action: onContinue)
                .buttonStyle(.borderedProminent)
                .disabled(!canContinue)
        }
        .frame(maxWidth: .infinity)
    }

    private var canContinue: Bool {
        phase == .review
            && !draftText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && phase != .transcribing
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}