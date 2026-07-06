//
//  ShadowingUITests.swift
//  anyappUITests
//

import XCTest

final class ShadowingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSegmentNavigatorSwitchesToShadowingTab() throws {
        let app = XCUIApplication()
        app.launch()

        let shadowingTab = app.buttons["shadowingTab"]
        XCTAssertTrue(shadowingTab.waitForExistence(timeout: 5))
        shadowingTab.tap()

        XCTAssertTrue(app.staticTexts["영어 쉐도잉"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["koreanStepCard"].exists)
        XCTAssertTrue(app.otherElements["englishStepCard"].exists)
        XCTAssertTrue(app.otherElements["verificationStepCard"].exists)
    }

    func testMemoTabReturnsToMemoList() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["shadowingTab"].tap()
        XCTAssertTrue(app.staticTexts["영어 쉐도잉"].waitForExistence(timeout: 3))

        app.buttons["memoTab"].tap()
        XCTAssertTrue(app.buttons["addMemoButton"].waitForExistence(timeout: 3))
    }
}
