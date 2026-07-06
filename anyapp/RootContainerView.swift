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

/// iPhone root: one NavigationStack and one toolbar so the segment control stays
/// fixed while memo/shadowing pages swipe underneath.
private struct RootPhoneShell: View {
    @Binding var selectedTab: RootTab?
    @Environment(\.modelContext) private var modelContext

    @State private var navigationPath = NavigationPath()
    @State private var selectedItemID: PersistentIdentifier?
    @State private var showAPIKeySettings = false

    private var selectedTabBinding: Binding<RootTab> {
        Binding(
            get: { selectedTab ?? .memo },
            set: { selectedTab = $0 }
        )
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            tabPager
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppMenuRoute.self) { _ in
                    AppMenuView(
                        selectedTab: selectedTabBinding,
                        onShowSettings: { showAPIKeySettings = true }
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
    }

    private var tabPager: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    MemoListView(
                        navigationPath: $navigationPath,
                        selectedItemID: $selectedItemID,
                        showsNavigationLinks: true,
                        onAddMemo: addMemo
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .id(RootTab.memo)

                    ShadowingView(
                        selectedTab: selectedTabBinding,
                        onShowSettings: { showAPIKeySettings = true },
                        onOpenMenu: { navigationPath.append(AppMenuRoute.menu) }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .id(RootTab.shadowing)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $selectedTab)
        }
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
