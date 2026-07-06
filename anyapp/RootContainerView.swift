//
//  RootContainerView.swift
//  anyapp
//

import SwiftUI
import SwiftData

struct RootContainerView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: RootTab? = .memo

    private var selectedTabBinding: Binding<RootTab> {
        Binding(
            get: { selectedTab ?? .memo },
            set: { selectedTab = $0 }
        )
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                RootPhoneShell(selectedTab: $selectedTab)
            } else {
                ContentView(selectedTab: selectedTabBinding)
            }
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("rootContainer")
    }
}

/// iPhone root: one NavigationStack and one toolbar so the title stays fixed while
/// memo/shadowing pages swipe underneath.
private struct RootPhoneShell: View {
    @Binding var selectedTab: RootTab?
    @Environment(\.modelContext) private var modelContext

    @State private var navigationPath = NavigationPath()
    @State private var selectedItemID: PersistentIdentifier?
    @State private var showMenu = false
    @State private var showAPIKeySettings = false

    private var activeTab: RootTab {
        selectedTab ?? .memo
    }

    private var selectedTabBinding: Binding<RootTab> {
        Binding(
            get: { selectedTab ?? .memo },
            set: { selectedTab = $0 }
        )
    }

    var body: some View {
        SideMenuDrawer(isPresented: $showMenu) {
            NavigationStack(path: $navigationPath) {
                tabPager
                    .navigationTitle(activeTab.title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(.automatic, for: .navigationBar)
                    .toolbar {
                        RootNavigationToolbar(
                            showMenu: $showMenu,
                            activeTab: activeTab,
                            onAddMemo: addMemo
                        )
                    }
                    .navigationDestination(for: PersistentIdentifier.self) { id in
                        if let item = modelContext.model(for: id) as? Item {
                            ItemDetailView(item: item)
                        }
                    }
            }
            .sheet(isPresented: $showAPIKeySettings) {
                APIKeySettingsView()
            }
        } menu: {
            AppMenuView(
                selectedTab: selectedTabBinding,
                onShowSettings: {
                    showMenu = false
                    showAPIKeySettings = true
                },
                onClose: { showMenu = false }
            )
        }
    }

    private var tabPager: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    MemoListView(
                        navigationPath: $navigationPath,
                        selectedItemID: $selectedItemID,
                        showsNavigationLinks: true
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .id(RootTab.memo)

                    ShadowingView(
                        onShowSettings: { showAPIKeySettings = true }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .id(RootTab.shadowing)

                    SpeakingPracticeView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .id(RootTab.speakingPractice)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $selectedTab)
        }
    }

    func addMemo() {
        guard activeTab == .memo else { return }
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
