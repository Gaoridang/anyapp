//
//  ComparisonResultView.swift
//  anyapp
//

import SwiftUI

struct ComparisonResultView: View {
    let result: SpeechComparisonResult
    let showsSemanticFallbackNotice: Bool
    let koreanAudioURL: URL?
    let englishAudioURL: URL?
    let onReplayKorean: () -> Void
    let onReplayEnglish: () -> Void
    let onRestart: () -> Void
    let onFinish: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ScoreRingView(
                    score: result.overallScore,
                    lexicalScore: result.lexicalScore,
                    semanticScore: result.semanticScore
                )
                .padding(.top, 8)

                if showsSemanticFallbackNotice {
                    fallbackNotice
                }

                comparisonCard(
                    title: "기대 영어",
                    subtitle: "번역 기준",
                    tokens: result.expectedTokens,
                    plainText: result.expectedEnglish
                )

                comparisonCard(
                    title: "내가 말한 영어",
                    subtitle: "발화 비교",
                    tokens: result.spokenTokens,
                    plainText: result.spokenEnglish,
                    highlighted: true
                )

                feedbackSection

                playbackButtons

                actionButtons
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }

    private var fallbackNotice: some View {
        Label {
            Text("의미 분석은 API 키가 있을 때 사용할 수 있어요. 지금은 단어 비교 중심으로 표시합니다.")
                .font(.caption)
        } icon: {
            Image(systemName: "info.circle")
        }
        .foregroundStyle(.secondary)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func comparisonCard(
        title: String,
        subtitle: String,
        tokens: [ComparisonToken],
        plainText: String,
        highlighted: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if highlighted, !tokens.isEmpty {
                HighlightedTokenText(tokens: tokens)
            } else if !tokens.isEmpty {
                HighlightedTokenText(tokens: tokens)
            } else {
                Text(plainText)
                    .font(.body)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("피드백", systemImage: "text.bubble")
                .font(.headline)

            Text(result.summary)
                .font(.body)

            if !result.feedbackItems.isEmpty {
                ForEach(result.feedbackItems) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(feedbackColor(for: item.kind))
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)

                        Text(item.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .transition(.push(from: .bottom))
    }

    private var playbackButtons: some View {
        HStack(spacing: 12) {
            if koreanAudioURL != nil {
                Button(action: onReplayKorean) {
                    Label("한국어 다시 듣기", systemImage: "play.circle")
                }
                .buttonStyle(.bordered)
            }

            if englishAudioURL != nil {
                Button(action: onReplayEnglish) {
                    Label("영어 다시 듣기", systemImage: "play.circle")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("처음부터 다시", action: onRestart)
                .buttonStyle(.bordered)

            Button("완료", action: onFinish)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
    }

    private func feedbackColor(for kind: ComparisonToken.TokenKind) -> Color {
        switch kind {
        case .match:
            .green
        case .synonym:
            .blue
        case .mismatch:
            .red
        case .missing:
            .gray
        case .extra:
            .yellow
        }
    }
}