//
//  RootContainerView.swift
//  anyapp
//

import SwiftUI

struct RootContainerView: View {
    @State private var selectedTab: RootTab = .memo

    var body: some View {
        VStack(spacing: 0) {
            TopSegmentNavigator(selection: $selectedTab)

            TabView(selection: $selectedTab) {
                ContentView()
                    .tag(RootTab.memo)

                ShadowingView()
                    .tag(RootTab.shadowing)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("rootContainer")
    }
}

#Preview {
    RootContainerView()
        .modelContainer(for: Item.self, inMemory: true)
}
