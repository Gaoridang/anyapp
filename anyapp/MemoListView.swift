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

    @State private var searchText = ""

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing ?? false
    }

    private var filteredItems: [Item] {
        MemoListGrouping.filtered(items, query: searchText)
    }

    private var sections: [(title: String, dayStart: Date, items: [Item])] {
        MemoListGrouping.sections(from: filteredItems)
    }

    var body: some View {
        Group {
            if items.isEmpty {
                ContentUnavailableView(
                    "메모가 없습니다",
                    systemImage: "note.text",
                    description: Text("오른쪽 위 + 버튼으로 새 메모를 만들어 보세요")
                )
            } else if filteredItems.isEmpty {
                ContentUnavailableView(
                    "검색 결과 없음",
                    systemImage: "magnifyingglass",
                    description: Text("다른 검색어를 입력해 보세요")
                )
                .searchable(text: $searchText, prompt: "메모 검색")
            } else {
                List(selection: showsNavigationLinks ? nil : $selectedItemID) {
                    ForEach(sections, id: \.dayStart) { section in
                        Section(section.title) {
                            if allowsSwipeToDelete || isEditing {
                                ForEach(section.items) { item in
                                    row(for: item)
                                }
                                .onDelete { offsets in
                                    deleteItems(offsets, in: section.items)
                                }
                            } else {
                                ForEach(section.items) { item in
                                    row(for: item)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
                .contentMargins(.top, 8, for: .scrollContent)
                .safeAreaPadding(.bottom)
                .searchable(text: $searchText, prompt: "메모 검색")
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

    private func deleteItems(_ offsets: IndexSet, in sectionItems: [Item]) {
        let itemsToDelete = offsets.map { sectionItems[$0] }
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
            Image(systemName: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.orange)
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
