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

        let homeTab = app.buttons["Home"]
        let favoritesTab = app.buttons["Favorites"]
        let myAffirmationsTab = app.buttons["My Affirmations"]
        let settingsTab = app.buttons["Settings"]

        // Query stable labels directly instead of depending on a particular
        // system tab-container hierarchy.
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5))
        XCTAssertTrue(favoritesTab.exists)
        XCTAssertTrue(myAffirmationsTab.exists)
        XCTAssertTrue(settingsTab.exists)

        myAffirmationsTab.tap()
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

        favoritesTab.tap()
        XCTAssertTrue(app.staticTexts["Favorites"].waitForExistence(timeout: 5))

        settingsTab.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))

        homeTab.tap()
        XCTAssertTrue(app.staticTexts["Affirmations"].waitForExistence(timeout: 5))
    }
}
