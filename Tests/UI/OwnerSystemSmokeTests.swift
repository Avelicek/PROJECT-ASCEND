import XCTest

final class OwnerSystemSmokeTests: XCTestCase {
    @MainActor private func pressContinue(_ app: XCUIApplication) {
        let button = app.buttons["onboarding.continue"]
        AscendUITestSupport.reveal(button, screen: "screen.onboarding", in: app)
        button.tap()
    }
    @MainActor func testFreshOnboardingThenTypedResetReturnsToSetup() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--fresh-ui-testing", "--ui-testing"]; app.launch()
        XCTAssertTrue(app.scrollViews["screen.onboarding"].waitForExistence(timeout: 20))
        let name = app.textFields["onboarding.name"]; name.tap(); name.typeText("Owner")
        app.buttons["Done"].firstMatch.tap()
        for _ in 0..<8 { pressContinue(app) }
        XCTAssertTrue(app.scrollViews["screen.dashboard"].waitForExistence(timeout: 20))
        AscendUITestSupport.navigate("profile", in: app)
        let data = app.buttons["profile.data"]; AscendUITestSupport.reveal(data, screen: "screen.profile", in: app); data.tap()
        XCTAssertTrue(app.scrollViews["screen.data"].waitForExistence(timeout: 10))
        let reset = app.buttons["data.reset"]; AscendUITestSupport.reveal(reset, screen: "screen.data", in: app); reset.tap()
        let erase = app.buttons["reset.erase"]
        XCTAssertTrue(erase.waitForExistence(timeout: 10)); XCTAssertFalse(erase.isEnabled)
        app.switches["reset.consent"].tap(); XCTAssertFalse(erase.isEnabled)
        let phrase = app.textFields["reset.phrase"]; phrase.tap(); phrase.typeText("RESET ASCEND"); app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(erase.isEnabled); erase.tap()
        XCTAssertTrue(app.scrollViews["screen.onboarding"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["Owner"].exists)
    }
    @MainActor func testRecordedSleepSurvivesProcessRestartAndSavesWakeDay() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--owner-fixture", "--ui-testing", "--fixture-recorded-sleep"]
        app.launchEnvironment["ASCEND_TEST_RUN"] = UUID().uuidString
        app.launch()
        let end = app.buttons["sleep.end"]
        XCTAssertTrue(end.waitForExistence(timeout: 20))
        let started = app.staticTexts["sleep.started"].label
        XCTAssertFalse(app.buttons["tab.dashboard"].exists)
        XCTAssertFalse(app.scrollViews["screen.dashboard"].exists)
        app.terminate(); app.launch()
        XCTAssertTrue(end.waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["sleep.started"].label, started)
        XCTAssertFalse(app.buttons["tab.workout"].exists)
        end.tap(); XCTAssertTrue(app.scrollViews["screen.endsleep"].waitForExistence(timeout: 10))
        let save = app.buttons["sleep.save"]; AscendUITestSupport.reveal(save, screen: "screen.endsleep", in: app); save.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.checkin"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.scrollViews["screen.dashboard"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["sleep.end"].exists)
    }
    @MainActor func testExerciseObjectiveQuickLogIsRealAndSickProtectionIsVisible() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--demo", "--ui-testing", "--capture-objectives"]; app.launch()
        XCTAssertTrue(app.scrollViews["screen.objectives"].waitForExistence(timeout: 20))
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "100 push-ups")).firstMatch
        AscendUITestSupport.reveal(row, screen: "screen.objectives", in: app); row.tap()
        XCTAssertTrue(app.scrollViews["screen.objectiveactivity"].waitForExistence(timeout: 10))
        let log = app.buttons["objective.log"]; AscendUITestSupport.reveal(log, screen: "screen.objectiveactivity", in: app); log.tap()
        XCTAssertTrue(app.scrollViews["screen.objectives"].waitForExistence(timeout: 10))
        XCTAssertTrue(row.label.contains("80"), "A quick log adds twenty real reps to the existing sixty.")
        app.buttons["Done"].firstMatch.tap()
        AscendUITestSupport.navigate("dashboard", in: app)
        let sick = app.buttons["sick.open"]; AscendUITestSupport.reveal(sick, screen: "screen.dashboard", in: app); sick.tap()
        XCTAssertTrue(app.buttons["sick.start"].waitForExistence(timeout: 10)); app.buttons["sick.start"].tap()
        let done = app.buttons["Done"].firstMatch
        AscendUITestSupport.reveal(done, screen: "screen.sickmode", in: app); done.tap()
        let protection = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Recovery prioritized")).firstMatch
        XCTAssertTrue(protection.waitForExistence(timeout: 10))
        let endSick = app.buttons["sick.global.end"]
        XCTAssertTrue(endSick.isHittable); endSick.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.sickmode"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["sick.finish"].waitForExistence(timeout: 10))
    }
}
