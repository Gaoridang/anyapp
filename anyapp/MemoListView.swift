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
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "메모가 없습니다",
                    systemImage: "note.text",
                    description: Text("오른쪽 위 + 버튼으로 새 메모를 만들어 보세요")
                )
            } else {
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
        }
    }

    @ViewBuilder
    private func row(for item: Item) -> some View {
        if showsNavigationLinks {
            NavigationLink(value: item.persistentModelID) {
                ItemRowView(item: item)
            }
            .contextMenu {
                Button("삭제", role: .destructive) {
                    deleteItem(item)
                }
            }
        } else {
            ItemRowView(item: item)
                .tag(item.persistentModelID)
                .contextMenu {
                    Button("삭제", role: .destructive) {
                        deleteItem(item)
                    }
                }
        }
    }

    private func deleteItem(_ item: Item) {
        withAnimation {
            let deletedID = item.persistentModelID
            item.deleteAudioFile()
            modelContext.delete(item)
            if selectedItemID == deletedID {
                selectedItemID = nil
            }
            navigationPath = NavigationPath()
        }
    }

    private func deleteItems(offsets: IndexSet) {
        let itemsToDelete = offsets.map { items[$0] }
        for item in itemsToDelete {
            deleteItem(item)
        }
    }
}

struct ItemRowView: View {
    let item: Item

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.listTitle)
                    .font(.body)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(item.listSecondaryDateText)
                    if let duration = item.listDurationText {
                        Text("·")
                        Text(duration)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            trailingAccessory
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.listAccessibilityLabel)
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if item.needsTranscription {
            ProgressView()
                .controlSize(.mini)
                .accessibilityHidden(true)
        } else if item.audioFileName != nil, item.listDurationText == nil {
            Image(systemName: "waveform")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
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
