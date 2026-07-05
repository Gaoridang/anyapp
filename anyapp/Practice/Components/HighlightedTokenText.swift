//
//  HighlightedTokenText.swift
//  anyapp
//

import SwiftUI

struct HighlightedTokenText: View {
    let tokens: [ComparisonToken]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedCount = 0

    var body: some View {
        FlowLayout(spacing: 6, lineSpacing: 8) {
            ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                tokenView(token)
                    .opacity(shouldReveal(index) ? 1 : 0)
                    .scaleEffect(shouldReveal(index) ? 1 : 0.85)
                    .animation(revealAnimation(for: index), value: revealedCount)
            }
        }
        .onAppear(perform: revealTokens)
        .onChange(of: tokens.map(\.id)) { _, _ in
            revealedCount = 0
            revealTokens()
        }
    }

    @ViewBuilder
    private func tokenView(_ token: ComparisonToken) -> some View {
        Text(token.text)
            .font(.body.weight(token.kind == .missing ? .regular : .medium))
            .italic(token.kind == .missing)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(backgroundColor(for: token.kind), in: RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .bottom) {
                if token.kind == .missing {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(height: 1)
                        .padding(.horizontal, 2)
                        .offset(y: 2)
                }
            }
            .modifier(MismatchShakeModifier(isActive: token.kind == .mismatch && shouldRevealAll))
            .accessibilityLabel(accessibilityLabel(for: token))
    }

    private func backgroundColor(for kind: ComparisonToken.TokenKind) -> Color {
        switch kind {
        case .match:
            Color.green.opacity(0.18)
        case .synonym:
            Color.blue.opacity(0.18)
        case .mismatch:
            Color.red.opacity(0.18)
        case .missing:
            Color.gray.opacity(0.12)
        case .extra:
            Color.yellow.opacity(0.22)
        }
    }

    private func accessibilityLabel(for token: ComparisonToken) -> String {
        switch token.kind {
        case .match:
            "일치: \(token.text)"
        case .synonym:
            "유사 표현: \(token.text), 기대: \(token.pairedText ?? "")"
        case .mismatch:
            "다름: \(token.text), 기대: \(token.pairedText ?? "")"
        case .missing:
            "누락: \(token.text)"
        case .extra:
            "추가: \(token.text)"
        }
    }

    private var shouldRevealAll: Bool {
        revealedCount >= tokens.count
    }

    private func shouldReveal(_ index: Int) -> Bool {
        reduceMotion || index < revealedCount
    }

    private func revealAnimation(for index: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .spring(duration: 0.35).delay(Double(index) * 0.06)
    }

    private func revealTokens() {
        guard !reduceMotion else {
            revealedCount = tokens.count
            return
        }

        revealedCount = 0
        for index in tokens.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.06 + 0.05) {
                revealedCount = index + 1
            }
        }
    }
}

private struct MismatchShakeModifier: ViewModifier {
    let isActive: Bool
    @State private var shake = false

    func body(content: Content) -> some View {
        content
            .offset(x: shake ? 2 : 0)
            .onChange(of: isActive) { _, active in
                guard active else { return }
                withAnimation(.easeInOut(duration: 0.08).repeatCount(3, autoreverses: true)) {
                    shake.toggle()
                }
            }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var size = CGSize.zero

        for subview in subviews {
            let dimension = subview.sizeThatFits(.unspecified)
            if x > 0, x + dimension.width > maxWidth {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }

            rowHeight = max(rowHeight, dimension.height)
            x += dimension.width + spacing
            size.width = max(size.width, min(x, maxWidth))
            size.height = y + rowHeight
        }

        return size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let dimension = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + dimension.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(dimension)
            )
            x += dimension.width + spacing
            rowHeight = max(rowHeight, dimension.height)
        }
    }
}