//
//  AppMenuView.swift
//  anyapp
//

import SwiftUI

enum AppMenuRoute: Hashable {
    case menu
}

struct AppMenuView: View {
    @Binding var selectedTab: RootTab
    var onShowSettings: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            menuHeader

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
            .listStyle(.insetGrouped)
            .contentMargins(.top, 8, for: .scrollContent)
        }
        .background(Color(.systemGroupedBackground))
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityIdentifier("appMenuView")
    }

    private var menuHeader: some View {
        HStack(spacing: 8) {
            Button(action: dismiss.callAsFunction) {
                Image(systemName: "chevron.backward")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("뒤로")

            Text("메뉴")
                .font(.title2.weight(.bold))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.leading, 4)
        .padding(.trailing, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

private enum AppMenuPlaceholder: String, CaseIterable, Identifiable {
    case comingSoon

    var id: String { rawValue }

    var title: String { "곧 추가될 기능" }

    var icon: String { "ellipsis.circle" }
}

#Preview {
    NavigationStack {
        AppMenuView(selectedTab: .constant(.memo), onShowSettings: {})
    }
}
