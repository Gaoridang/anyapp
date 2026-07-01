//
//  anyappTests.swift
//  anyappTests
//

import Foundation
import Testing
@testable import anyapp

struct anyappTests {
    @Test func audioFileStoreProducesUniqueM4AURLs() {
        let first = AudioFileStore.newRecordingURL()
        let second = AudioFileStore.newRecordingURL()

        #expect(first.pathExtension == "m4a")
        #expect(second.pathExtension == "m4a")
        #expect(first != second)
        #expect(first.deletingLastPathComponent() == AudioFileStore.documentsDirectory)
    }
}