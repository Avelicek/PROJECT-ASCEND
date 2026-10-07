import XCTest

final class AscendSmokeTests: XCTestCase {
    @MainActor func testNextActionDailyResultAndRecoveryModes() {
        continueAfterFailure = false
        let app = AscendUITestSupport.launchDemo()
        let dashboard = app.scrollViews["screen.dashboard"]
        let next = app.buttons["dashboard.next.action"]
        for _ in 0..<4 { if next.isHittable { break }; dashboard.swipeUp() }
        XCTAssertTrue(next.isHittable); XCTAssertEqual(next.value as? String, "fuel"); next.tap()
        XCTAssertTrue(app.textFields["Calories · kcal"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()
        let details = app.buttons["daily.open"]
        for _ in 0..<5 { if details.isHittable { break }; dashboard.swipeUp() }
        XCTAssertTrue(details.isHittable); details.tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.dailyevaluation"].firstMatch.waitForExistence(timeout: 10))
        let done = app.buttons["Done"]
        for _ in 0..<5 { if done.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(done.isHittable); done.tap()
        AscendUITestSupport.navigate("recovery", in: app)
        for mode in ["load", "fatigue", "recovery"] {
            let button = app.buttons["body.metric.\(mode)"]
            XCTAssertTrue(button.waitForExistence(timeout: 10)); button.tap()
            XCTAssertEqual(button.value as? String, "Selected")
        }
        app.terminate()
    }
    @MainActor func testDeterministicRankRewardPresentation() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launchArguments = ["--demo", "--ui-testing", "--rank-reward"]; app.launch()
        let reward = app.descendants(matching: .any)["screen.rankreward"].firstMatch
        XCTAssertTrue(reward.waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["RANK UP"].exists)
        XCTAssertTrue(app.staticTexts["PLATINUM III"].exists)
        app.buttons["rank.reward.done"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["screen.dailyevaluation"].firstMatch.waitForExistence(timeout: 10))
        app.terminate()
    }
    @MainActor func testLiveWorkoutSetRestResumeAndSummary() {
        continueAfterFailure = false
        let app = AscendUITestSupport.launchDemo()
        AscendUITestSupport.navigate("workout", in: app)
        let start = app.buttons["workout.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10)); start.tap()
        let add = app.buttons["live.add.exercise"]
        XCTAssertTrue(add.waitForExistence(timeout: 10)); add.tap()
        let bench = app.buttons["live.choose.chest_press"]
        XCTAssertTrue(bench.waitForExistence(timeout: 10)); bench.tap()
        let screen = app.scrollViews["screen.liveworkout"]
        let kg = app.textFields["live.set.kg"].firstMatch
        for _ in 0..<6 { if kg.isHittable { break }; screen.swipeUp() }
        XCTAssertTrue(kg.isHittable)
        kg.tap()
        let complete = app.buttons["live.keyboard.complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 10)); complete.tap()
        let pause = app.buttons["live.rest.pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 10)); pause.tap()
        XCTAssertEqual(pause.label, "Resume")
        app.buttons["live.minimize"].tap()
        AscendUITestSupport.navigate("dashboard", in: app)
        AscendUITestSupport.navigate("workout", in: app)
        app.buttons["workout.start"].tap()
        XCTAssertTrue(app.buttons["live.rest.pause"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["live.rest.pause"].label, "Resume")
        app.buttons["live.rest.skip"].tap()
        XCTAssertEqual(app.staticTexts["live.rest.state"].label, "Ready")
        app.buttons["live.finish"].tap()
        let confirm = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Finish workout", "live.finish")).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10)); confirm.tap()
        XCTAssertTrue(app.scrollViews["screen.workoutsummary"].waitForExistence(timeout: 10))
        let done = app.buttons["live.summary.done"]
        for _ in 0..<6 { if done.isHittable { break }; app.scrollViews["screen.workoutsummary"].swipeUp() }
        XCTAssertTrue(done.isHittable); done.tap()
        XCTAssertTrue(app.scrollViews["screen.workout"].waitForExistence(timeout: 10))
        app.terminate()
    }
    @MainActor func testDemoLaunchAndAllFiveDestinations() {
        continueAfterFailure = false
        let app = AscendUITestSupport.launchDemo()
        for destination in AscendUITestSupport.destinations {
            XCTContext.runActivity(named: "Navigate to \(destination)") { _ in
                AscendUITestSupport.navigate(destination, in: app)
            }
        }
        XCTAssertEqual(app.staticTexts["profile.name"].label, "Alex")
        let badge = app.descendants(matching: .any)["profile.rank.badge"].firstMatch
        XCTAssertEqual(badge.value as? String, "rank_platinum_2")
        app.terminate()
    }

    @MainActor func testLaunchWithoutDemoOrModelInference() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertTrue(app.scrollViews["screen.dashboard"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.staticTexts["demo.marker"].exists)
        // Fresh simulator install still exposes the deterministic Personal Brain without model inference.
        let brain = app.descendants(matching: .any)["brain.hero"].firstMatch
        for _ in 0..<8 {
            if brain.exists { break }
            app.scrollViews["screen.dashboard"].swipeUp()
        }
        XCTAssertTrue(brain.exists)
        XCTAssertTrue(app.staticTexts["brain.confidence"].exists)
        XCTAssertEqual(app.state, .runningForeground)
        app.terminate()
    }

    @MainActor func testRecoveryRegionSelectionAndFrontBackControls() {
        continueAfterFailure = false
        let app = AscendUITestSupport.launchDemo()
        AscendUITestSupport.navigate("recovery", in: app)
        let screen = app.scrollViews["screen.recovery"]
        let glutes = app.buttons["body.region.glutes"]
        for _ in 0..<4 {
            if glutes.isHittable && glutes.frame.maxY < app.buttons["tab.workout"].frame.minY - 12 { break }
            screen.swipeUp()
        }
        XCTAssertTrue(glutes.isHittable)
        XCTAssertLessThan(glutes.frame.maxY, app.buttons["tab.workout"].frame.minY - 12, "Reveal the entire control above the bottom navigation before tapping")
        glutes.tap()
        XCTAssertEqual(glutes.value as? String, "Selected")
        for _ in 0..<4 {
            if app.buttons["body.view.front"].isHittable { break }
            screen.swipeDown()
        }
        let front = app.buttons["body.view.front"]
        let back = app.buttons["body.view.back"]
        XCTAssertTrue(front.isHittable)
        XCTAssertEqual(back.value as? String, "Selected")
        front.tap()
        XCTAssertEqual(front.value as? String, "Selected")
        back.tap()
        XCTAssertEqual(back.value as? String, "Selected")
        app.terminate()
    }
}
