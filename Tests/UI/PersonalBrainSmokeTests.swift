import XCTest

final class PersonalBrainSmokeTests: XCTestCase {
    @MainActor private func launch(_ arguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--demo", "--ui-testing"] + arguments; app.launch()
        XCTAssertTrue(app.scrollViews["screen.dashboard"].waitForExistence(timeout: 20)); return app
    }
    @MainActor func testBrainHeroDetailAndStartRecommendedSession() {
        let app = launch()
        let detail = app.buttons["brain.detail"]
        AscendUITestSupport.reveal(detail, screen: "screen.dashboard", in: app); detail.tap()
        XCTAssertTrue(app.scrollViews["screen.braindetail"].waitForExistence(timeout: 10))
        app.buttons["Done"].firstMatch.tap()
        AscendUITestSupport.navigate("workout", in: app)
        XCTAssertTrue(app.buttons["workout.start"].waitForExistence(timeout: 10)); app.buttons["workout.start"].tap()
        XCTAssertTrue(app.scrollViews["screen.liveworkout"].waitForExistence(timeout: 10))
        XCTAssertFalse((app.textFields["live.title"].value as? String ?? "").isEmpty)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "live.exercise.")).count > 0)
        app.terminate()
    }
    @MainActor func testLowConfidenceDoesNotInventRecovery() {
        let app = launch(["--brain-low-data"])
        let confidence = app.staticTexts["brain.confidence"]
        AscendUITestSupport.reveal(confidence, screen: "screen.dashboard", in: app)
        XCTAssertTrue(confidence.label.contains("Low confidence"))
        XCTAssertTrue(app.staticTexts["Learning"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["91%"].exists)
        app.terminate()
    }
    @MainActor func testRecommendationUpdatesWhenSleepInputDisabled() {
        let app = launch(["--brain-poor-sleep"])
        AscendUITestSupport.navigate("workout", in: app)
        XCTAssertTrue(app.staticTexts["Recovery today"].waitForExistence(timeout: 10))
        AscendUITestSupport.navigate("profile", in: app)
        let settings = app.buttons["profile.brain"]
        AscendUITestSupport.reveal(settings, screen: "screen.profile", in: app); settings.tap()
        let sleep = app.switches["brain.settings.sleep"]
        XCTAssertTrue(sleep.waitForExistence(timeout: 10)); XCTAssertTrue(sleep.isHittable); sleep.tap()
        app.buttons["Done"].firstMatch.tap()
        AscendUITestSupport.navigate("workout", in: app)
        XCTAssertTrue(app.buttons["workout.start"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Recovery today"].exists)
        app.terminate()
    }
}
