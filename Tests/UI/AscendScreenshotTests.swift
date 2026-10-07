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
    }
}
