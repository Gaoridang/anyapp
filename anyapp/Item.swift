//
//  Item.swift
//  anyapp
//
//  Created by ijaejun on 6/25/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    var textNote: String = ""
    var audioFileName: String?
    var audioDuration: TimeInterval?
    var lastTranscribedAudioFileName: String?

    init(timestamp: Date) {
        self.timestamp = timestamp
    }

    var needsTranscription: Bool {
        guard let audioFileName else { return false }
        return audioFileName != lastTranscribedAudioFileName
    }

    func appendTextEntry(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let timestamp = Date.now.formatted(.dateTime.day().month().year().hour().minute())
        let entry = "[\(timestamp)]\n\(trimmed)"

        if textNote.isEmpty {
            textNote = entry
        } else {
            textNote += "\n\n" + entry
        }
    }

    var audioFileURL: URL? {
        guard let audioFileName else { return nil }
        return AudioFileStore.documentsDirectory.appendingPathComponent(audioFileName)
    }

    func deleteAudioFile() {
        guard let url = audioFileURL else { return }
        try? FileManager.default.removeItem(at: url)
        audioFileName = nil
        audioDuration = nil
        lastTranscribedAudioFileName = nil
    }

    /// First meaningful body line from textNote, stripping `[timestamp]` entry headers.
    var listPreviewBody: String? {
        let trimmedNote = textNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNote.isEmpty else { return nil }

        let entries = trimmedNote.components(separatedBy: "\n\n")
        for entry in entries.reversed() {
            let lines = entry
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
            guard !lines.isEmpty else { continue }

            var bodyLines = lines
            if let first = bodyLines.first,
               first.hasPrefix("["),
               first.hasSuffix("]") {
                bodyLines.removeFirst()
            }

            for line in bodyLines {
                let candidate = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !candidate.isEmpty {
                    return candidate
                }
            }
        }
        return nil
    }

    /// Primary row title for memo list.
    var listTitle: String {
        if let listPreviewBody {
            return listPreviewBody
        }
        if audioFileName != nil {
            return "음성 메모"
        }
        return "새 메모"
    }

    /// Compact duration like ItemDetailView: "m:ss" from audioDuration; nil if no duration.
    var listDurationText: String? {
        guard let audioDuration else { return nil }
        return Self.formattedListDuration(audioDuration)
    }

    /// Relative-ish secondary date string for list (locale-aware).
    var listSecondaryDateText: String {
        let formatted = timestamp.formatted(.relative(presentation: .named))
        if formatted.isEmpty {
            return timestamp.formatted(date: .abbreviated, time: .omitted)
        }
        return formatted
    }

    /// Single VoiceOver sentence for the memo list row.
    var listAccessibilityLabel: String {
        var parts: [String] = [listTitle]
        if let listDurationText {
            parts.append(listDurationText)
        }
        parts.append(listSecondaryDateText)
        if needsTranscription {
            parts.append("변환 대기 중")
        }
        if audioFileName != nil, listPreviewBody != nil {
            parts.append("음성 및 텍스트")
        }
        return parts.joined(separator: ", ")
    }

    static func formattedListDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
