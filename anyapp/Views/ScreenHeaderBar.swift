//
//  ScreenHeaderBar.swift
//  anyapp
//

import SwiftUI

struct ScreenHeaderBar<Trailing: View>: View {
    let title: String
    var onOpenMenu: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: onOpenMenu) {
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
    }
}

#Preview {
    ScreenHeaderBar(title: "메모", onOpenMenu: {}) {
        Button(action: {}) {
            Image(systemName: "plus")
        }
    }
}
