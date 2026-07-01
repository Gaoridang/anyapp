//
//  RecordingPersistence.swift
//  anyapp
//

import Foundation

enum RecordingPersistence {
    /// Applies stopped-recording metadata to the item. Returns the audio file URL when persisted.
    static func persistStoppedRecording(
        on item: Item,
        pendingFileName: String?,
        duration: TimeInterval?
    ) -> URL? {
        guard let duration, duration > 0, let pendingFileName else { return nil }
        item.audioFileName = pendingFileName
        item.audioDuration = duration
        return item.audioFileURL
    }
}