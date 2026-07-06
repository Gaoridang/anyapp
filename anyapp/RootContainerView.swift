//
//  RootContainerView.swift
//  anyapp
//

import SwiftUI
import SwiftData

struct RootContainerView: View {
    @State private var selectedTab: RootTab = .memo

    var body: some View {
        VStack(spacing: 0) {
            TopSegmentNavigator(selection: $selectedTab)

            // Use ScrollView paging instead of TabView(.page). UIPageViewController
            // breaks the keyboard safe-area animation chain for ItemDetailView's
            // bottom input toolbar, so the bar and content jump instead of tracking
            // the keyboard.
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ContentView()
                        .containerRelativeFrame(.horizontal)
                        .containerRelativeFrame(.vertical)
                        .id(RootTab.memo)

                    ShadowingView()
                        .containerRelativeFrame(.horizontal)
                        .containerRelativeFrame(.vertical)
                        .id(RootTab.shadowing)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $selectedTab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("rootContainer")
    }
}

#Preview {
    RootContainerView()
        .modelContainer(for: Item.self, inMemory: true)
}
