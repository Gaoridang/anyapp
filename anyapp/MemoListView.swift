//
//  MemoListView.swift
//  anyapp
//

import SwiftData
import SwiftUI

struct MemoListView: View {
    @Environment(\.editMode) private var editMode
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Item.timestamp, order: .reverse) private var items: [Item]

    @Binding var navigationPath: NavigationPath
    @Binding var selectedItemID: PersistentIdentifier?
    var showsNavigationLinks: Bool
    /// Swipe-to-delete conflicts with the root horizontal pager; keep edit-mode delete.
    var allowsSwipeToDelete: Bool = true

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing ?? false
    }

    var body: some View {
        List(selection: showsNavigationLinks ? nil : $selectedItemID) {
            if allowsSwipeToDelete || isEditing {
                ForEach(items) { item in
                    row(for: item)
                }
                .onDelete(perform: deleteItems)
            } else {
                ForEach(items) { item in
                    row(for: item)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .contentMargins(.top, 8, for: .scrollContent)
        .safeAreaPadding(.bottom)
    }

    @ViewBuilder
    private func row(for item: Item) -> some View {
        if showsNavigationLinks {
            NavigationLink(value: item.persistentModelID) {
                ItemRowView(item: item)
            }
        } else {
            ItemRowView(item: item)
                .tag(item.persistentModelID)
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
            showsNavigationLinks: true
        )
        .navigationTitle("메모")
    }
    .modelContainer(for: Item.self, inMemory: true)
}
