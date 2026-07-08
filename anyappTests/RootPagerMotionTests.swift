//
//  RootPagerMotionTests.swift
//  anyappTests
//

import CoreGraphics
import Testing
@testable import anyapp

struct RootPagerMotionTests {
    private let pageCount = 2

    @Test func turnsPageAfterHalfPageDragFromMemo() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.45, velocity: 0, currentPage: 0, pageCount: pageCount) == 0)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.55, velocity: 0, currentPage: 0, pageCount: pageCount) == 1)
    }

    @Test func turnsPageAfterHalfPageDragBackFromShadowing() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.55, velocity: 0, currentPage: 1, pageCount: pageCount) == 1)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.45, velocity: 0, currentPage: 1, pageCount: pageCount) == 0)
    }

    @Test func committedPageTracksLastTurnNotStaleTab() {
        // After committing to page 1, a reverse flick near page 1 must reach page 0.
        #expect(RootPagerMotion.targetPageIndex(progress: 0.92, velocity: -80, currentPage: 1, pageCount: pageCount) == 0)
    }

    @Test func staleTabZeroNearPageOneBlocksReverseFlick() {
        // Without committed-page tracking, selectedTab 0 at offset 0.92 blocks going back.
        #expect(RootPagerMotion.targetPageIndex(progress: 0.92, velocity: -80, currentPage: 0, pageCount: pageCount) == 1)
    }

    @Test func flickTurnsPageBeforeDistanceThreshold() {
        // Below 50% drag, a fast release in the scroll direction still advances.
        #expect(RootPagerMotion.targetPageIndex(progress: 0.12, velocity: 250, currentPage: 0, pageCount: pageCount) == 1)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.88, velocity: -250, currentPage: 1, pageCount: pageCount) == 0)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.02, velocity: 80, currentPage: 0, pageCount: pageCount) == 1)
    }

    @Test func distancePastThresholdWinsOverReverseReleaseVelocity() {
        // Slowing to a stop past 50% with a slight backward flick must not snap home first.
        #expect(RootPagerMotion.targetPageIndex(progress: 0.55, velocity: -200, currentPage: 0, pageCount: pageCount) == 1)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.45, velocity: 200, currentPage: 1, pageCount: pageCount) == 0)
    }

    @Test func edgeBounceOverscrollDoesNotChangePage() {
        #expect(RootPagerMotion.targetPageIndex(progress: 1.08, velocity: 0, currentPage: 1, pageCount: pageCount) == 1)
        #expect(RootPagerMotion.targetPageIndex(progress: -0.06, velocity: 0, currentPage: 0, pageCount: pageCount) == 0)
    }

    @Test func belowHalfPageWithoutFlickSnapsBack() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.40, velocity: 0, currentPage: 0, pageCount: pageCount) == 0)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.60, velocity: 0, currentPage: 1, pageCount: pageCount) == 1)
    }

    @Test func flickAdvancesFromCurrentPage() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.05, velocity: 200, currentPage: 0, pageCount: pageCount) == 1)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.95, velocity: -200, currentPage: 1, pageCount: pageCount) == 0)
    }

    @Test func slowVelocityBelowFlickThresholdUsesProgress() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.05, velocity: 15, currentPage: 0, pageCount: pageCount) == 0)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.55, velocity: 15, currentPage: 0, pageCount: pageCount) == 1)
    }

    @Test func velocityJustAboveFlickThresholdCountsAsFlick() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.05, velocity: 30, currentPage: 0, pageCount: pageCount) == 1)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.95, velocity: -30, currentPage: 1, pageCount: pageCount) == 0)
    }

    @Test func targetIsClampedAtEdges() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0, velocity: -900, currentPage: 0, pageCount: pageCount) == 0)
        #expect(RootPagerMotion.targetPageIndex(progress: 1, velocity: 900, currentPage: 1, pageCount: pageCount) == 1)
    }
}
