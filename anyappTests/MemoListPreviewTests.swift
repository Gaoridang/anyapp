//
//  MemoListPreviewTests.swift
//  anyappTests
//

import Foundation
import Testing
@testable import anyapp

struct MemoListPreviewTests {
    @Test func plainAppendTextEntryListTitleIsBodyWithoutHeader() {
        let item = Item(timestamp: .now)
        item.appendTextEntry("오늘 회의 노트")

        #expect(item.listPreviewBody == "오늘 회의 노트")
        #expect(item.listTitle == "오늘 회의 노트")
        #expect(!item.listTitle.contains("["))
        #expect(!item.listTitle.contains("]"))
    }

    @Test func multipleEntriesLatestBodyWins() {
        let item = Item(timestamp: .now)
        item.appendTextEntry("첫 번째")
        item.appendTextEntry("두 번째")

        #expect(item.listPreviewBody == "두 번째")
        #expect(item.listTitle == "두 번째")
    }

    @Test func emptyItemUsesNewMemoTitle() {
        let item = Item(timestamp: .now)

        #expect(item.listPreviewBody == nil)
        #expect(item.listTitle == "새 메모")
        #expect(!item.listSecondaryDateText.isEmpty)
        #expect(item.listAccessibilityLabel.contains("새 메모"))
    }

    @Test func audioOnlyUsesVoiceMemoTitleAndDuration() {
        let item = Item(timestamp: .now)
        item.audioFileName = "voice.m4a"
        item.audioDuration = 84

        #expect(item.listPreviewBody == nil)
        #expect(item.listTitle == "음성 메모")
        #expect(item.listDurationText == "1:24")
        #expect(item.listAccessibilityLabel.contains("음성 메모"))
        #expect(item.listAccessibilityLabel.contains("1:24"))
    }

    @Test func needsTranscriptionAppearsInAccessibilityLabel() {
        let item = Item(timestamp: .now)
        item.audioFileName = "pending.m4a"
        item.audioDuration = 84
        item.lastTranscribedAudioFileName = nil

        #expect(item.needsTranscription)
        #expect(item.listAccessibilityLabel.contains("변환 대기"))
    }

    @Test func formattedListDurationFormatsMinutesAndSeconds() {
        #expect(Item.formattedListDuration(65) == "1:05")
    }

    @Test func bothAudioAndTextMentionedInAccessibilityLabel() {
        let item = Item(timestamp: .now)
        item.audioFileName = "both.m4a"
        item.audioDuration = 10
        item.lastTranscribedAudioFileName = "both.m4a"
        item.appendTextEntry("오늘 회의")

        #expect(item.listAccessibilityLabel.contains("음성 및 텍스트"))
        #expect(!item.listAccessibilityLabel.contains("변환 대기"))
    }

    @Test func plainTextWithoutHeadersStillPreviews() {
        let item = Item(timestamp: .now)
        item.textNote = "레거시 메모 본문"

        #expect(item.listPreviewBody == "레거시 메모 본문")
        #expect(item.listTitle == "레거시 메모 본문")
    }
}
