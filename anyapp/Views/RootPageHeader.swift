//
//  RootPageHeader.swift
//  anyapp
//

import SwiftUI
import SwiftData
import UIKit

struct RootMenuPage: View {
    @Binding var selectedTab: RootTab
    var onShowSettings: () -> Void

    var body: some View {
        NavigationStack {
            AppMenuView(
                selectedTab: $selectedTab,
                onShowSettings: onShowSettings
            )
            .rootPageScrollTransition()
            .navigationTitle(RootTab.menu.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.automatic, for: .navigationBar)
        }
    }
}

struct RootMemoPage: View {
    @Binding var selectedTab: RootTab
    @Binding var navigationPath: NavigationPath
    @Binding var selectedItemID: PersistentIdentifier?
    var onAddMemo: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack(path: $navigationPath) {
            MemoListView(
                navigationPath: $navigationPath,
                selectedItemID: $selectedItemID,
                showsNavigationLinks: true
            )
            .rootPageScrollTransition()
            .navigationTitle(RootTab.memo.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar {
                RootMenuToolbarItem(selectedTab: $selectedTab)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: onAddMemo) {
                        Label("새 메모", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addMemoButton")
                }
            }
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let item = modelContext.model(for: id) as? Item {
                    ItemDetailView(item: item)
                }
            }
        }
    }
}

struct RootShadowingPage: View {
    @Binding var selectedTab: RootTab
    var onShowSettings: () -> Void

    var body: some View {
        NavigationStack {
            ShadowingView(onShowSettings: onShowSettings)
                .rootPageScrollTransition()
                .navigationTitle(RootTab.shadowing.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.automatic, for: .navigationBar)
                .toolbar {
                    RootMenuToolbarItem(selectedTab: $selectedTab)
                }
        }
    }
}

struct RootSpeakingPracticePage: View {
    @Binding var selectedTab: RootTab

    var body: some View {
        NavigationStack {
            SpeakingPracticeView()
                .rootPageScrollTransition()
                .navigationTitle(RootTab.speakingPractice.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.automatic, for: .navigationBar)
                .toolbar {
                    RootMenuToolbarItem(selectedTab: $selectedTab)
                }
        }
    }
}

struct RootMenuToolbarItem: ToolbarContent {
    @Binding var selectedTab: RootTab

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                withAnimation(.smooth(duration: 0.35)) {
                    selectedTab = .menu
                }
            } label: {
                Label("메뉴", systemImage: "line.3.horizontal")
            }
            .accessibilityIdentifier("appMenuButton")
        }
    }
}

enum RootPagerHaptics {
    static func pageChanged() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct RootPageScrollTransitionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                view
                    .opacity(phase.isIdentity ? 1 : 1 - min(abs(phase.value), 1) * 0.12)
            }
    }
}

extension View {
    func rootPageScrollTransition() -> some View {
        modifier(RootPageScrollTransitionModifier())
    }
}