//
//  RootPagerMotionTests.swift
//  anyappTests
//

import CoreGraphics
import Testing
@testable import anyapp

struct RootPagerMotionTests {
    private let pageCount = 2

    @Test func turnsPageAfterTwentyPercentDragFromMemo() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.15, velocity: 0, currentPage: 0, pageCount: pageCount) == 0)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.25, velocity: 0, currentPage: 0, pageCount: pageCount) == 1)
    }

    @Test func turnsPageAfterTwentyPercentDragBackFromShadowing() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.85, velocity: 0, currentPage: 1, pageCount: pageCount) == 1)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.75, velocity: 0, currentPage: 1, pageCount: pageCount) == 0)
    }

    @Test func edgeBounceOverscrollDoesNotChangePage() {
        #expect(RootPagerMotion.targetPageIndex(progress: 1.08, velocity: 0, currentPage: 1, pageCount: pageCount) == 1)
        #expect(RootPagerMotion.targetPageIndex(progress: -0.06, velocity: 0, currentPage: 0, pageCount: pageCount) == 0)
    }

    @Test func middleReleaseAlwaysPicksASide() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.45, velocity: 0, currentPage: 0, pageCount: pageCount) == 1)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.55, velocity: 0, currentPage: 1, pageCount: pageCount) == 0)
    }

    @Test func flickAdvancesFromCurrentPage() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.05, velocity: 200, currentPage: 0, pageCount: pageCount) == 1)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.95, velocity: -200, currentPage: 1, pageCount: pageCount) == 0)
    }

    @Test func slowVelocityBelowFlickThresholdUsesProgress() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.05, velocity: 30, currentPage: 0, pageCount: pageCount) == 0)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.25, velocity: 30, currentPage: 0, pageCount: pageCount) == 1)
    }

    @Test func velocityJustAboveFlickThresholdCountsAsFlick() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.05, velocity: 60, currentPage: 0, pageCount: pageCount) == 1)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.95, velocity: -60, currentPage: 1, pageCount: pageCount) == 0)
    }

    @Test func targetIsClampedAtEdges() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0, velocity: -900, currentPage: 0, pageCount: pageCount) == 0)
        #expect(RootPagerMotion.targetPageIndex(progress: 1, velocity: 900, currentPage: 1, pageCount: pageCount) == 1)
    }
}
