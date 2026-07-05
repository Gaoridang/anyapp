//
//  PracticeStepIndicator.swift
//  anyapp
//

import SwiftUI

struct PracticeStepIndicator: View {
    let step: SpeakingPracticeSession.Step

    private let labels = ["한국어", "영어", "결과"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SpeakingPracticeSession.Step.allCases, id: \.rawValue) { item in
                stepItem(for: item)

                if item != .result {
                    connector(isActive: item.rawValue < step.rawValue)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .animation(.spring(response: 0.4), value: step)
    }

    @ViewBuilder
    private func stepItem(for item: SpeakingPracticeSession.Step) -> some View {
        let state = stepState(for: item)

        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(state.fillColor)
                    .frame(width: 28, height: 28)

                if state.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(item.rawValue + 1)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(state.isCurrent ? .white : .secondary)
                }
            }

            Text(labels[item.rawValue])
                .font(.caption)
                .foregroundStyle(state.isCurrent ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func connector(isActive: Bool) -> some View {
        Rectangle()
            .fill(isActive ? Color.accentColor : Color(.separator))
            .frame(height: 2)
            .frame(maxWidth: 36)
            .padding(.bottom, 18)
    }

    private func stepState(for item: SpeakingPracticeSession.Step) -> StepVisualState {
        if item.rawValue < step.rawValue {
            StepVisualState(isCompleted: true, isCurrent: false)
        } else if item == step {
            StepVisualState(isCompleted: false, isCurrent: true)
        } else {
            StepVisualState(isCompleted: false, isCurrent: false)
        }
    }

    private struct StepVisualState {
        let isCompleted: Bool
        let isCurrent: Bool

        var fillColor: Color {
            if isCompleted || isCurrent {
                Color.accentColor
            } else {
                Color(.tertiarySystemFill)
            }
        }
    }
}