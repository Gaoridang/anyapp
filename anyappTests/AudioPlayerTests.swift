//
//  AudioPlayerTests.swift
//  anyappTests
//

import Testing
@testable import anyapp

@MainActor
struct AudioPlayerTests {
    @Test func remainingTimeNeverNegative() {
        #expect(AudioPlayer.remainingTime(total: 120, elapsed: 30) == 90)
        #expect(AudioPlayer.remainingTime(total: 10, elapsed: 10) == 0)
        #expect(AudioPlayer.remainingTime(total: 10, elapsed: 15) == 0)
    }

    @Test func remainingTimeAtStartEqualsTotal() {
        #expect(AudioPlayer.remainingTime(total: 185, elapsed: 0) == 185)
    }
}
