//
//  TopSegmentNavigator.swift
//  anyapp
//

import SwiftUI

enum RootTab: Int, CaseIterable, Identifiable, Hashable {
    case memo = 0
    case shadowing = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .memo:
            "메모"
        case .shadowing:
            "쉐도잉"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .memo:
            "memoTab"
        case .shadowing:
            "shadowingTab"
        }
    }
}

enum TopSegmentNavigatorStyle {
    case standalone
    case navigationBar
}

struct TopSegmentNavigator: View {
    @Binding var selection: RootTab
    var style: TopSegmentNavigatorStyle = .standalone
    @Namespace private var indicatorNamespace

    var body: some View {
        HStack(spacing: style == .navigationBar ? 4 : 8) {
            ForEach(RootTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        selection = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(tabFont(isSelected: selection == tab))
                        .foregroundStyle(selection == tab ? Color.primary : Color.secondary)
                        .padding(.horizontal, style == .navigationBar ? 14 : 18)
                        .padding(.vertical, style == .navigationBar ? 6 : 10)
                        .background {
                            if selection == tab {
                                Capsule()
                                    .fill(Color(.secondarySystemFill))
                                    .matchedGeometryEffect(id: "segmentIndicator", in: indicatorNamespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(tab.accessibilityIdentifier)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(style == .navigationBar ? 3 : 4)
        .background(Color(.tertiarySystemFill), in: Capsule())
        .frame(maxWidth: style == .navigationBar ? 220 : nil)
        .padding(.horizontal, style == .standalone ? 20 : 0)
        .padding(.top, style == .standalone ? 8 : 0)
        .padding(.bottom, style == .standalone ? 6 : 0)
        .accessibilityIdentifier("topSegmentNavigator")
    }

    private func tabFont(isSelected: Bool) -> Font {
        switch style {
        case .standalone:
            .subheadline.weight(isSelected ? .semibold : .medium)
        case .navigationBar:
            .subheadline.weight(isSelected ? .semibold : .medium)
        }
    }
}

#Preview {
    @Previewable @State var selection = RootTab.memo
    TopSegmentNavigator(selection: $selection)
}
