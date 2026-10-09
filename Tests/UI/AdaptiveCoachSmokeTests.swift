import XCTest

final class AdaptiveCoachSmokeTests: XCTestCase {
    @MainActor func testMorningCheckInAndDataGroundedAskAscend() {
        continueAfterFailure = false
        let app = AscendUITestSupport.launchDemo()
        let checkIn = app.buttons["coach.checkin"]
        AscendUITestSupport.reveal(checkIn, screen: "screen.dashboard", in: app); checkIn.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.checkin"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["checkin.submit"].exists)
        app.buttons["Done"].firstMatch.tap()
        let ask = app.buttons["coach.open.ask"]
        AscendUITestSupport.reveal(ask, screen: "screen.dashboard", in: app); ask.tap()
        XCTAssertTrue(app.scrollViews["screen.askascend"].waitForExistence(timeout: 10))
        let elo = app.buttons["Why did I lose ELO?"]
        AscendUITestSupport.reveal(elo, screen: "screen.askascend", in: app); elo.tap()
        XCTAssertTrue(app.staticTexts["OBSERVED"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Today's ELO:")).firstMatch.exists)
        app.terminate()
    }
    @MainActor func testQuickPushUpsAreIntegratedAndCannotDuplicateOnDone() {
        continueAfterFailure = false
        let app = AscendUITestSupport.launchDemo()
        AscendUITestSupport.navigate("workout", in: app)
        let push = app.buttons["quick.push_up"]
        AscendUITestSupport.reveal(push, screen: "screen.workout", in: app); push.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.quickactivity"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["quick.save"].tap()
        XCTAssertTrue(app.staticTexts["Activity integrated"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["quick.save"].exists)
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.scrollViews["screen.workout"].waitForExistence(timeout: 10))
        app.terminate()
    }
    @MainActor func testTimedExercisePauseFinishAndEffortReview() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--demo", "--ui-testing", "--capture-timer"]; app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["screen.exercisetimer"].firstMatch.waitForExistence(timeout: 20))
        let pause = app.buttons["exercise.timer.pause"]
        XCTAssertEqual(pause.label, "Resume"); pause.tap(); XCTAssertEqual(pause.label, "Pause")
        pause.tap(); app.buttons["exercise.timer.finish"].tap()
        XCTAssertTrue(app.scrollViews["screen.liveworkout"].waitForExistence(timeout: 10))
        let review = app.descendants(matching: .any)["live.effort.review"].firstMatch
        AscendUITestSupport.reveal(review, screen: "screen.liveworkout", in: app)
        XCTAssertTrue(review.exists)
        app.terminate()
    }

    @MainActor func testGoalCoachAttachesContextAndChangesGoalThroughRealEditor() {
        continueAfterFailure = false
        let app = AscendUITestSupport.launchDemo()
        AscendUITestSupport.navigate("progress", in: app)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Momentum")).firstMatch.exists)
        let coach = app.buttons["goal.coach"]
        AscendUITestSupport.reveal(coach, screen: "screen.progress", in: app); coach.tap()
        XCTAssertTrue(app.scrollViews["screen.goalcoach"].waitForExistence(timeout: 10))
        app.buttons["goal.faster"].tap()
        let change = app.buttons["goal.change"]; AscendUITestSupport.reveal(change, screen: "screen.goalcoach", in: app); change.tap()
        XCTAssertTrue(app.navigationBars["Profile & goals"].waitForExistence(timeout: 10))
        app.terminate()
    }
    @MainActor func testSleepSummaryIsShownBeforeActivationAndSickAllowsBrowsing() {
        continueAfterFailure = false
        let app = AscendUITestSupport.launchDemo()
        let start = app.buttons["sleep.start"]
        AscendUITestSupport.reveal(start, screen: "screen.dashboard", in: app); start.tap()
        XCTAssertTrue(app.scrollViews["screen.sleepsummary"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["screen.sleepmode"].firstMatch.exists)
        let confirm = app.buttons["sleep.confirm.start"]
        AscendUITestSupport.reveal(confirm, screen: "screen.sleepsummary", in: app); confirm.tap()
        XCTAssertTrue(app.buttons["sleep.end"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["tab.progress"].exists)
        app.terminate()
        app.launchArguments = ["--demo", "--ui-testing", "--capture-sick"]; app.launch()
        XCTAssertTrue(app.buttons["sick.global.end"].waitForExistence(timeout: 20))
        AscendUITestSupport.navigate("progress", in: app)
        XCTAssertTrue(app.buttons["sick.global.end"].exists)
        AscendUITestSupport.navigate("workout", in: app)
        XCTAssertFalse(app.buttons["workout.start"].exists)
        app.terminate()
    }
}
