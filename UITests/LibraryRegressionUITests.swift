import XCTest

extension AffirmationAppUITests {
    @MainActor
    func testEditDeleteAndRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset-state", "-ui-testing-disable-background-refresh"]
        app.launch()
        tapTab("My Affirmations", in: app)
        app.buttons["submit-own-affirmation-button"].tap()
        let submit = app.buttons["submit-affirmation-confirm-button"]
        if !submit.isHittable { app.swipeUp() }
        submit.tap()
        XCTAssertTrue(app.alerts["Missing Information"].waitForExistence(timeout: 5))
        app.alerts.buttons["OK"].tap()
        let input = app.textViews["submit-affirmation-editor"]
        input.tap(); input.typeText("My durable affirmation")
        if !submit.isHittable { app.swipeUp() }
        submit.tap()
        let original = app.staticTexts["My durable affirmation"]
        XCTAssertTrue(original.waitForExistence(timeout: 5)); original.tap()
        let editor = app.textViews["edit-affirmation-editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap(); editor.typeText(" revised")
        let revised = try XCTUnwrap(editor.value as? String)
        XCTAssertTrue(revised.contains("revised"))
        if !app.buttons["Save Changes"].isHittable { app.swipeUp() }
        app.buttons["Save Changes"].tap()
        XCTAssertTrue(app.staticTexts[revised].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments.removeAll { $0 == "-ui-testing-reset-state" }
        app.launch()
        tapTab("My Affirmations", in: app)
        XCTAssertTrue(app.staticTexts[revised].waitForExistence(timeout: 5))
        app.staticTexts[revised].tap()
        let delete = app.buttons["Delete Affirmation"]
        if !delete.isHittable { app.swipeUp() }
        delete.tap()
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.textViews["edit-affirmation-editor"].exists)
        delete.tap(); app.alerts.buttons["Delete"].tap()
        app.terminate(); app.launch()
        tapTab("My Affirmations", in: app)
        XCTAssertFalse(app.staticTexts[revised].exists)
    }

    @MainActor
    func testAppearancePersistsAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset-state", "-ui-testing-disable-background-refresh"]
        app.launch()
        tapTab("Settings", in: app)
        app.buttons["Themes & Fonts"].tap()
        let theme = app.buttons["theme-dusk"]
        XCTAssertTrue(theme.waitForExistence(timeout: 5)); theme.tap()
        let font = app.buttons["font-rounded"]
        for _ in 0..<8 where !font.isHittable { app.collectionViews.firstMatch.swipeUp() }
        XCTAssertTrue(font.isHittable)
        font.tap()
        app.terminate()
        app.launchArguments.removeAll { $0 == "-ui-testing-reset-state" }
        app.launch()
        tapTab("Settings", in: app); app.buttons["Themes & Fonts"].tap()
        XCTAssertEqual(app.buttons["theme-dusk"].value as? String, "Selected")
        for _ in 0..<8 where !app.buttons["font-rounded"].isHittable {
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(app.buttons["font-rounded"].isHittable)
        XCTAssertEqual(app.buttons["font-rounded"].value as? String, "Selected")
    }

    @MainActor
    func testFeedPaginationAndFavoriteAfterRotation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset-state", "-ui-testing-seed-feed", "-ui-testing-disable-background-refresh"]
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        for index in 1...18 {
            let id = String(format: "feed-card-00000000-0000-0000-0000-%012d", index)
            let cards = app.descendants(matching: .any).matching(identifier: id)
            let card = cards.firstMatch
            for _ in 0..<15 {
                if card.exists && card.isHittable { break }
                app.scrollViews.firstMatch.swipeUp()
            }
            XCTAssertTrue(card.isHittable, "Missing feed item \(index)")
            XCTAssertEqual(cards.count, 1, "Duplicate feed item \(index)")
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        let last = app.descendants(matching: .any)["feed-card-00000000-0000-0000-0000-000000000018"]
        for _ in 0..<6 where !last.isHittable { app.scrollViews.firstMatch.swipeUp() }
        let favorite = last.buttons["Add to Favorites"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 5)); favorite.tap()
        XCTAssertTrue(last.buttons["Remove Favorite"].waitForExistence(timeout: 5))
        tapTab("Favorites", in: app)
        XCTAssertTrue(app.staticTexts["Feed test affirmation 18"].waitForExistence(timeout: 5))
    }
    @MainActor
    func testAccessibilityFeedUsesOneColumn() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset-state", "-ui-testing-seed-feed",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let first = app.descendants(matching: .any)["feed-card-00000000-0000-0000-0000-000000000001"]
        let second = app.descendants(matching: .any)["feed-card-00000000-0000-0000-0000-000000000002"]
        for _ in 0..<8 where !second.exists { app.swipeUp() }
        XCTAssertTrue(first.exists && second.exists)
        XCTAssertGreaterThan(first.frame.width, 0)
        XCTAssertEqual(first.frame.minX, second.frame.minX, accuracy: 2)
        XCTAssertEqual(first.frame.width, second.frame.width, accuracy: 2)
        XCTAssertLessThanOrEqual(first.frame.maxY, second.frame.minY)
    }

    @MainActor
    func testShareComposerDoneAfterRotation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset-state"]
        app.launch()
        defer { XCUIDevice.shared.orientation = .portrait }
        app.buttons["Share an affirmation card"].tap()
        app.buttons["You are enough."].tap()
        XCTAssertTrue(app.navigationBars["Share Card"].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .landscapeLeft
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isHittable)
        done.tap()
        XCTAssertTrue(app.buttons["Share an affirmation card"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars["Share Card"].exists)
    }

}
