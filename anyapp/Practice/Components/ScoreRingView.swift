//
//  ScoreRingView.swift
//  anyapp
//

import SwiftUI

struct ScoreRingView: View {
    let score: Int
    let lexicalScore: Int
    let semanticScore: Int?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedScore = 0
    @State private var progress: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .spring(duration: 1.0), value: progress)

                VStack(spacing: 2) {
                    Text("\(animatedScore)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("점")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 148, height: 148)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("종합 점수 \(score)점")

            HStack(spacing: 16) {
                scoreChip(title: "단어", value: lexicalScore)
                if let semanticScore {
                    scoreChip(title: "의미", value: semanticScore)
                }
            }
        }
        .onAppear(perform: animateIn)
        .onChange(of: score) { _, _ in animateIn() }
        .sensoryFeedback(.success, trigger: score >= 80)
    }

    private var ringColor: Color {
        switch score {
        case 80...:
            .green
        case 50..<80:
            .yellow
        default:
            .orange
        }
    }

    private func scoreChip(title: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemFill), in: Capsule())
    }

    private func animateIn() {
        if reduceMotion {
            animatedScore = score
            progress = CGFloat(score) / 100
            return
        }

        animatedScore = 0
        progress = 0

        withAnimation(.spring(duration: 1.0)) {
            progress = CGFloat(score) / 100
        }

        let steps = max(score, 1)
        let interval = 1.0 / Double(steps)
        for value in 0...score {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(value) * interval) {
                animatedScore = value
            }
        }
    }
}