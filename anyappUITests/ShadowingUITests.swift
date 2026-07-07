//
//  ShadowingUITests.swift
//  anyappUITests
//

import XCTest

final class ShadowingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func swipeToShadowing(in app: XCUIApplication) {
        let root = app.otherElements["rootContainer"]
        XCTAssertTrue(root.waitForExistence(timeout: 5))
        root.swipeLeft()
    }

    private func swipeToMemo(in app: XCUIApplication) {
        let root = app.otherElements["rootContainer"]
        XCTAssertTrue(root.waitForExistence(timeout: 5))
        root.swipeRight()
    }

    func testSwipeSwitchesToShadowingTab() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["addMemoButton"].waitForExistence(timeout: 5))

        swipeToShadowing(in: app)

        XCTAssertTrue(app.staticTexts["쉐도잉"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["koreanStepCard"].exists)
        XCTAssertTrue(app.otherElements["englishStepCard"].exists)
        XCTAssertTrue(app.otherElements["verificationStepCard"].exists)
    }

    func testSwipeReturnsToMemoList() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["addMemoButton"].waitForExistence(timeout: 5))

        swipeToShadowing(in: app)
        XCTAssertTrue(app.staticTexts["쉐도잉"].waitForExistence(timeout: 3))

        swipeToMemo(in: app)
        XCTAssertTrue(app.buttons["addMemoButton"].waitForExistence(timeout: 3))
    }
}
