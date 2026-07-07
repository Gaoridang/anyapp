//
//  RootContainerView.swift
//  anyapp
//

import SwiftUI
import SwiftData
import UIKit

struct RootContainerView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: RootTab = .memo

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                RootPhoneShell()
            } else {
                ContentView(selectedTab: $selectedTab)
            }
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("rootContainer")
    }
}

/// iPhone root: horizontal pager with a single shared NavigationStack header.
private struct RootPhoneShell: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedTab: RootTab = .memo
    @State private var pagerProgress: CGFloat = 0
    @State private var navigationPath = NavigationPath()
    @State private var selectedItemID: PersistentIdentifier?
    @State private var showAPIKeySettings = false
    @State private var hapticsReady = false

    var body: some View {
        NavigationStack(path: $navigationPath) {
            tabPager
                .navigationBarTitleDisplayMode(.inline)
                // Toolbar items stay unconditional: a root view's toolbar never
                // shows on pushed destinations, and removing items when the path
                // changes both breaks re-display after popping back (items never
                // return on iOS 26) and defeats the system's Liquid Glass morph
                // between the leading item and the back button.
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        settingsButton
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Group {
                            EditButton()
                            Button(action: addMemo) {
                                Label("새 메모", systemImage: "plus")
                            }
                            .accessibilityIdentifier("addMemoButton")
                        }
                        .opacity(1 - pagerProgress)
                        .allowsHitTesting(pagerProgress < 0.5)
                    }
                }
                .navigationDestination(for: PersistentIdentifier.self) { id in
                    if let item = modelContext.model(for: id) as? Item {
                        ItemDetailView(item: item)
                    }
                }
        }
        .sheet(isPresented: $showAPIKeySettings) {
            APIKeySettingsView()
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            guard hapticsReady, oldTab != newTab else { return }
            RootPagerHaptics.pageChanged()
        }
        .onAppear {
            hapticsReady = true
        }
    }

    private var pagerTabPosition: Binding<RootTab?> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if let newValue {
                    selectedTab = newValue
                }
            }
        )
    }

    private var tabPager: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                MemoListView(
                    navigationPath: $navigationPath,
                    selectedItemID: $selectedItemID,
                    showsNavigationLinks: true
                )
                .rootPageScrollTransition()
                .containerRelativeFrame(.horizontal)
                .id(RootTab.memo)

                ShadowingView(onShowSettings: { showAPIKeySettings = true })
                    .rootPageScrollTransition()
                    .containerRelativeFrame(.horizontal)
                    .id(RootTab.shadowing)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: pagerTabPosition)
        .scrollDisabled(!navigationPath.isEmpty)
        .scrollClipDisabled()
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            let pageWidth = geometry.containerSize.width
            guard pageWidth > 0 else { return 0 }
            return min(max(geometry.contentOffset.x / pageWidth, 0), 1)
        } action: { _, progress in
            pagerProgress = progress
        }
    }

    private var settingsButton: some View {
        Button {
            showAPIKeySettings = true
        } label: {
            Label("Grok API 키", systemImage: "key")
        }
        .accessibilityIdentifier("apiSettingsButton")
    }

    func addMemo() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
            try? modelContext.save()
            selectedItemID = newItem.persistentModelID
            navigationPath.append(newItem.persistentModelID)
        }
    }
}

enum RootPagerHaptics {
    static func pageChanged() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

private struct RootPageScrollTransitionModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                view
                    .opacity(phase.isIdentity ? 1 : 1 - min(abs(phase.value), 1) * 0.12)
            }
    }
}

extension View {
    func rootPageScrollTransition() -> some View {
        modifier(RootPageScrollTransitionModifier())
    }
}

#Preview {
    RootContainerView()
        .modelContainer(for: Item.self, inMemory: true)
}
