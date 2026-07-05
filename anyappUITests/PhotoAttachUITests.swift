//
//  PhotoAttachUITests.swift
//  anyappUITests
//

import XCTest

final class PhotoAttachUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Verifies the keyboard-toolbar plus button dismisses the keyboard and presents
    /// the inline photo album sheet.
    @MainActor
    func testPlusButtonOpensPhotoAlbumSheetWhileKeyboardIsVisible() throws {
        let app = XCUIApplication()
        app.launch()

        addUIInterruptionMonitor(withDescription: "Permission") { alert in
            for title in ["Allow Full Access", "Allow Access to All Photos", "Allow", "허용", "모든 사진", "OK", "확인"] {
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

        let textField = app.textFields["memoTextField"]
        XCTAssertTrue(textField.waitForExistence(timeout: 8))
        textField.tap()

        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 8), "Keyboard should appear after focusing the text field")

        let attachButton = app.buttons["attachPhotoButton"]
        XCTAssertTrue(attachButton.waitForExistence(timeout: 8))
        attachButton.tap()

        let photoSheetTitle = app.navigationBars["사진"]
        let photoSheet = app.otherElements["photoAlbumSheet"]
        let sheetAppeared = photoSheetTitle.waitForExistence(timeout: 8) || photoSheet.waitForExistence(timeout: 2)
        XCTAssertTrue(sheetAppeared, "Photo album sheet should appear")

        let keyboardDismissed = !keyboard.waitForExistence(timeout: 3)
        XCTAssertTrue(keyboardDismissed, "Keyboard should dismiss while the sheet is presented")

        let closeButton = app.buttons["closePhotoAlbumButton"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 8))
        closeButton.tap()

        XCTAssertTrue(textField.waitForExistence(timeout: 8))
        let sheetDismissed = !photoSheetTitle.waitForExistence(timeout: 2) && !photoSheet.waitForExistence(timeout: 1)
        XCTAssertTrue(sheetDismissed, "Photo album sheet should dismiss after tapping close")
    }
}
