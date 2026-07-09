//
//  MemoListGroupingTests.swift
//  anyappTests
//

import Foundation
import Testing
@testable import anyapp

struct MemoListGroupingTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "ko_KR")
        return calendar
    }

    private var fixedNow: Date {
        // 2026-07-09 12:00:00 UTC
        Date(timeIntervalSince1970: 1_783_598_400)
    }

    @Test func sectionTitleTodayAndYesterday() {
        let calendar = utcCalendar
        let now = fixedNow
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        #expect(MemoListGrouping.sectionTitle(for: today, now: now, calendar: calendar) == "오늘")
        #expect(MemoListGrouping.sectionTitle(for: yesterday, now: now, calendar: calendar) == "어제")
    }

    @Test func sectionsGroupsTwoDaysNewestFirst() {
        let calendar = utcCalendar
        let now = fixedNow
        let todayAfternoon = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: now)!
        let todayMorning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayAfternoon)!

        let newerToday = Item(timestamp: todayAfternoon)
        let olderToday = Item(timestamp: todayMorning)
        let yesterdayItem = Item(timestamp: yesterday)

        // Already sorted newest-first
        let items = [newerToday, olderToday, yesterdayItem]
        let result = MemoListGrouping.sections(from: items, now: now, calendar: calendar)

        #expect(result.count == 2)
        #expect(result[0].title == "오늘")
        #expect(result[0].items.map(\.timestamp) == [todayAfternoon, todayMorning])
        #expect(result[1].title == "어제")
        #expect(result[1].items.map(\.timestamp) == [yesterday])
        #expect(result[0].dayStart == calendar.startOfDay(for: now))
        #expect(result[1].dayStart == calendar.startOfDay(for: yesterday))
    }

    @Test func filteredEmptyQueryReturnsAll() {
        let items = [
            Item(timestamp: .now),
            Item(timestamp: .now.addingTimeInterval(-3600)),
        ]
        items[0].textNote = "알파"
        items[1].textNote = "베타"

        #expect(MemoListGrouping.filtered(items, query: "").count == 2)
        #expect(MemoListGrouping.filtered(items, query: "   ").count == 2)
        #expect(MemoListGrouping.matches(items[0], query: ""))
        #expect(MemoListGrouping.matches(items[0], query: "\t "))
    }

    @Test func filteredMatchesListTitleBodyText() {
        let item = Item(timestamp: .now)
        item.appendTextEntry("오늘 회의 노트")

        #expect(MemoListGrouping.matches(item, query: "회의"))
        #expect(MemoListGrouping.filtered([item], query: "회의").count == 1)
        #expect(MemoListGrouping.filtered([item], query: "없는단어").isEmpty)
    }

    @Test func filteredMatchesTextInsideTextNote() {
        let item = Item(timestamp: .now)
        item.textNote = "[2026. 7. 1. 오전 10:00]\n숨겨진 키워드 본문"

        #expect(MemoListGrouping.matches(item, query: "숨겨진"))
        #expect(MemoListGrouping.filtered([item], query: "키워드").count == 1)
    }

    @Test func filteredIsCaseInsensitiveOrKoreanSubstring() {
        let item = Item(timestamp: .now)
        item.textNote = "Hello World 메모"

        #expect(MemoListGrouping.matches(item, query: "hello"))
        #expect(MemoListGrouping.matches(item, query: "WORLD"))
        #expect(MemoListGrouping.matches(item, query: "메모"))
        #expect(MemoListGrouping.filtered([item], query: "HeLLo").count == 1)
    }
}
