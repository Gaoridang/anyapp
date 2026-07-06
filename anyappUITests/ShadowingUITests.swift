//
//  ShadowingUITests.swift
//  anyappUITests
//

import XCTest

final class ShadowingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func openMenu(in app: XCUIApplication) {
        let menuButton = app.buttons["appMenuButton"]
        XCTAssertTrue(menuButton.waitForExistence(timeout: 5))
        menuButton.tap()

        let menuView = app.otherElements["appMenuView"]
        XCTAssertTrue(menuView.waitForExistence(timeout: 5))
    }

    func testMenuSwitchesToShadowingTab() throws {
        let app = XCUIApplication()
        app.launch()

        openMenu(in: app)

        let shadowingTab = app.buttons["shadowingTab"]
        XCTAssertTrue(shadowingTab.waitForExistence(timeout: 5))
        shadowingTab.tap()

        XCTAssertTrue(app.staticTexts["쉐도잉"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["koreanStepCard"].exists)
        XCTAssertTrue(app.otherElements["englishStepCard"].exists)
        XCTAssertTrue(app.otherElements["verificationStepCard"].exists)
    }

    func testMenuReturnsToMemoList() throws {
        let app = XCUIApplication()
        app.launch()

        openMenu(in: app)
        app.buttons["shadowingTab"].tap()
        XCTAssertTrue(app.staticTexts["쉐도잉"].waitForExistence(timeout: 3))

        openMenu(in: app)
        app.buttons["memoTab"].tap()
        XCTAssertTrue(app.buttons["addMemoButton"].waitForExistence(timeout: 3))
    }
}
