//
//  TranscriptionFlowTests.swift
//  anyappTests
//

import Foundation
import Testing
@testable import anyapp

struct TranscriptionFlowTests {
    @Test func appendTextEntryUsesTimestampBlockFormat() {
        let item = Item(timestamp: .now)
        item.appendTextEntry("첫 번째 메모")

        #expect(item.textNote.contains("첫 번째 메모"))
        #expect(item.textNote.contains("["))
        #expect(item.textNote.contains("]"))
    }

    @Test func appendTextEntrySeparatesMultipleEntries() {
        let item = Item(timestamp: .now)
        item.appendTextEntry("첫 번째")
        item.appendTextEntry("두 번째")

        #expect(item.textNote.contains("첫 번째"))
        #expect(item.textNote.contains("두 번째"))
        #expect(item.textNote.contains("\n\n"))
    }

    @Test func needsTranscriptionWhenAudioNotYetTranscribed() {
        let item = Item(timestamp: .now)
        item.audioFileName = "abc.m4a"
        item.lastTranscribedAudioFileName = nil

        #expect(item.needsTranscription)
    }

    @Test func needsTranscriptionFalseAfterMatchingFileName() {
        let item = Item(timestamp: .now)
        item.audioFileName = "abc.m4a"
        item.lastTranscribedAudioFileName = "abc.m4a"

        #expect(!item.needsTranscription)
    }

    @Test func deleteAudioFileClearsTranscriptionTracking() throws {
        let item = Item(timestamp: .now)
        let fileName = "test-delete.m4a"
        let url = AudioFileStore.documentsDirectory.appendingPathComponent(fileName)
        try Data().write(to: url)

        item.audioFileName = fileName
        item.audioDuration = 1.0
        item.lastTranscribedAudioFileName = fileName

        item.deleteAudioFile()

        #expect(item.audioFileName == nil)
        #expect(item.audioDuration == nil)
        #expect(item.lastTranscribedAudioFileName == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func reRecordPreservesTextWhileReplacingAudioMetadata() {
        let item = Item(timestamp: .now)
        item.audioFileName = "old.m4a"
        item.audioDuration = 3.0
        item.lastTranscribedAudioFileName = "old.m4a"
        item.appendTextEntry("이전 녹음 전사")

        let previousText = item.textNote

        item.audioFileName = "new.m4a"
        item.audioDuration = 5.0
        item.lastTranscribedAudioFileName = nil

        #expect(item.textNote == previousText)
        #expect(item.audioFileName == "new.m4a")
        #expect(item.needsTranscription)
    }
}
