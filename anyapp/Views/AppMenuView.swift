//
//  AppMenuView.swift
//  anyapp
//

import SwiftUI

struct AppMenuView: View {
    @Binding var selectedTab: RootTab
    var onShowSettings: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("기능") {
                    ForEach(RootTab.allCases) { tab in
                        Button {
                            selectedTab = tab
                            dismiss()
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

                    ForEach(AppMenuPlaceholder.allCases) { placeholder in
                        Label(placeholder.title, systemImage: placeholder.icon)
                            .foregroundStyle(.tertiary)
                    }
                }

                Section {
                    Button {
                        dismiss()
                        onShowSettings()
                    } label: {
                        Label("설정", systemImage: "key")
                    }
                    .accessibilityIdentifier("apiSettingsButton")
                }
            }
            .navigationTitle("메뉴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private enum AppMenuPlaceholder: String, CaseIterable, Identifiable {
    case comingSoon

    var id: String { rawValue }

    var title: String { "곧 추가될 기능" }

    var icon: String { "ellipsis.circle" }
}

#Preview {
    @Previewable @State var selectedTab = RootTab.memo
    AppMenuView(selectedTab: $selectedTab, onShowSettings: {})
}
