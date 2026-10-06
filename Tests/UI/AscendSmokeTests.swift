import XCTest

final class AscendSmokeTests: XCTestCase {
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
        // Fresh simulator install: on-device AI is off. The local insight is available offline.
        let insight = app.descendants(matching: .any)["brain.source"].firstMatch
        for _ in 0..<8 {
            if insight.exists && insight.isHittable { break }
            app.scrollViews["screen.dashboard"].swipeUp()
        }
        XCTAssertTrue(insight.exists)
        XCTAssertEqual(insight.value as? String, "deterministic")
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
            if glutes.isHittable { break }
            screen.swipeUp()
        }
        XCTAssertTrue(glutes.isHittable)
        glutes.tap()
        XCTAssertEqual(glutes.value as? String, "Selected")
        let picker = app.descendants(matching: .any)["body.view"].firstMatch
        for _ in 0..<4 {
            if picker.exists && picker.isHittable { break }
            screen.swipeDown()
        }
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let backButton = picker.buttons["Back"].firstMatch
        let frontButton = picker.buttons["Front"].firstMatch
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        XCTAssertTrue(frontButton.waitForExistence(timeout: 5))
        XCTAssertTrue(backButton.isSelected)
        frontButton.tap()
        XCTAssertTrue(frontButton.isSelected)
        app.terminate()
    }
}
