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
    @State private var selectedItemID: PersistentIdentifier?
    @State private var navigationPath = NavigationPath()
    @State private var showAPIKeySettings = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailColumn
        }
        .sheet(isPresented: $showAPIKeySettings) {
            APIKeySettingsView()
        }
    }

    private var sidebar: some View {
        List {
            Section("기능") {
                ForEach(RootTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack {
                            Label(tab.title, systemImage: tab.menuIcon)
                            Spacer()
                            if selectedTab == tab {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier(tab.accessibilityIdentifier)
                }
            }

            Section {
                Button {
                    showAPIKeySettings = true
                } label: {
                    Label("Grok API 키", systemImage: "key")
                }
                .accessibilityIdentifier("apiSettingsButton")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("기능")
        .toolbar {
            if selectedTab == .memo {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: addItem) {
                        Label("새 메모", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addMemoButton")
                }
            }
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        switch selectedTab {
        case .memo:
            NavigationStack(path: $navigationPath) {
                itemList
                    .navigationTitle("메모")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationDestination(for: PersistentIdentifier.self) { id in
                        if let item = modelContext.model(for: id) as? Item {
                            ItemDetailView(item: item)
                        }
                    }
            }
        case .shadowing:
            ShadowingView(onShowSettings: { showAPIKeySettings = true })
        }
    }

    private var itemList: some View {
        MemoListView(
            navigationPath: $navigationPath,
            selectedItemID: $selectedItemID,
            showsNavigationLinks: true
        )
    }

    private func addItem() {
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
    ContentView(selectedTab: .constant(.memo))
        .modelContainer(for: Item.self, inMemory: true)
}
