//
//  AudioFileStore.swift
//  anyapp
//

import Foundation

enum AudioFileStore {
    static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func newRecordingURL(prefix: String? = nil) -> URL {
        let name: String
        if let prefix {
            name = "\(prefix)-\(UUID().uuidString).m4a"
        } else {
            name = "\(UUID().uuidString).m4a"
        }
        return documentsDirectory.appendingPathComponent(name)
    }
}