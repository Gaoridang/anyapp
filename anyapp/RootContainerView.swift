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

                ShadowingView(
                    session: shadowingSession,
                    onShowSettings: { showAPIKeySettings = true }
                )
                    .rootPageScrollTransition()
                    .containerRelativeFrame(.horizontal)
                    .id(RootTab.shadowing)
            }
            .scrollTargetLayout()
            // Hooks the underlying UIScrollView so we can kill UIKit paging
            // deceleration and run our own cubic-bezier snap instead.
            .background(PagerScrollController(
                pageCount: RootTab.allCases.count,
                currentPage: { selectedTab.rawValue }
            ) { pageIndex in
                if let tab = RootTab(rawValue: pageIndex) {
                    selectedTab = tab
                }
            })
        }
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
    /// cubic-bezier(0.22, 1, 0.36, 1) — ease-out: fast at release, smooth landing.
    static let snapDuration: TimeInterval = 0.45
    static let snapControlPoint1 = CGPoint(x: 0.22, y: 1.0)
    static let snapControlPoint2 = CGPoint(x: 0.36, y: 1.0)

    /// Drag past 20% of a page width (default UIKit paging is ~50%) to turn.
    static let progressTurnThreshold: CGFloat = 0.20

    /// Release velocity (pt/s) above which a flick turns the page even below
    /// `progressTurnThreshold`.
    static let flickVelocityThreshold: CGFloat = 50

    static var snapTimingParameters: UICubicTimingParameters {
        UICubicTimingParameters(
            controlPoint1: snapControlPoint1,
            controlPoint2: snapControlPoint2
        )
    }

    /// Picks the page to snap to when the finger lifts.
    static func targetPageIndex(
        progress: CGFloat,
        velocity: CGFloat,
        currentPage: Int,
        pageCount: Int
    ) -> Int {
        let maxIndex = pageCount - 1
        let lower = floor(progress)
        let fraction = progress - lower

        if abs(velocity) > flickVelocityThreshold {
            let target = velocity > 0 ? currentPage + 1 : currentPage - 1
            return min(max(target, 0), maxIndex)
        }

        if currentPage == 0 {
            return fraction >= progressTurnThreshold ? min(1, maxIndex) : 0
        }

        return fraction <= (1 - progressTurnThreshold) ? max(currentPage - 1, 0) : currentPage
    }
}

// MARK: - UIKit scroll snap (SwiftUI `withAnimation` + `scrollTo` does not
// override `.scrollTargetBehavior(.paging)` deceleration, so we intercept
// `scrollViewWillEndDragging` and drive `contentOffset` ourselves.)

private final class PagerScrollSnapHandler {
    let pageCount: Int
    let currentPage: () -> Int
    var onPageSettled: ((Int) -> Void)?
    private var activeAnimator: UIViewPropertyAnimator?

    init(pageCount: Int, currentPage: @escaping () -> Int) {
        self.pageCount = pageCount
        self.currentPage = currentPage
    }

    func handleWillEndDragging(_ scrollView: UIScrollView, velocity: CGPoint) {
        let pageWidth = scrollView.bounds.width
        guard pageWidth > 0 else { return }

        let progress = scrollView.contentOffset.x / pageWidth
        let targetIndex = RootPagerMotion.targetPageIndex(
            progress: progress,
            velocity: velocity.x,
            currentPage: currentPage(),
            pageCount: pageCount
        )
        let targetX = CGFloat(targetIndex) * pageWidth

        activeAnimator?.stopAnimation(true)

        guard abs(scrollView.contentOffset.x - targetX) > 0.5 else {
            onPageSettled?(targetIndex)
            return
        }

        let animator = UIViewPropertyAnimator(
            duration: RootPagerMotion.snapDuration,
            timingParameters: RootPagerMotion.snapTimingParameters
        )
        animator.addAnimations {
            scrollView.contentOffset = CGPoint(x: targetX, y: scrollView.contentOffset.y)
        }
        animator.addCompletion { [weak self] _ in
            self?.activeAnimator = nil
            self?.onPageSettled?(targetIndex)
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

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        originalDelegate?.scrollViewWillEndDragging?(
            scrollView,
            withVelocity: velocity,
            targetContentOffset: targetContentOffset
        )
        // Cancel UIKit paging deceleration; our animator takes over below.
        targetContentOffset.pointee = scrollView.contentOffset
        snapHandler.handleWillEndDragging(scrollView, velocity: velocity)
    }
}

private struct PagerScrollController: UIViewRepresentable {
    let pageCount: Int
    let currentPage: () -> Int
    let onPageSettled: (Int) -> Void

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
        }
    }

    final class Coordinator {
        let snapHandler: PagerScrollSnapHandler
        private weak var attachedScrollView: UIScrollView?
        private var delegateProxy: PagerScrollDelegateProxy?

        init(pageCount: Int, currentPage: @escaping () -> Int, onPageSettled: @escaping (Int) -> Void) {
            snapHandler = PagerScrollSnapHandler(pageCount: pageCount, currentPage: currentPage)
            snapHandler.onPageSettled = onPageSettled
        }

        func attachIfNeeded(from view: UIView) {
            var candidate: UIView? = view.superview
            while let current = candidate {
                if let scrollView = current as? UIScrollView {
                    guard attachedScrollView !== scrollView else { return }

                    attachedScrollView = scrollView
                    scrollView.bounces = false

                    let proxy = PagerScrollDelegateProxy(snapHandler: snapHandler)
                    proxy.originalDelegate = scrollView.delegate
                    scrollView.delegate = proxy
                    delegateProxy = proxy
                    return
                }
                candidate = current.superview
            }
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
