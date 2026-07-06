//
//  LexicalComparatorTests.swift
//  anyappTests
//

import Testing
@testable import anyapp

struct LexicalComparatorTests {
    @Test func compareExactMatchScoresHighly() {
        let result = LexicalComparator.compare(
            expected: "The weather is nice today.",
            spoken: "The weather is nice today."
        )

        #expect(result.score == 100)
        #expect(result.spokenTokens.allSatisfy { $0.kind == .match })
    }

    @Test func compareDetectsMismatchAndExtraWords() {
        let result = LexicalComparator.compare(
            expected: "The weather is nice today",
            spoken: "The weather is good today really"
        )

        #expect(result.score < 100)
        #expect(result.spokenTokens.contains { $0.kind == .mismatch })
        #expect(result.spokenTokens.contains { $0.kind == .extra })
    }

    @Test func compareDetectsMissingWords() {
        let result = LexicalComparator.compare(
            expected: "I want some coffee",
            spoken: "I want coffee"
        )

        #expect(result.expectedTokens.contains { $0.kind == .missing })
    }
}