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
                    showsNavigationLinks: true,
                    allowsSwipeToDelete: false
                )
                .rootPageScrollTransition()
                .containerRelativeFrame(.horizontal)
                .background(Color(.systemGroupedBackground))
                .id(RootTab.memo)

                ShadowingView(
                    session: shadowingSession,
                    onShowSettings: { showAPIKeySettings = true }
                )
                    .rootPageScrollTransition()
                    .containerRelativeFrame(.horizontal)
                    .background(Color(.systemGroupedBackground))
                    .id(RootTab.shadowing)
            }
            .background(PagerScrollController(
                pageCount: RootTab.allCases.count,
                currentPage: { selectedTab.rawValue },
                onPageSettled: { pageIndex, didChangePage in
                    if let tab = RootTab(rawValue: pageIndex) {
                        selectedTab = tab
                    }
                    if hapticsReady, didChangePage {
                        RootPagerHaptics.pageChanged()
                    }
                }
            ))
        }
        .background(Color(.systemGroupedBackground))
        .scrollIndicators(.hidden)
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
    /// Monotonic ease-out — never reverses direction mid-animation (springs could
    /// undershoot past the origin, which looked like “snap back, then forward”).
    static let snapControlPoint1 = CGPoint(x: 0.22, y: 1.0)
    static let snapControlPoint2 = CGPoint(x: 0.36, y: 1.0)
    static let minSnapDuration: TimeInterval = 0.24
    static let maxSnapDuration: TimeInterval = 0.46

    /// Drag past 20% of a page width (default UIKit paging is ~50%) to turn.
    static let progressTurnThreshold: CGFloat = 0.20

    /// Release velocity (pt/s) above which a flick turns the page when the drag
    /// stayed below `progressTurnThreshold`.
    static let flickVelocityThreshold: CGFloat = 50

    static func snapTimingParameters() -> UICubicTimingParameters {
        UICubicTimingParameters(
            controlPoint1: snapControlPoint1,
            controlPoint2: snapControlPoint2
        )
    }

    /// Duration scales with how far the scroll view still has to travel.
    static func snapDuration(distanceFraction: CGFloat) -> TimeInterval {
        let fraction = min(max(Double(distanceFraction), 0.12), 1.0)
        return minSnapDuration + (maxSnapDuration - minSnapDuration) * fraction
    }

    static var pagerBackgroundColor: UIColor { .systemGroupedBackground }

    /// Picks the page to snap to when the finger lifts.
    ///
    /// Priority: dragged distance past threshold wins first (so slowing to a stop
    /// with a small negative release velocity does not flip back to the origin
    /// page). Flick velocity only applies below the distance threshold.
    static func targetPageIndex(
        progress: CGFloat,
        velocity: CGFloat,
        currentPage: Int,
        pageCount: Int
    ) -> Int {
        let maxIndex = pageCount - 1
        let clampedPage = min(max(currentPage, 0), maxIndex)
        let offsetFromCurrent = progress - CGFloat(clampedPage)

        if offsetFromCurrent >= progressTurnThreshold {
            return min(clampedPage + 1, maxIndex)
        }
        if offsetFromCurrent <= -progressTurnThreshold {
            return max(clampedPage - 1, 0)
        }

        if velocity > flickVelocityThreshold {
            return min(clampedPage + 1, maxIndex)
        }
        if velocity < -flickVelocityThreshold {
            return max(clampedPage - 1, 0)
        }
        return clampedPage
    }

    static func isOnPageBoundary(progress: CGFloat, tolerance: CGFloat = 0.001) -> Bool {
        abs(progress - progress.rounded()) <= tolerance
    }
}

// MARK: - UIKit scroll snap (SwiftUI `withAnimation` + `scrollTo` does not
// override `.scrollTargetBehavior(.paging)` deceleration, so we intercept
// `scrollViewWillEndDragging` and drive `contentOffset` ourselves.)

private final class PagerScrollSnapHandler {
    let pageCount: Int
    let currentPage: () -> Int
    var onPageSettled: ((Int, Bool) -> Void)?
    private var activeAnimator: UIViewPropertyAnimator?
    private var isDragging = false
    private var hasCommittedSnap = false

    init(pageCount: Int, currentPage: @escaping () -> Int) {
        self.pageCount = pageCount
        self.currentPage = currentPage
    }

    var isAnimatingSnap: Bool { activeAnimator != nil }
    var isCommittingSnap: Bool { hasCommittedSnap }

    func handleWillBeginDragging() {
        isDragging = true
        hasCommittedSnap = false
        if let activeAnimator {
            activeAnimator.stopAnimation(true)
            self.activeAnimator = nil
        }
    }

    func syncToCurrentPage(in scrollView: UIScrollView, animated: Bool) {
        guard !isDragging, activeAnimator == nil, !hasCommittedSnap else { return }

        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }

        let targetX = CGFloat(currentPage()) * pageWidth
        guard abs(scrollView.contentOffset.x - targetX) > 0.5 else { return }

        scrollView.contentOffset = CGPoint(x: targetX, y: scrollView.contentOffset.y)
    }

    func handleWillEndDragging(_ scrollView: UIScrollView, velocity: CGPoint) {
        isDragging = false
        hasCommittedSnap = true

        // Freeze the visual position before UIKit/SwiftUI can snap elsewhere.
        let locked = scrollView.contentOffset
        scrollView.setContentOffset(locked, animated: false)

        commitSnap(in: scrollView, velocity: velocity)
    }

    func handleDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
        isDragging = false
    }

    private func commitSnap(in scrollView: UIScrollView, velocity: CGPoint) {
        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }

        let fromPage = currentPage()
        let progress = scrollView.contentOffset.x / pageWidth
        let targetIndex = RootPagerMotion.targetPageIndex(
            progress: progress,
            velocity: velocity.x,
            currentPage: fromPage,
            pageCount: pageCount
        )
        let targetX = CGFloat(targetIndex) * pageWidth
        let didChangePage = targetIndex != fromPage
        let distanceFraction = abs(targetX - scrollView.contentOffset.x) / pageWidth

        animate(
            toOffsetX: targetX,
            distanceFraction: distanceFraction,
            in: scrollView
        ) {
            self.hasCommittedSnap = false
            self.onPageSettled?(targetIndex, didChangePage)
        }
    }

    private func animate(
        toOffsetX targetX: CGFloat,
        distanceFraction: CGFloat,
        in scrollView: UIScrollView,
        completion: (() -> Void)? = nil
    ) {
        if let activeAnimator {
            activeAnimator.stopAnimation(true)
            self.activeAnimator = nil
        }

        guard abs(scrollView.contentOffset.x - targetX) > 0.5 else {
            hasCommittedSnap = false
            completion?()
            return
        }

        let duration = RootPagerMotion.snapDuration(distanceFraction: distanceFraction)
        let animator = UIViewPropertyAnimator(
            duration: duration,
            timingParameters: RootPagerMotion.snapTimingParameters()
        )
        animator.addAnimations {
            scrollView.contentOffset = CGPoint(x: targetX, y: scrollView.contentOffset.y)
        }
        animator.addCompletion { [weak self] position in
            guard let self else { return }
            self.activeAnimator = nil
            if position == .end {
                scrollView.contentOffset = CGPoint(x: targetX, y: scrollView.contentOffset.y)
            }
            guard position == .end else { return }
            completion?()
        }
        activeAnimator = animator
        animator.startAnimation()
    }
}

private final class PagerScrollDelegateProxy: NSObject, UIScrollViewDelegate {
    weak var originalDelegate: UIScrollViewDelegate?
    let snapHandler: PagerScrollSnapHandler

    init(snapHandler: PagerScrollSnapHandler) {
        self.snapHandler = snapHandler
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || (originalDelegate?.responds(to: aSelector) ?? false)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if super.responds(to: aSelector) { return self }
        return originalDelegate
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        originalDelegate?.scrollViewWillBeginDragging?(scrollView)
        snapHandler.handleWillBeginDragging()
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        // Freeze native deceleration *before* SwiftUI's delegate runs — calling
        // the original `willEndDragging` first lets it target page 0, which
        // produced the visible “jump home, then forward” double step.
        targetContentOffset.pointee = scrollView.contentOffset
        snapHandler.handleWillEndDragging(scrollView, velocity: velocity)
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        // If UIKit still starts deceleration, stop it — our animator owns the snap.
        scrollView.setContentOffset(scrollView.contentOffset, animated: false)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !snapHandler.isCommittingSnap, !snapHandler.isAnimatingSnap else { return }
        originalDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
        snapHandler.handleDidEndDragging(scrollView, willDecelerate: decelerate)
    }
}

private struct PagerScrollController: UIViewRepresentable {
    let pageCount: Int
    let currentPage: () -> Int
    let onPageSettled: (Int, Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(pageCount: pageCount, currentPage: currentPage, onPageSettled: onPageSettled)
    }

    func makeUIView(context: Context) -> UIView {
        let probe = UIView(frame: .zero)
        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(from: probe)
        }
        return probe
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attachIfNeeded(from: uiView)
            context.coordinator.syncIfNeeded()
        }
    }

    final class Coordinator {
        let snapHandler: PagerScrollSnapHandler
        let currentPage: () -> Int
        private weak var attachedScrollView: UIScrollView?
        private var delegateProxy: PagerScrollDelegateProxy?
        private var lastSyncedPage: Int?

        init(pageCount: Int, currentPage: @escaping () -> Int, onPageSettled: @escaping (Int, Bool) -> Void) {
            self.currentPage = currentPage
            snapHandler = PagerScrollSnapHandler(pageCount: pageCount, currentPage: currentPage)
            snapHandler.onPageSettled = { [weak self] pageIndex, didChangePage in
                self?.lastSyncedPage = pageIndex
                onPageSettled(pageIndex, didChangePage)
            }
        }

        func syncIfNeeded() {
            guard let scrollView = attachedScrollView else { return }
            guard !scrollView.isDragging, !snapHandler.isAnimatingSnap, !snapHandler.isCommittingSnap else { return }
            let page = currentPage()
            guard lastSyncedPage != page else { return }
            lastSyncedPage = page
            snapHandler.syncToCurrentPage(in: scrollView, animated: false)
        }

        func attachIfNeeded(from view: UIView) {
            var candidate: UIView? = view.superview
            while let current = candidate {
                if let scrollView = current as? UIScrollView {
                    guard attachedScrollView !== scrollView else { return }

                    attachedScrollView = scrollView
                    configure(scrollView)

                    let proxy = PagerScrollDelegateProxy(snapHandler: snapHandler)
                    proxy.originalDelegate = scrollView.delegate
                    scrollView.delegate = proxy
                    delegateProxy = proxy

                    lastSyncedPage = currentPage()
                    snapHandler.syncToCurrentPage(in: scrollView, animated: false)
                    return
                }
                candidate = current.superview
            }
        }

        private func configure(_ scrollView: UIScrollView) {
            scrollView.bounces = true
            scrollView.alwaysBounceHorizontal = false
            scrollView.isPagingEnabled = false
            scrollView.backgroundColor = RootPagerMotion.pagerBackgroundColor
        }
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
