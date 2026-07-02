//
//  ContentView.swift
//  anyapp
//
//  Created by ijaejun on 6/25/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]
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

    /// iPhone: single NavigationStack so ItemDetailView is never duplicated.
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
        List(selection: horizontalSizeClass == .compact ? nil : $selectedItemID) {
            ForEach(items) { item in
                if horizontalSizeClass == .compact {
                    NavigationLink(value: item.persistentModelID) {
                        ItemRowView(item: item)
                    }
                } else {
                    ItemRowView(item: item)
                        .tag(item.persistentModelID)
                }
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle("메모")
        .toolbar {
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

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                items[index].deleteAudioFile()
                modelContext.delete(items[index])
            }
            if let selectedItemID,
               !items.contains(where: { $0.persistentModelID == selectedItemID }) {
                self.selectedItemID = nil
            }
            navigationPath = NavigationPath()
        }
    }
}

private struct ItemRowView: View {
    let item: Item

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.timestamp, format: .dateTime.day().month().year().hour().minute())
                    .font(.body)

                if !item.textNote.isEmpty {
                    Text(item.textNote)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                if item.audioFileName != nil {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !item.textNote.isEmpty {
                    Image(systemName: "text.alignleft")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
