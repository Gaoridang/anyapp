//
//  LexicalComparator.swift
//  anyapp
//

import Foundation

struct LexicalComparisonResult: Equatable, Sendable {
    let score: Int
    let expectedTokens: [ComparisonToken]
    let spokenTokens: [ComparisonToken]
}

enum LexicalComparator {
    static func compare(expected: String, spoken: String) -> LexicalComparisonResult {
        let expectedWords = tokenize(expected)
        let spokenWords = tokenize(spoken)
        let aligned = align(expected: expectedWords, spoken: spokenWords)

        var expectedTokens: [ComparisonToken] = []
        var spokenTokens: [ComparisonToken] = []
        var matchCount = 0

        for item in aligned {
            switch item {
            case .match(let word):
                let token = ComparisonToken(text: word, kind: .match)
                expectedTokens.append(token)
                spokenTokens.append(token)
                matchCount += 1
            case .missing(let word):
                expectedTokens.append(ComparisonToken(text: word, kind: .missing))
            case .extra(let word):
                spokenTokens.append(ComparisonToken(text: word, kind: .extra))
            case .mismatch(let expectedWord, let spokenWord):
                expectedTokens.append(
                    ComparisonToken(text: expectedWord, kind: .mismatch, pairedText: spokenWord)
                )
                spokenTokens.append(
                    ComparisonToken(text: spokenWord, kind: .mismatch, pairedText: expectedWord)
                )
            }
        }

        let denominator = max(expectedWords.count, 1)
        let score = Int((Double(matchCount) / Double(denominator) * 100).rounded())

        return LexicalComparisonResult(
            score: min(max(score, 0), 100),
            expectedTokens: expectedTokens,
            spokenTokens: spokenTokens
        )
    }

    static func tokenize(_ text: String) -> [String] {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: #"[^\w\s']"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return [] }
        return normalized.split(separator: " ").map(String.init)
    }

    private enum AlignedItem: Equatable {
        case match(String)
        case missing(String)
        case extra(String)
        case mismatch(expected: String, spoken: String)
    }

    private enum DiffOperation: Equatable {
        case equal(String)
        case delete(String)
        case insert(String)
    }

    private static func align(expected: [String], spoken: [String]) -> [AlignedItem] {
        let operations = diffOperations(expected: expected, spoken: spoken)
        var aligned: [AlignedItem] = []
        var index = 0

        while index < operations.count {
            if index + 1 < operations.count,
               case .delete(let expectedWord) = operations[index],
               case .insert(let spokenWord) = operations[index + 1] {
                aligned.append(.mismatch(expected: expectedWord, spoken: spokenWord))
                index += 2
                continue
            }

            switch operations[index] {
            case .equal(let word):
                aligned.append(.match(word))
            case .delete(let word):
                aligned.append(.missing(word))
            case .insert(let word):
                aligned.append(.extra(word))
            }
            index += 1
        }

        return aligned
    }

    private static func diffOperations(expected: [String], spoken: [String]) -> [DiffOperation] {
        let rowCount = expected.count + 1
        let columnCount = spoken.count + 1
        var lengths = Array(repeating: Array(repeating: 0, count: columnCount), count: rowCount)

        if !expected.isEmpty && !spoken.isEmpty {
            for row in 1..<rowCount {
                for column in 1..<columnCount {
                    if expected[row - 1] == spoken[column - 1] {
                        lengths[row][column] = lengths[row - 1][column - 1] + 1
                    } else {
                        lengths[row][column] = max(lengths[row - 1][column], lengths[row][column - 1])
                    }
                }
            }
        }

        var operations: [DiffOperation] = []
        var row = expected.count
        var column = spoken.count

        while row > 0 || column > 0 {
            if row > 0, column > 0, expected[row - 1] == spoken[column - 1] {
                operations.append(.equal(expected[row - 1]))
                row -= 1
                column -= 1
            } else if column > 0, row == 0 || lengths[row][column - 1] >= lengths[row - 1][column] {
                operations.append(.insert(spoken[column - 1]))
                column -= 1
            } else {
                operations.append(.delete(expected[row - 1]))
                row -= 1
            }
        }

        return operations.reversed()
    }
}