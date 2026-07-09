//
//  MemoListGrouping.swift
//  anyapp
//

import Foundation

enum MemoListGrouping {
    /// Korean-friendly section header for a memo's day.
    /// - same calendar day as `now` → "오늘"
    /// - yesterday → "어제"
    /// - within previous 6 days (not today/yesterday) → localized weekday (e.g. "월요일")
    /// - same year → "M월 d일" style via FormatStyle date: .abbreviated or custom Korean-friendly
    /// - otherwise → include year (date .abbreviated is fine)
    static func sectionTitle(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let day = dayStart(for: date, calendar: calendar)
        let today = dayStart(for: now, calendar: calendar)

        if day == today {
            return "오늘"
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today), day == yesterday {
            return "어제"
        }

        if let sixDaysAgo = calendar.date(byAdding: .day, value: -6, to: today),
           day >= sixDaysAgo,
           day < today {
            return date.formatted(
                Date.FormatStyle()
                    .weekday(.wide)
                    .locale(calendar.locale ?? .current)
                    .calendar(calendar)
            )
        }

        let sameYear = calendar.component(.year, from: day) == calendar.component(.year, from: today)
        if sameYear {
            return date.formatted(
                Date.FormatStyle()
                    .month(.defaultDigits)
                    .day()
                    .locale(calendar.locale ?? .current)
                    .calendar(calendar)
            )
        }

        return date.formatted(
            Date.FormatStyle(date: .abbreviated, time: .omitted)
                .locale(calendar.locale ?? .current)
                .calendar(calendar)
        )
    }

    /// Day bucket key (startOfDay) for grouping.
    static func dayStart(for date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    /// Case-insensitive search against listTitle, textNote, and absolute formatted timestamp.
    static func matches(_ item: Item, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let needle = trimmed.lowercased()
        if item.listTitle.lowercased().contains(needle) {
            return true
        }
        if item.textNote.lowercased().contains(needle) {
            return true
        }

        let absoluteTimestamp = item.timestamp.formatted(
            .dateTime.day().month().year().hour().minute()
        )
        return absoluteTimestamp.lowercased().contains(needle)
    }

    static func filtered(_ items: [Item], query: String) -> [Item] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { matches($0, query: trimmed) }
    }

    /// Group already-sorted (newest first) items into sections newest-day-first.
    /// Each section: (title: String, dayStart: Date, items: [Item])
    /// Items within a section keep relative order (newest first).
    static func sections(
        from items: [Item],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [(title: String, dayStart: Date, items: [Item])] {
        var orderedDayStarts: [Date] = []
        var buckets: [Date: [Item]] = [:]

        for item in items {
            let key = dayStart(for: item.timestamp, calendar: calendar)
            if buckets[key] == nil {
                orderedDayStarts.append(key)
                buckets[key] = []
            }
            buckets[key, default: []].append(item)
        }

        return orderedDayStarts.map { key in
            (
                title: sectionTitle(for: key, now: now, calendar: calendar),
                dayStart: key,
                items: buckets[key] ?? []
            )
        }
    }
}
