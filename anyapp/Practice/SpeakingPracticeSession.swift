//
//  SpeakingPracticeSession.swift
//  anyapp
//

import Foundation
import Observation

@Observable
@MainActor
final class SpeakingPracticeSession {
    enum Step: Int, CaseIterable {
        case korean
        case english
        case result
    }

    enum RecordPhase: Equatable {
        case idle
        case recording
        case transcribing
        case review
    }

    enum AnalysisPhase: Equatable {
        case idle
        case translating
        case comparingLexical
        case comparingSemantic
        case done
        case failed(String)

        var isAnalyzing: Bool {
            switch self {
            case .translating, .comparingLexical, .comparingSemantic:
                true
            default:
                false
            }
        }
    }

    var step: Step = .korean
    var koreanPhase: RecordPhase = .idle
    var englishPhase: RecordPhase = .idle
    var analysisPhase: AnalysisPhase = .idle

    var koreanText = ""
    var koreanTextDraft = ""
    var englishText = ""
    var englishTextDraft = ""
    var expectedEnglish = ""

    var koreanAudioURL: URL?
    var englishAudioURL: URL?

    var comparisonResult: SpeechComparisonResult?
    var showsSemanticFallbackNotice = false
    var errorMessage: String?

    private let sttRouter: STTRouter
    private let translationRouter: TranslationRouter
    private let comparisonEngine: SpeechComparisonEngine
    private let hasGrokKey: @Sendable () -> Bool

    init(
        sttRouter: STTRouter = STTRouter(),
        translationRouter: TranslationRouter = TranslationRouter(),
        comparisonEngine: SpeechComparisonEngine = SpeechComparisonEngine(),
        hasGrokKey: @escaping @Sendable () -> Bool = { GrokAPIKeyStore.hasKey }
    ) {
        self.sttRouter = sttRouter
        self.translationRouter = translationRouter
        self.comparisonEngine = comparisonEngine
        self.hasGrokKey = hasGrokKey
    }

    var aiStatusLabel: String {
        hasGrokKey() ? "Grok" : "기기 모드"
    }

    func resetForKoreanRetake() {
        cleanupAudio(at: koreanAudioURL)
        koreanAudioURL = nil
        koreanText = ""
        koreanTextDraft = ""
        koreanPhase = .idle
        errorMessage = nil
    }

    func resetForEnglishRetake() {
        cleanupAudio(at: englishAudioURL)
        englishAudioURL = nil
        englishText = ""
        englishTextDraft = ""
        englishPhase = .idle
        comparisonResult = nil
        expectedEnglish = ""
        analysisPhase = .idle
        showsSemanticFallbackNotice = false
        errorMessage = nil
    }

    func resetAll() {
        cleanupAudio(at: koreanAudioURL)
        cleanupAudio(at: englishAudioURL)
        koreanAudioURL = nil
        englishAudioURL = nil
        koreanText = ""
        koreanTextDraft = ""
        englishText = ""
        englishTextDraft = ""
        expectedEnglish = ""
        comparisonResult = nil
        step = .korean
        koreanPhase = .idle
        englishPhase = .idle
        analysisPhase = .idle
        showsSemanticFallbackNotice = false
        errorMessage = nil
    }

    func handleRecordingFinished(url: URL, duration: TimeInterval, for step: Step) async {
        guard duration > 0 else {
            cleanupAudio(at: url)
            errorMessage = "녹음된 오디오가 없습니다. 다시 시도해 주세요."
            setPhase(.idle, for: step)
            return
        }

        switch step {
        case .korean:
            cleanupAudio(at: koreanAudioURL)
            koreanAudioURL = url
        case .english:
            cleanupAudio(at: englishAudioURL)
            englishAudioURL = url
        case .result:
            cleanupAudio(at: url)
            return
        }

        setPhase(.transcribing, for: step)
        errorMessage = nil

        do {
            let locale = step == .korean ? PracticeLocale.korean : PracticeLocale.english
            let text = try await sttRouter.transcribe(audioFileURL: url, locale: locale)
            switch step {
            case .korean:
                koreanText = text
                koreanTextDraft = text
            case .english:
                englishText = text
                englishTextDraft = text
            case .result:
                break
            }
            setPhase(.review, for: step)
        } catch {
            errorMessage = error.localizedDescription
            setPhase(.idle, for: step)
        }
    }

    func advanceFromKorean() {
        let trimmed = koreanTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        koreanText = trimmed
        step = .english
        errorMessage = nil
    }

    func runAnalysis() async {
        let trimmedEnglish = englishTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEnglish.isEmpty else { return }

        englishText = trimmedEnglish
        step = .result
        analysisPhase = .translating
        comparisonResult = nil
        showsSemanticFallbackNotice = false
        errorMessage = nil

        do {
            expectedEnglish = try await translationRouter.translateKoreanToEnglish(koreanText)
            analysisPhase = .comparingLexical

            if !hasGrokKey() {
                showsSemanticFallbackNotice = true
            }

            analysisPhase = .comparingSemantic
            let result = await comparisonEngine.compare(
                korean: koreanText,
                expectedEnglish: expectedEnglish,
                spokenEnglish: englishText
            )

            if !result.usedSemanticAnalysis {
                showsSemanticFallbackNotice = true
            }

            comparisonResult = result
            analysisPhase = .done
        } catch {
            analysisPhase = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func setPhase(_ phase: RecordPhase, for step: Step) {
        switch step {
        case .korean:
            koreanPhase = phase
        case .english:
            englishPhase = phase
        case .result:
            break
        }
    }

    private func cleanupAudio(at url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }
}