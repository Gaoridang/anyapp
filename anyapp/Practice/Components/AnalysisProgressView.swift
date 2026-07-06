//
//  AnalysisProgressView.swift
//  anyapp
//

import SwiftUI

struct AnalysisProgressView: View {
    let phase: SpeakingPracticeSession.AnalysisPhase

    private var checklist: [(title: String, state: ChecklistState)] {
        [
            ("번역 생성", state(for: .translating)),
            ("단어 비교", state(for: .comparingLexical)),
            ("의미 분석", state(for: .comparingSemantic)),
        ]
    }

    var body: some View {
        VStack(spacing: 28) {
            ProgressView()
                .controlSize(.large)

            Text("비교 결과를 준비하고 있어요")
                .font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(checklist.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: item.state))
                            .foregroundStyle(color(for: item.state))
                            .contentTransition(.symbolEffect(.replace))

                        Text(item.title)
                            .foregroundStyle(item.state == .pending ? .secondary : .primary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .padding(.horizontal, 24)
    }

    private enum ChecklistState {
        case pending
        case active
        case done
    }

    private func state(for target: SpeakingPracticeSession.AnalysisPhase) -> ChecklistState {
        switch phase {
        case .failed:
            return .pending
        case .translating:
            return target == .translating ? .active : .pending
        case .comparingLexical:
            if target == .translating { return .done }
            return target == .comparingLexical ? .active : .pending
        case .comparingSemantic, .done:
            if target == .comparingSemantic { return phase == .done ? .done : .active }
            return .done
        case .idle:
            return .pending
        }
    }

    private func icon(for state: ChecklistState) -> String {
        switch state {
        case .pending:
            "circle"
        case .active:
            "ellipsis.circle"
        case .done:
            "checkmark.circle.fill"
        }
    }

    private func color(for state: ChecklistState) -> Color {
        switch state {
        case .pending:
            .secondary
        case .active:
            .accentColor
        case .done:
            .green
        }
    }
}