import XCTest

final class AffirmationAppUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchTabsAndAddAffirmation() throws {
        let app = XCUIApplication()
        let uniqueAffirmation = "UI Test Affirmation \(UUID().uuidString.prefix(8))"

        app.launchArguments += [
            "-ui-testing-reset-state",
            "-ui-testing-disable-background-refresh",
        ]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Favorites"].exists)
        XCTAssertTrue(app.tabBars.buttons["My Affirmations"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)

        app.tabBars.buttons["My Affirmations"].tap()
        let addButton = app.buttons["submit-own-affirmation-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let editor = app.textViews["submit-affirmation-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(uniqueAffirmation)

        let submitButton = app.buttons["submit-affirmation-confirm-button"]
        XCTAssertTrue(submitButton.exists)
        submitButton.tap()

        XCTAssertTrue(app.staticTexts[uniqueAffirmation].waitForExistence(timeout: 5))

        app.tabBars.buttons["Favorites"].tap()
        XCTAssertTrue(app.staticTexts["Favorites"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts["Affirmations"].waitForExistence(timeout: 5))
    }
}
