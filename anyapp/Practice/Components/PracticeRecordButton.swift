//
//  PracticeRecordButton.swift
//  anyapp
//

import SwiftUI
import UIKit

struct PracticeRecordButton: View {
    let isRecording: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(isRecording ? .white : .primary)
                .frame(width: 72, height: 72)
                .background {
                    Circle()
                        .fill(isRecording ? Color.red.opacity(0.92) : Color(.secondarySystemFill))
                }
                .overlay {
                    if isRecording {
                        Circle()
                            .stroke(Color.red.opacity(0.35), lineWidth: 6)
                            .scaleEffect(1.15)
                            .opacity(0.8)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isRecording)
                    }
                }
                .symbolEffect(.bounce, value: isRecording)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "녹음 중지" : "녹음 시작")
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    static func triggerHaptic(isStarting: Bool) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = isStarting ? .medium : .rigid
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}