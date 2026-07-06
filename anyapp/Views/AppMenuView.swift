//
//  AppMenuView.swift
//  anyapp
//

import SwiftUI

struct AppMenuView: View {
    @Binding var selectedTab: RootTab
    var onShowSettings: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("메뉴")
                .font(.largeTitle.bold())
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

            List {
                Section("기능") {
                    ForEach(RootTab.allCases) { tab in
                        Button {
                            selectedTab = tab
                            onClose()
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
                        onClose()
                        onShowSettings()
                    } label: {
                        Label("Grok API 키", systemImage: "key")
                    }
                    .accessibilityIdentifier("apiSettingsButton")
                }
            }
            .listStyle(.insetGrouped)
        }
        .accessibilityIdentifier("appMenuView")
    }
}

private enum AppMenuPlaceholder: String, CaseIterable, Identifiable {
    case comingSoon

    var id: String { rawValue }

    var title: String { "곧 추가될 기능" }

    var icon: String { "ellipsis.circle" }
}

#Preview {
    AppMenuView(selectedTab: .constant(.memo), onShowSettings: {}, onClose: {})
}
