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
        if horizontalSizeClass == .compact {
            RootPhoneShell(selectedTab: $selectedTab)
        } else {
            ContentView(selectedTab: selectedTabBinding)
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
        NavigationStack(path: $navigationPath) {
            tabPager
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.automatic, for: .navigationBar)
                .toolbar { rootToolbar }
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
                        showsNavigationLinks: true
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .id(RootTab.memo)

                    ShadowingView()
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

    @ToolbarContentBuilder
    private var rootToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            TopSegmentNavigator(selection: selectedTabBinding, style: .navigationBar)
        }
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                showAPIKeySettings = true
            } label: {
                Label("설정", systemImage: "key")
            }
            .accessibilityIdentifier("apiSettingsButton")
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            EditButton()
                .disabled(activeTab != .memo)
                .opacity(activeTab == .memo ? 1 : 0.35)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: addMemo) {
                Label("새 메모", systemImage: "plus")
            }
            .accessibilityIdentifier("addMemoButton")
            .disabled(activeTab != .memo)
            .opacity(activeTab == .memo ? 1 : 0.35)
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
