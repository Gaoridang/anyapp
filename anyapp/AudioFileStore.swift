//
//  AudioFileStore.swift
//  anyapp
//

import Foundation

enum AudioFileStore {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func newRecordingURL() -> URL {
        documentsDirectory.appendingPathComponent("\(UUID().uuidString).m4a")
    }
}