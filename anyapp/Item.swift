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
    }
}
