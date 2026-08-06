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

    @MainActor
    func testAppStoreSnapshots() throws {
        let app = XCUIApplication()
        setupSnapshot(app)
        app.launchArguments += [
            "-ui-testing-reset-state",
            "-ui-testing-disable-background-refresh",
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Affirmations"].waitForExistence(timeout: 5))
        snapshot("grounded_01_home")

        let favoriteButton = app.buttons["Add to Favorites"].firstMatch
        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 5))
        favoriteButton.tap()
        tapTab("Favorites", in: app)
        XCTAssertTrue(app.staticTexts["Favorites"].waitForExistence(timeout: 5))
        snapshot("grounded_02_favorites")

        tapTab("My Affirmations", in: app)
        let addButton = app.buttons["submit-own-affirmation-button"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let affirmation = "I trust myself to grow through every challenge, honor my progress, and make space for joy along the way."
        let editor = app.textViews["submit-affirmation-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(affirmation)
        app.buttons["submit-affirmation-confirm-button"].tap()
        XCTAssertTrue(app.staticTexts[affirmation].waitForExistence(timeout: 5))
        snapshot("grounded_03_my_affirmations")

        tapTab("Settings", in: app)
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 10))
        snapshot("grounded_04_settings")

        tapTab("Home", in: app)
        let shareButton = app.buttons["Share an affirmation card"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5))
        shareButton.tap()
        XCTAssertTrue(app.staticTexts["Share an Affirmation"].waitForExistence(timeout: 5))
        app.buttons["You are enough."].tap()
        XCTAssertTrue(app.navigationBars["Share Card"].waitForExistence(timeout: 5))
        snapshot("grounded_05_share_card")
    }

    @MainActor
    private func tapTab(_ name: String, in app: XCUIApplication) {
        let matches = app.buttons.matching(identifier: name)
        for index in 0..<matches.count {
            let candidate = matches.element(boundBy: index)
            if candidate.isHittable {
                candidate.tap()
                return
            }
        }
        XCTFail("Could not find a hittable \(name) tab")
    }
}
