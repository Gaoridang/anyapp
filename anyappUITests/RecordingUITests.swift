//
//  RecordingUITests.swift
//  anyappUITests
//

import XCTest

final class RecordingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testMicButtonShowsRecordingTimer() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleSimulatorMicrophoneEnabled", "YES"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "Microphone permission") { alert in
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

        let enabledMic = micButton.wait(
            for: \.isEnabled,
            toEqual: { $0 },
            timeout: 8
        )
        XCTAssertTrue(enabledMic, "Mic button should become enabled after prepare()")

        app.tap()
        micButton.tap()

        let recordingTimer = app.staticTexts["recordingTimer"]
        XCTAssertTrue(recordingTimer.waitForExistence(timeout: 8))

        let initialLabel = recordingTimer.label
        guard let initialSeconds = Self.parseSeconds(from: initialLabel) else {
            XCTFail("Could not parse initial timer label: \(initialLabel)")
            return
        }

        let timerUpdated = recordingTimer.wait(
            for: \.label,
            toEqual: { label in
                guard let seconds = Self.parseSeconds(from: label) else { return false }
                return seconds > initialSeconds
            },
            timeout: 4
        )
        XCTAssertTrue(timerUpdated, "Timer should advance while recording; started at \(initialLabel)")

        micButton.tap()

        let playbackButton = app.buttons["playbackButton"]
        XCTAssertTrue(playbackButton.waitForExistence(timeout: 8))
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