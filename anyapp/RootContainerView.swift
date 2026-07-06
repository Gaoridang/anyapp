//
//  RootContainerView.swift
//  anyapp
//

import SwiftUI
import SwiftData

struct RootContainerView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: RootTab = .memo

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                RootPhoneShell(selectedTab: $selectedTab)
            } else {
                ContentView(selectedTab: $selectedTab)
            }
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("rootContainer")
    }
}

/// iPhone root: Grok-style horizontal pager — Menu ← Memo → Shadowing → Practice.
/// Each page uses a native NavigationStack header that slides with the page.
private struct RootPhoneShell: View {
    @Binding var selectedTab: RootTab
    @Environment(\.modelContext) private var modelContext

    @State private var navigationPath = NavigationPath()
    @State private var selectedItemID: PersistentIdentifier?
    @State private var showAPIKeySettings = false
    @State private var hapticsReady = false

    var body: some View {
        tabPager
            .sheet(isPresented: $showAPIKeySettings) {
                APIKeySettingsView()
            }
            .onChange(of: selectedTab) { oldTab, newTab in
                guard hapticsReady, oldTab != newTab else { return }
                RootPagerHaptics.pageChanged()
            }
            .onAppear {
                hapticsReady = true
            }
    }

    private var pagerTabPosition: Binding<RootTab?> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if let newValue {
                    selectedTab = newValue
                }
            }
        )
    }

    private var tabPager: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                RootMenuPage(
                    selectedTab: $selectedTab,
                    onShowSettings: { showAPIKeySettings = true }
                )
                .containerRelativeFrame(.horizontal)
                .id(RootTab.menu)

                RootMemoPage(
                    selectedTab: $selectedTab,
                    navigationPath: $navigationPath,
                    selectedItemID: $selectedItemID,
                    onAddMemo: addMemo
                )
                .containerRelativeFrame(.horizontal)
                .id(RootTab.memo)

                RootShadowingPage(
                    selectedTab: $selectedTab,
                    onShowSettings: { showAPIKeySettings = true }
                )
                .containerRelativeFrame(.horizontal)
                .id(RootTab.shadowing)

                RootSpeakingPracticePage(selectedTab: $selectedTab)
                    .containerRelativeFrame(.horizontal)
                    .id(RootTab.speakingPractice)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: pagerTabPosition)
        .scrollDisabled(!navigationPath.isEmpty)
        .scrollClipDisabled()
    }

    func addMemo() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
            try? modelContext.save()
            selectedItemID = newItem.persistentModelID
            navigationPath.append(newItem.persistentModelID)
        }
    }
}

#Preview {
    RootContainerView()
        .modelContainer(for: Item.self, inMemory: true)
}