//
//  AppMenuView.swift
//  anyapp
//

import SwiftUI

struct AppMenuView: View {
    @Binding var selectedTab: RootTab
    var onShowSettings: () -> Void

    var body: some View {
        List {
            Section("기능") {
                ForEach(RootTab.contentTabs) { tab in
                    Button {
                        withAnimation(.smooth(duration: 0.35)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack {
                            Label(tab.title, systemImage: tab.menuIcon)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedTab == tab {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(tab.accessibilityIdentifier)
                }

                ForEach(AppMenuPlaceholder.allCases) { placeholder in
                    Label(placeholder.title, systemImage: placeholder.icon)
                        .foregroundStyle(.tertiary)
                }
            }

            Section {
                Button(action: onShowSettings) {
                    Label("Grok API 키", systemImage: "key")
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("apiSettingsButton")
            }
        }
        .listStyle(.insetGrouped)
        .tint(.primary)
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
    AppMenuView(selectedTab: .constant(.memo), onShowSettings: {})
}