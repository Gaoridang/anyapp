//
//  SideMenuDrawer.swift
//  anyapp
//

import SwiftUI

struct SideMenuDrawer<Content: View, Menu: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder var content: () -> Content
    @ViewBuilder var menu: () -> Menu

    private var menuWidth: CGFloat {
        min(320, UIScreen.main.bounds.width * 0.82)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            content()
                .allowsHitTesting(!isPresented)

            if isPresented {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture { closeMenu() }
                    .transition(.opacity)
                    .accessibilityLabel("메뉴 닫기")
                    .accessibilityAddTraits(.isButton)

                menu()
                    .frame(width: menuWidth)
                    .frame(maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                    .transition(.move(edge: .leading))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isPresented)
        .simultaneousGesture(menuOpenSwipeGesture)
    }

    private var menuOpenSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard !isPresented else { return }
                guard value.startLocation.x < 44 else { return }
                guard value.translation.width > 50 else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                isPresented = true
            }
    }

    private func closeMenu() {
        isPresented = false
    }
}

struct RootNavigationToolbar: ToolbarContent {
    @Binding var showMenu: Bool
    var activeTab: RootTab
    var onAddMemo: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                showMenu = true
            } label: {
                Label("메뉴", systemImage: "line.3.horizontal")
            }
            .accessibilityIdentifier("appMenuButton")
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            EditButton()
                .disabled(activeTab != .memo)
                .opacity(activeTab == .memo ? 1 : 0.35)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: onAddMemo) {
                Label("새 메모", systemImage: "plus")
            }
            .accessibilityIdentifier("addMemoButton")
            .disabled(activeTab != .memo)
            .opacity(activeTab == .memo ? 1 : 0.35)
        }
    }
}
