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

    init(timestamp: Date) {
        self.timestamp = timestamp
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

enum AudioFileStore {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func newRecordingURL() -> URL {
        documentsDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
    }
}
