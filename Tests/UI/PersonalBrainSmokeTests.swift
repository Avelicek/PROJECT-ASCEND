import XCTest

final class PersonalBrainSmokeTests: XCTestCase {
    @MainActor private func launch(_ arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--demo", "--ui-testing"] + arguments; app.launch()
        XCTAssertTrue(app.scrollViews["screen.dashboard"].waitForExistence(timeout: 20))
        return app
    }
    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        AscendUITestSupport.reveal(element, screen: "screen.dashboard", in: app)
    }
    @MainActor func testBrainHeroDetailAndStartRecommendedSession() {
        let app = launch()
        XCTAssertEqual(app.staticTexts["brain.focus"].label, "PULL")
        let detail = app.buttons["brain.detail"]; reveal(detail, in: app); detail.tap()
        XCTAssertTrue(app.scrollViews["screen.braindetail"].waitForExistence(timeout: 10))
        app.buttons["Done"].firstMatch.tap()
        let start = app.buttons["brain.start"]; reveal(start, in: app); start.tap()
        XCTAssertTrue(app.scrollViews["screen.liveworkout"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.textFields["live.title"].value as? String, "Pull")
        XCTAssertTrue(app.buttons["live.exercise.pull_up"].exists)
    }
    @MainActor func testLowConfidenceDoesNotInventRecovery() {
        let app = launch(["--brain-low-data"])
        let confidence = app.staticTexts["brain.confidence"]; reveal(confidence, in: app)
        XCTAssertTrue(confidence.label.contains("Low confidence"))
        XCTAssertTrue(app.staticTexts["Unknown"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["91%"].exists)
    }
    @MainActor func testRecommendationUpdatesWhenSleepInputDisabled() {
        let app = launch(["--brain-poor-sleep"])
        XCTAssertEqual(app.staticTexts["brain.focus"].label, "RECOVERY")
        AscendUITestSupport.navigate("profile", in: app)
        let settings = app.buttons["profile.brain"]
        AscendUITestSupport.reveal(settings, screen: "screen.profile", in: app)
        XCTAssertTrue(settings.isHittable); settings.tap()
        XCTAssertTrue(app.navigationBars["Brain settings"].waitForExistence(timeout: 10))
        let sleep = app.switches["brain.settings.sleep"]
        XCTAssertTrue(sleep.waitForExistence(timeout: 10))
        if !sleep.isHittable { app.scrollViews.firstMatch.swipeUp() }
        XCTAssertTrue(sleep.isHittable)
        sleep.tap()
        app.buttons["Done"].firstMatch.tap()
        AscendUITestSupport.navigate("dashboard", in: app)
        XCTAssertEqual(app.staticTexts["brain.focus"].label, "PULL")
    }
}
