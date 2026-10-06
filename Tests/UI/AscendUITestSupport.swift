import XCTest

@MainActor enum AscendUITestSupport {
    static let destinations = ["dashboard", "workout", "recovery", "progress", "profile"]

    static func launchDemo() -> XCUIApplication {
        let app = XCUIApplication()
        // DEBUG-only demo data uses a fresh, in-memory SwiftData container.
        // AI is disabled by default in that fixture. No inference is requested.
        app.launchArguments = ["--demo", "--ui-testing"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertTrue(app.scrollViews["screen.dashboard"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["demo.marker"].exists)
        let elo = app.staticTexts["dashboard.elo"]
        XCTAssertTrue(elo.waitForExistence(timeout: 10))
        XCTAssertEqual(elo.value as? String, "1084", "The screenshot fixture must contain seeded history")
        let badge = app.descendants(matching: .any)["dashboard.rank.badge"].firstMatch
        XCTAssertTrue(badge.exists)
        XCTAssertEqual(badge.value as? String, "rank_platinum_2", "The real compiled badge must be loaded")
        return app
    }

    static func navigate(_ destination: String, in app: XCUIApplication) {
        let tab = app.buttons["tab.\(destination)"]
        XCTAssertTrue(tab.waitForExistence(timeout: 10))
        XCTAssertTrue(tab.isHittable)
        tab.tap()
        let screen = app.scrollViews["screen.\(destination)"]
        XCTAssertTrue(screen.waitForExistence(timeout: 10))
        XCTAssertTrue(screen.isHittable, "The selected destination must be rendered and visible")
        XCTAssertEqual(tab.value as? String, "Selected")
        XCTAssertEqual(app.state, .runningForeground)
    }
}
