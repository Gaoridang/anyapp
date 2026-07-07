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
    @State private var pagerPosition = ScrollPosition()
    @State private var navigationPath = NavigationPath()
    @State private var selectedItemID: PersistentIdentifier?
    @State private var showAPIKeySettings = false
    @State private var shadowingSession = ShadowingSessionModel()
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
                    ToolbarItem(placement: .principal) {
                        RootPagerTitle(progress: pagerProgress)
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
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Group {
                            Button(action: shadowingSession.resetSession) {
                                Label("다시 하기", systemImage: "arrow.counterclockwise")
                            }
                            .disabled(!shadowingSession.canReset)
                            .accessibilityIdentifier("resetShadowingButton")
                        }
                        .opacity(pagerProgress)
                        .allowsHitTesting(pagerProgress > 0.5)
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

                ShadowingView(
                    session: shadowingSession,
                    onShowSettings: { showAPIKeySettings = true }
                )
                    .rootPageScrollTransition()
                    .containerRelativeFrame(.horizontal)
                    .id(RootTab.shadowing)
            }
            .scrollTargetLayout()
            // Turns off UIScrollView rubber-banding so the first/last page
            // cannot be pulled past the edge (SwiftUI has no bounce-off API).
            .background(PagerBounceDisabler())
        }
        // Kept as a safety net: if the custom snap below ever fails to take
        // over, the system still lands on a page boundary.
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition($pagerPosition)
        .scrollDisabled(!navigationPath.isEmpty)
        .scrollClipDisabled()
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            let pageWidth = geometry.containerSize.width
            guard pageWidth > 0 else { return 0 }
            return min(max(geometry.contentOffset.x / pageWidth, 0), 1)
        } action: { _, progress in
            pagerProgress = progress
        }
        .onScrollPhaseChange { oldPhase, newPhase, context in
            // The moment the finger lifts, replace the velocity-dependent
            // system deceleration with a fixed-duration ease-in-out snap.
            // (`tracking` never scrolled, so a plain tap stays a no-op.)
            guard oldPhase == .interacting,
                  newPhase == .decelerating || newPhase == .idle else { return }
            snapToPage(geometry: context.geometry, velocity: context.velocity)
        }
    }

    private func snapToPage(geometry: ScrollGeometry, velocity: CGVector?) {
        let pageWidth = geometry.containerSize.width
        guard pageWidth > 0 else { return }

        let targetIndex = RootPagerMotion.targetPageIndex(
            progress: geometry.contentOffset.x / pageWidth,
            velocity: velocity?.dx ?? 0,
            pageCount: RootTab.allCases.count
        )

        withAnimation(RootPagerMotion.snap) {
            pagerPosition.scrollTo(x: CGFloat(targetIndex) * pageWidth)
        }
        if let tab = RootTab(rawValue: targetIndex) {
            selectedTab = tab
        }
    }

    private var settingsButton: some View {
        Button {
            showAPIKeySettings = true
        } label: {
            Label("설정", systemImage: "gearshape")
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

struct RootPagerTitle: View {
    let progress: CGFloat

    var body: some View {
        ZStack {
            Text(RootTab.memo.title)
                .opacity(1 - progress)
            Text(RootTab.shadowing.title)
                .opacity(progress)
        }
        .font(.headline)
        .animation(nil, value: progress)
    }
}

enum RootPagerHaptics {
    static func pageChanged() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

enum RootPagerMotion {
    /// cubic-bezier(0.45, 0, 0.25, 1) — a softer, more symmetric ease-in-out
    /// than the Material standard curve. Fixed duration keeps every page turn
    /// identical regardless of swipe speed.
    static let snap: Animation = .timingCurve(0.45, 0.0, 0.25, 1.0, duration: 0.42)

    /// Content-offset velocity (pt/s) above which a release counts as a flick
    /// toward the next page even if the drag covered less than half the width.
    static let flickVelocityThreshold: CGFloat = 120

    /// Picks the page to snap to when the finger lifts. Velocity only decides
    /// the target page; the snap animation itself never depends on it.
    /// - Parameters:
    ///   - progress: content offset divided by page width (0 = first page).
    ///   - velocity: content-offset velocity in pt/s (positive = toward last page).
    ///   - pageCount: total number of pages.
    static func targetPageIndex(progress: CGFloat, velocity: CGFloat, pageCount: Int) -> Int {
        let rawIndex: CGFloat
        if abs(velocity) > flickVelocityThreshold {
            rawIndex = velocity > 0 ? progress.rounded(.up) : progress.rounded(.down)
        } else {
            rawIndex = progress.rounded()
        }
        return Int(min(max(rawIndex, 0), CGFloat(pageCount - 1)))
    }
}

/// Finds the pager's enclosing `UIScrollView` and disables rubber-banding so
/// the first/last page stops dead at the edge. Walking *up* the hierarchy is
/// what keeps this from touching the `List` inside each page (a sibling
/// subtree, not an ancestor).
private struct PagerBounceDisabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let probe = UIView()
        DispatchQueue.main.async { [weak probe] in
            var view = probe?.superview
            while let current = view {
                if let scrollView = current as? UIScrollView {
                    scrollView.bounces = false
                    return
                }
                view = current.superview
            }
        }
        return probe
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
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
