//
//  ContentView.swift
//  anyapp
//
//  Created by ijaejun on 6/25/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Binding var selectedTab: RootTab
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedItemID: PersistentIdentifier?
    @State private var navigationPath = NavigationPath()
    @State private var showAPIKeySettings = false

    var body: some View {
        if horizontalSizeClass == .compact {
            phoneNavigation
        } else {
            tabletNavigation
        }
    }

    /// iPhone fallback when not hosted by RootPhoneShell.
    private var phoneNavigation: some View {
        NavigationStack(path: $navigationPath) {
            itemList
                .toolbar(.hidden, for: .navigationBar)
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

    /// iPad: sidebar selection + detail column (no NavigationLink push in sidebar).
    private var tabletNavigation: some View {
        NavigationSplitView {
            Group {
                switch selectedTab {
                case .memo:
                    itemList
                case .shadowing:
                    ShadowingView(
                        selectedTab: $selectedTab,
                        onShowSettings: { showAPIKeySettings = true }
                    )
                }
            }
        } detail: {
            if selectedTab == .memo {
                if let selectedItemID,
                   let item = modelContext.model(for: selectedItemID) as? Item {
                    ItemDetailView(item: item)
                } else {
                    ContentUnavailableView(
                        "메모 없음",
                        systemImage: "note.text",
                        description: Text("왼쪽에서 메모를 선택하거나 +를 눌러 새 메모를 만드세요.")
                    )
                }
            } else {
                ContentUnavailableView(
                    "쉐도잉",
                    systemImage: "text.bubble",
                    description: Text("왼쪽에서 쉐도잉 연습을 시작하세요.")
                )
            }
        }
        .sheet(isPresented: $showAPIKeySettings) {
            APIKeySettingsView()
        }
    }

    private var itemList: some View {
        MemoListView(
            navigationPath: $navigationPath,
            selectedItemID: $selectedItemID,
            selectedTab: $selectedTab,
            showsNavigationLinks: horizontalSizeClass == .compact,
            onShowSettings: { showAPIKeySettings = true },
            onAddMemo: addItem
        )
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
            try? modelContext.save()
            selectedItemID = newItem.persistentModelID
            if horizontalSizeClass == .compact {
                navigationPath.append(newItem.persistentModelID)
            }
        }
    }
}

#Preview {
    ContentView(selectedTab: .constant(.memo))
        .modelContainer(for: Item.self, inMemory: true)
}
