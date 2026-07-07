//
//  RootPagerMotionTests.swift
//  anyappTests
//

import CoreGraphics
import Testing
@testable import anyapp

struct RootPagerMotionTests {
    private let pageCount = 2

    @Test func slowReleaseSnapsToNearestPage() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.3, velocity: 0, pageCount: pageCount) == 0)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.7, velocity: 0, pageCount: pageCount) == 1)
    }

    @Test func flickAdvancesEvenBeforeHalfway() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.15, velocity: 500, pageCount: pageCount) == 1)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.85, velocity: -500, pageCount: pageCount) == 0)
    }

    @Test func slowVelocityBelowThresholdDoesNotFlick() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.15, velocity: 80, pageCount: pageCount) == 0)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.85, velocity: -80, pageCount: pageCount) == 1)
    }

    @Test func velocityJustAboveThresholdCountsAsFlick() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0.15, velocity: 150, pageCount: pageCount) == 1)
        #expect(RootPagerMotion.targetPageIndex(progress: 0.85, velocity: -150, pageCount: pageCount) == 0)
    }

    @Test func targetIsClampedAtEdges() {
        // Flicking outward on the first/last page must not target a page
        // that does not exist.
        #expect(RootPagerMotion.targetPageIndex(progress: 0, velocity: -900, pageCount: pageCount) == 0)
        #expect(RootPagerMotion.targetPageIndex(progress: 1, velocity: 900, pageCount: pageCount) == 1)
    }

    @Test func exactPageBoundaryStaysPut() {
        #expect(RootPagerMotion.targetPageIndex(progress: 0, velocity: 0, pageCount: pageCount) == 0)
        #expect(RootPagerMotion.targetPageIndex(progress: 1, velocity: 0, pageCount: pageCount) == 1)
    }
}
