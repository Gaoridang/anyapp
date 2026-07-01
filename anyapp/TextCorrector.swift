//
//  TextCorrector.swift
//  anyapp
//

import Foundation
import FoundationModels

enum TextCorrector {
    nonisolated static func correct(_ rawText: String) async -> String {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }

        if let corrected = await correctWithFoundationModel(trimmed) {
            return corrected
        }

        return applyRuleBasedCorrection(trimmed)
    }

    private nonisolated static func correctWithFoundationModel(_ text: String) async -> String? {
        let model = SystemLanguageModel.default

        guard case .available = model.availability else {
            return nil
        }

        do {
            let session = LanguageModelSession(instructions: """
            다음은 음성 인식 결과입니다. 오인식된 단어를 수정하고, 자연스러운 한국어 문장으로 다듬어 주세요. \
            의미를 바꾸지 말고 원문 길이를 크게 늘리지 마세요. 보정된 텍스트만 출력하세요.
            """)

            let response = try await session.respond(to: text)
            let corrected = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return corrected.isEmpty ? nil : corrected
        } catch {
            return nil
        }
    }

    private nonisolated static func applyRuleBasedCorrection(_ text: String) -> String {
        var result = text

        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"([가-힣])\s+([,.!?])"#, with: "$1$2", options: .regularExpression)
        result = result.replacingOccurrences(of: #"([,.!?])([가-힣])"#, with: "$1 $2", options: .regularExpression)

        if let last = result.last, !".!?".contains(last) {
            result += "."
        }

        if let first = result.first, first.isLowercase {
            result.replaceSubrange(result.startIndex...result.startIndex, with: String(first).uppercased())
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
