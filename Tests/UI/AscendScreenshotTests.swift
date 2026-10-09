import XCTest

final class AscendScreenshotTests: XCTestCase {
    @MainActor func testFiveSeededScreenshots() {
        continueAfterFailure = false
        let app = AscendUITestSupport.launchDemo()
        for (index, destination) in AscendUITestSupport.destinations.enumerated() {
            let name = String(format: "%02d_%@", index + 1, destination)
            XCTContext.runActivity(named: name) { _ in
                // XCUITest synchronizes with the app before tapping and taking a screenshot.
                AscendUITestSupport.navigate(destination, in: app)
                let attachment = XCTAttachment(screenshot: app.screenshot())
                attachment.name = name
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        app.terminate()
        for (argument, name, screen) in [("--capture-live", "06_live_workout", "screen.liveworkout"), ("--capture-summary", "07_workout_summary", "screen.workoutsummary"), ("--capture-daily", "08_daily_evaluation", "screen.dailyevaluation"), ("--capture-library", "09_exercise_library", "screen.exerciselibrary"), ("--capture-routine", "10_routine", "screen.routine"), ("--capture-history", "11_exercise_history", "screen.exercisehistory")] {
            let capture = XCUIApplication()
            capture.launchArguments = ["--demo", "--ui-testing", argument]
            capture.launch()
            XCTAssertTrue(capture.descendants(matching: .any)[screen].firstMatch.waitForExistence(timeout: 20))
            let attachment = XCTAttachment(screenshot: capture.screenshot())
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            capture.terminate()
        }
        for (arguments, name, screen) in [(["--capture-brain-today"], "12_brain_today", "screen.dashboard"), (["--capture-brain-detail"], "13_brain_detail", "screen.braindetail"), (["--brain-low-data"], "14_brain_low_confidence", "screen.dashboard"), (["--capture-summary"], "15_post_workout_brain", "screen.workoutsummary")] {
            let capture = XCUIApplication(); capture.launchArguments = ["--demo", "--ui-testing"] + arguments; capture.launch()
            XCTAssertTrue(capture.descendants(matching: .any)[screen].firstMatch.waitForExistence(timeout: 20))
            if screen == "screen.dashboard" {
                let hero = capture.descendants(matching: .any)["brain.hero"].firstMatch
                for _ in 0..<3 { if hero.isHittable { break }; capture.scrollViews[screen].swipeUp() }
                XCTAssertTrue(hero.exists)
            }
            let attachment = XCTAttachment(screenshot: capture.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            capture.terminate()
        }
        for (argument, name, screen) in [("--capture-onboarding", "16_onboarding", "screen.onboarding"), ("--capture-sleep", "17_sleep_mode", "screen.sleepmode"), ("--capture-end-sleep", "18_end_sleep", "screen.endsleep"), ("--capture-objectives", "19_daily_objectives", "screen.objectives"), ("--capture-sick", "20_sick_mode", "screen.dashboard"), ("--capture-data", "21_data_management", "screen.data")] {
            let capture = XCUIApplication(); capture.launchArguments = ["--demo", "--ui-testing", argument]; capture.launch()
            XCTAssertTrue(capture.descendants(matching: .any)[screen].firstMatch.waitForExistence(timeout: 20))
            let attachment = XCTAttachment(screenshot: capture.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
            capture.terminate()
        }

        for (argument, name, screen) in [("--capture-checkin", "23_morning_checkin", "screen.checkin"), ("--capture-ask", "24_ask_ascend", "screen.askascend"), ("--capture-plan", "25_generated_plan", "screen.generatedplan"), ("--capture-quick", "26_quick_activity", "screen.quickactivity"), ("--capture-timer", "27_exercise_timer", "screen.exercisetimer"), ("--capture-guide", "28_exercise_guide", "screen.exerciseguide"), ("--capture-weekly", "29_weekly_coach", "coach.weekly.analysis"), ("--capture-goal-coach", "30_goal_coach", "screen.goalcoach"), ("--capture-sleep-summary", "31_sleep_summary", "screen.sleepsummary")] {
            let capture = XCUIApplication(); capture.launchArguments = ["--demo", "--ui-testing", argument]; capture.launch()
            let target = capture.descendants(matching: .any)[screen].firstMatch
            if screen == "coach.weekly.analysis" {
                XCTAssertTrue(capture.descendants(matching: .any)["screen.weeklyrecap"].firstMatch.waitForExistence(timeout: 20))
                for _ in 0..<10 { if target.exists && target.isHittable { break }; capture.scrollViews.firstMatch.swipeUp() }
            }
            XCTAssertTrue(target.waitForExistence(timeout: 20))
            if screen == "screen.goalcoach" { capture.buttons["goal.faster"].tap() }
            let attachment = XCTAttachment(screenshot: capture.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment); capture.terminate()
        }
        let anatomy = XCUIApplication(); anatomy.launchArguments = ["--demo", "--ui-testing", "--capture-anatomy-3d"]; anatomy.launch()
        let model = anatomy.descendants(matching: .any)["anatomy.native"].firstMatch
        XCTAssertTrue(model.waitForExistence(timeout: 45))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Ready"), object: model)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 60), .completed)
        let image = XCTAttachment(screenshot: anatomy.screenshot()); image.name = "22_anatomy_3d"; image.lifetime = .keepAlways; add(image)
        anatomy.terminate()

    }
}
