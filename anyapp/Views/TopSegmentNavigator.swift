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

struct TopSegmentNavigator: View {
    @Binding var selection: RootTab
    @Namespace private var indicatorNamespace

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RootTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                        selection = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.subheadline.weight(selection == tab ? .semibold : .medium))
                        .foregroundStyle(selection == tab ? Color.primary : Color.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
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
        .padding(4)
        .background(Color(.tertiarySystemFill), in: Capsule())
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .accessibilityIdentifier("topSegmentNavigator")
    }
}

#Preview {
    @Previewable @State var selection = RootTab.memo
    TopSegmentNavigator(selection: $selection)
}
