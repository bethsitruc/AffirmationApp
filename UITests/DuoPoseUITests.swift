import XCTest

extension AffirmationAppUITests {
    /// Opt-in because XCTest exposes rotation, but not Device Hub's fold controls.
    /// A tester drives Open → Closed → Open while each width expectation waits.
    @MainActor
    func testDuoFoldTransitionsPreserveFavorites() throws {
        guard ProcessInfo.processInfo.environment["GROUNDED_DUO_POSES"] == "1" else {
            throw XCTSkip("Run with GROUNDED_DUO_POSES=1 and drive Device Hub's fold controls")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-reset-state", "-ui-testing-seed-feed", "-ui-testing-disable-background-refresh"]
        app.launch()
        func waitForWidth(inner: Bool) {
            print("DUO POSE REQUEST: \(inner ? "OPEN" : "CLOSED")")
            let predicate = NSPredicate { _, _ in inner ? app.frame.width > 600 : app.frame.width < 600 }
            let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app)
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 60), .completed,
                           "Expected \(inner ? "inner" : "outer") display; actual app frame \(app.frame)")
        }
        waitForWidth(inner: true)
        app.swipeUp()
        let first = app.descendants(matching: .any)["feed-card-00000000-0000-0000-0000-000000000001"]
        let second = app.descendants(matching: .any)["feed-card-00000000-0000-0000-0000-000000000002"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(second.exists)
        XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 3, "Inner display should lay cards out in multiple columns")
        first.buttons["Add to Favorites"].tap()
        tapTab("Favorites", in: app)
        for inner in [false, true] {
            waitForWidth(inner: inner)
            XCTAssertTrue(app.staticTexts["Feed test affirmation 1"].waitForExistence(timeout: 5))
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = inner ? "duo-open-favorite-retained" : "duo-closed-favorite-retained"
            shot.lifetime = .keepAlways
            add(shot)
        }
    }
}
