//
//  RecordingUITests.swift
//  anyappUITests
//

import XCTest

final class RecordingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// End-to-end coverage of the record → timer → stop → playback flow. Stopping
    /// is the historical crash point, so reaching the playback button after a stop
    /// verifies the app stays alive through teardown.
    @MainActor
    func testRecordThenStopSurvivesAndShowsPlayback() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleSimulatorMicrophoneEnabled", "YES"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "Permission") { alert in
            for title in ["Allow", "허용", "OK", "확인"] {
                let button = alert.buttons[title]
                if button.exists {
                    button.tap()
                    return true
                }
            }
            return false
        }

        let addButton = app.buttons["addMemoButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 8))
        addButton.tap()

        let micButton = app.buttons["micButton"]
        XCTAssertTrue(micButton.waitForExistence(timeout: 8))

        let enabled = micButton.wait(for: \.isEnabled, toEqual: { $0 }, timeout: 8)
        XCTAssertTrue(enabled, "Mic button should become enabled after prepare()")

        app.tap()
        micButton.tap()

        let recordingTimer = app.staticTexts["recordingTimer"]
        XCTAssertTrue(recordingTimer.waitForExistence(timeout: 8))

        let initialLabel = recordingTimer.label
        guard let initialSeconds = Self.parseSeconds(from: initialLabel) else {
            XCTFail("Could not parse initial timer label: \(initialLabel)")
            return
        }

        let advanced = recordingTimer.wait(
            for: \.label,
            toEqual: { label in
                guard let seconds = Self.parseSeconds(from: label) else { return false }
                return seconds > initialSeconds
            },
            timeout: 4
        )
        XCTAssertTrue(advanced, "Timer should advance while recording; started at \(initialLabel)")

        micButton.tap()

        let playbackButton = app.buttons["playbackButton"]
        XCTAssertTrue(playbackButton.waitForExistence(timeout: 8), "App should survive stop and show playback")
    }

    private static func parseSeconds(from label: String) -> Int? {
        let parts = label.split(separator: ":")
        guard parts.count == 2,
              let minutes = Int(parts[0]),
              let seconds = Int(parts[1]) else {
            return nil
        }
        return minutes * 60 + seconds
    }
}

private extension XCUIElement {
    func wait<T>(
        for keyPath: KeyPath<XCUIElement, T>,
        toEqual predicate: (T) -> Bool,
        timeout: TimeInterval
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate(self[keyPath: keyPath]) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return predicate(self[keyPath: keyPath])
    }
}
