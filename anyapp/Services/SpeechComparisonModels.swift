//
//  SpeechComparisonModels.swift
//  anyapp
//

import Foundation

struct ComparisonToken: Equatable, Identifiable, Sendable {
    let id: UUID
    let text: String
    let kind: TokenKind
    let pairedText: String?

    enum TokenKind: String, Sendable {
        case match
        case synonym
        case mismatch
        case missing
        case extra
    }

    init(id: UUID = UUID(), text: String, kind: TokenKind, pairedText: String? = nil) {
        self.id = id
        self.text = text
        self.kind = kind
        self.pairedText = pairedText
    }
}

struct FeedbackItem: Equatable, Identifiable, Sendable {
    let id: UUID
    let kind: ComparisonToken.TokenKind
    let message: String
    let expectedFragment: String?
    let spokenFragment: String?

    init(
        id: UUID = UUID(),
        kind: ComparisonToken.TokenKind,
        message: String,
        expectedFragment: String? = nil,
        spokenFragment: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.message = message
        self.expectedFragment = expectedFragment
        self.spokenFragment = spokenFragment
    }
}

struct SpeechComparisonResult: Equatable, Sendable {
    let lexicalScore: Int
    let semanticScore: Int?
    let overallScore: Int
    let expectedEnglish: String
    let spokenEnglish: String
    let expectedTokens: [ComparisonToken]
    let spokenTokens: [ComparisonToken]
    let feedbackItems: [FeedbackItem]
    let summary: String
    let usedSemanticAnalysis: Bool
}

enum PracticeLocale {
    static let korean = Locale(identifier: "ko-KR")
    static let english = Locale(identifier: "en-US")
}