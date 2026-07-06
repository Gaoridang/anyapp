//
//  RootContainerView.swift
//  anyapp
//

import SwiftUI
import SwiftData

struct RootContainerView: View {
    @State private var selectedTab: RootTab? = .memo

    private let pageTransition = Animation.spring(response: 0.38, dampingFraction: 0.86)

    private var selectedTabBinding: Binding<RootTab> {
        Binding(
            get: { selectedTab ?? .memo },
            set: { selectedTab = $0 }
        )
    }

    var body: some View {
        // Use ScrollView paging instead of TabView(.page). UIPageViewController
        // breaks the keyboard safe-area animation chain for ItemDetailView's
        // bottom input toolbar, so the bar and content jump instead of tracking
        // the keyboard.
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ContentView(selectedTab: selectedTabBinding)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .id(RootTab.memo)
                        .rootPageTransition()

                    ShadowingView(selectedTab: selectedTabBinding)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .id(RootTab.shadowing)
                        .rootPageTransition()
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $selectedTab)
            .scrollClipDisabled()
        }
        .animation(pageTransition, value: selectedTab)
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("rootContainer")
    }
}

private extension View {
    func rootPageTransition() -> some View {
        scrollTransition(.animated(.spring(response: 0.38, dampingFraction: 0.86))) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.9)
                .scaleEffect(phase.isIdentity ? 1 : 0.985)
        }
    }
}

#Preview {
    RootContainerView()
        .modelContainer(for: Item.self, inMemory: true)
}
