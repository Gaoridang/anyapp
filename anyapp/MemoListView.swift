//
//  MemoListView.swift
//  anyapp
//

import SwiftData
import SwiftUI

struct MemoListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]

    @Binding var navigationPath: NavigationPath
    @Binding var selectedItemID: PersistentIdentifier?
    @Binding var selectedTab: RootTab
    var showsNavigationLinks: Bool
    var onShowSettings: () -> Void
    var onAddMemo: () -> Void

    @State private var showMenu = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderBar(
                title: "메모",
                selectedTab: $selectedTab,
                showMenu: $showMenu,
                onShowSettings: onShowSettings
            ) {
                EditButton()
                Button(action: onAddMemo) {
                    Label("새 메모", systemImage: "plus")
                }
                .accessibilityIdentifier("addMemoButton")
            }

            List(selection: showsNavigationLinks ? nil : $selectedItemID) {
                ForEach(items) { item in
                    if showsNavigationLinks {
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
            .listStyle(.insetGrouped)
            .contentMargins(.top, 8, for: .scrollContent)
            .safeAreaPadding(.bottom)
        }
        .simultaneousGesture(menuSwipeGesture)
        .sheet(isPresented: $showMenu) {
            AppMenuView(selectedTab: $selectedTab, onShowSettings: onShowSettings)
        }
    }

    private var menuSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard value.startLocation.x < 44 else { return }
                guard value.translation.width > 50 else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                showMenu = true
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

struct ItemRowView: View {
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
    NavigationStack {
        MemoListView(
            navigationPath: .constant(NavigationPath()),
            selectedItemID: .constant(nil),
            selectedTab: .constant(.memo),
            showsNavigationLinks: true,
            onShowSettings: {},
            onAddMemo: {}
        )
    }
    .modelContainer(for: Item.self, inMemory: true)
}
