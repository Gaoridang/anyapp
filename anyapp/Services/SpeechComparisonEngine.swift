//
//  SpeechComparisonEngine.swift
//  anyapp
//

import Foundation

struct SpeechComparisonEngine {
    private let semanticComparator: SemanticComparator
    private let hasGrokKey: @Sendable () -> Bool

    init(
        semanticComparator: SemanticComparator = SemanticComparator(),
        hasGrokKey: @escaping @Sendable () -> Bool = { GrokAPIKeyStore.hasKey }
    ) {
        self.semanticComparator = semanticComparator
        self.hasGrokKey = hasGrokKey
    }

    func compare(
        korean: String,
        expectedEnglish: String,
        spokenEnglish: String
    ) async -> SpeechComparisonResult {
        let lexical = LexicalComparator.compare(expected: expectedEnglish, spoken: spokenEnglish)

        guard hasGrokKey() else {
            return buildResult(
                lexical: lexical,
                semantic: nil,
                expectedEnglish: expectedEnglish,
                spokenEnglish: spokenEnglish
            )
        }

        let semantic = try? await semanticComparator.analyze(
            korean: korean,
            expectedEnglish: expectedEnglish,
            spokenEnglish: spokenEnglish
        )

        return buildResult(
            lexical: lexical,
            semantic: semantic,
            expectedEnglish: expectedEnglish,
            spokenEnglish: spokenEnglish
        )
    }

    private func buildResult(
        lexical: LexicalComparisonResult,
        semantic: SemanticAnalysisResult?,
        expectedEnglish: String,
        spokenEnglish: String
    ) -> SpeechComparisonResult {
        let promoted = promoteSynonyms(
            lexical: lexical,
            semantic: semantic
        )

        let feedbackItems = buildFeedback(from: semantic, lexical: promoted)
        let summary = semantic?.summary ?? defaultSummary(for: promoted.lexicalScore)
        let semanticScore = semantic?.semanticScore
        let overallScore: Int

        if let semanticScore {
            overallScore = Int((Double(promoted.lexicalScore) * 0.35 + Double(semanticScore) * 0.65).rounded())
        } else {
            overallScore = promoted.lexicalScore
        }

        return SpeechComparisonResult(
            lexicalScore: promoted.lexicalScore,
            semanticScore: semanticScore,
            overallScore: min(max(overallScore, 0), 100),
            expectedEnglish: expectedEnglish,
            spokenEnglish: spokenEnglish,
            expectedTokens: promoted.expectedTokens,
            spokenTokens: promoted.spokenTokens,
            feedbackItems: feedbackItems,
            summary: summary,
            usedSemanticAnalysis: semantic != nil
        )
    }

    private struct PromotedLexicalResult: Equatable {
        let lexicalScore: Int
        let expectedTokens: [ComparisonToken]
        let spokenTokens: [ComparisonToken]
    }

    private func promoteSynonyms(
        lexical: LexicalComparisonResult,
        semantic: SemanticAnalysisResult?
    ) -> PromotedLexicalResult {
        guard let semantic else {
            return PromotedLexicalResult(
                lexicalScore: lexical.score,
                expectedTokens: lexical.expectedTokens,
                spokenTokens: lexical.spokenTokens
            )
        }

        let synonymPairs = semantic.synonyms.filter(\.acceptable)

        func isSynonym(expected: String, spoken: String) -> Bool {
            synonymPairs.contains { pair in
                LexicalComparator.tokenize(pair.expected) == LexicalComparator.tokenize(expected)
                    && LexicalComparator.tokenize(pair.spoken) == LexicalComparator.tokenize(spoken)
            }
        }

        var expectedTokens = lexical.expectedTokens
        var spokenTokens = lexical.spokenTokens
        var additionalMatches = 0

        for index in expectedTokens.indices {
            guard expectedTokens[index].kind == .mismatch,
                  index < spokenTokens.count,
                  spokenTokens[index].kind == .mismatch,
                  let paired = expectedTokens[index].pairedText,
                  isSynonym(expected: expectedTokens[index].text, spoken: paired) else {
                continue
            }

            expectedTokens[index] = ComparisonToken(
                id: expectedTokens[index].id,
                text: expectedTokens[index].text,
                kind: .synonym,
                pairedText: paired
            )
            spokenTokens[index] = ComparisonToken(
                id: spokenTokens[index].id,
                text: spokenTokens[index].text,
                kind: .synonym,
                pairedText: expectedTokens[index].text
            )
            additionalMatches += 1
        }

        let baseMatches = lexical.expectedTokens.filter { $0.kind == .match }.count
        let denominator = max(lexical.expectedTokens.filter { $0.kind != .extra }.count, 1)
        let adjustedScore = Int(
            (Double(baseMatches + additionalMatches) / Double(denominator) * 100).rounded()
        )

        return PromotedLexicalResult(
            lexicalScore: min(max(adjustedScore, 0), 100),
            expectedTokens: expectedTokens,
            spokenTokens: spokenTokens
        )
    }

    private func buildFeedback(
        from semantic: SemanticAnalysisResult?,
        lexical: PromotedLexicalResult
    ) -> [FeedbackItem] {
        var items: [FeedbackItem] = []

        if let semantic {
            for synonym in semantic.synonyms where synonym.acceptable {
                if let feedback = synonym.feedback, !feedback.isEmpty {
                    items.append(
                        FeedbackItem(
                            kind: .synonym,
                            message: feedback,
                            expectedFragment: synonym.expected,
                            spokenFragment: synonym.spoken
                        )
                    )
                }
            }

            for issue in semantic.issues {
                let kind: ComparisonToken.TokenKind
                switch issue.type {
                case "missing":
                    kind = .missing
                case "extra":
                    kind = .extra
                case "mismatch", "grammar":
                    kind = .mismatch
                default:
                    kind = .mismatch
                }

                items.append(
                    FeedbackItem(
                        kind: kind,
                        message: issue.feedback,
                        expectedFragment: issue.expected,
                        spokenFragment: issue.spoken
                    )
                )
            }
        }

        if items.isEmpty {
            for token in lexical.spokenTokens where token.kind == .mismatch {
                items.append(
                    FeedbackItem(
                        kind: .mismatch,
                        message: "'\(token.text)' 대신 '\(token.pairedText ?? "")'를 기대했어요.",
                        expectedFragment: token.pairedText,
                        spokenFragment: token.text
                    )
                )
            }
        }

        return items
    }

    private func defaultSummary(for score: Int) -> String {
        switch score {
        case 80...:
            "단어 일치도가 높아요. 잘하고 있어요!"
        case 50..<80:
            "몇몇 표현이 달라요. 기대 문장과 한 번 더 비교해 보세요."
        default:
            "기대 문장과 차이가 있어요. 한국어 문장을 떠올리며 다시 말해 보세요."
        }
    }
}