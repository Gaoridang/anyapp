//
//  ScreenHeaderBar.swift
//  anyapp
//

import SwiftUI

struct ScreenHeaderBar<Trailing: View>: View {
    let title: String
    @Binding var selectedTab: RootTab
    var onShowSettings: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    @State private var showMenu = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                showMenu = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.body.weight(.medium))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("메뉴")
            .accessibilityIdentifier("appMenuButton")

            Text(title)
                .font(.title2.weight(.bold))
                .lineLimit(1)

            Spacer(minLength: 0)

            trailing()
        }
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .padding(.top, 4)
        .padding(.bottom, 8)
        .sheet(isPresented: $showMenu) {
            AppMenuView(selectedTab: $selectedTab, onShowSettings: onShowSettings)
        }
    }
}

#Preview {
    @Previewable @State var selectedTab = RootTab.memo
    ScreenHeaderBar(title: "메모", selectedTab: $selectedTab, onShowSettings: {}) {
        Button(action: {}) {
            Image(systemName: "plus")
        }
    }
}
