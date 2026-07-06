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
                .navigationDestination(for: PersistentIdentifier.self) { id in
                    if let item = modelContext.model(for: id) as? Item {
                        ItemDetailView(item: item)
                    }
                }
        }
    }

    /// iPad: sidebar selection + detail column (no NavigationLink push in sidebar).
    private var tabletNavigation: some View {
        NavigationSplitView {
            itemList
        } detail: {
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
        }
    }

    private var itemList: some View {
        MemoListView(
            navigationPath: $navigationPath,
            selectedItemID: $selectedItemID,
            showsNavigationLinks: horizontalSizeClass == .compact
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TopSegmentNavigator(selection: $selectedTab, style: .navigationBar)
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
            }
            ToolbarItem {
                Button(action: addItem) {
                    Label("새 메모", systemImage: "plus")
                }
                .accessibilityIdentifier("addMemoButton")
            }
        }
        .sheet(isPresented: $showAPIKeySettings) {
            APIKeySettingsView()
        }
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
