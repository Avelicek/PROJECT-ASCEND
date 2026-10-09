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
        XCTAssertTrue(app.buttons["dashboard.daily.elo"].waitForExistence(timeout: 10))
        let finalized = app.staticTexts["dashboard.previous.elo"]
        XCTAssertTrue(finalized.waitForExistence(timeout: 10))
        XCTAssertEqual(finalized.value as? String, "1084", "The fixture must preserve its finalized ELO history")
        // Rank artwork is exercised on Profile and in capture tests; collapsed detail is not a launch requirement.
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

    static func reveal(_ element: XCUIElement, screen: String, in app: XCUIApplication) {
        let scroll = app.scrollViews[screen]
        let tab = app.buttons["tab.dashboard"]
        let bottom = tab.exists ? tab.frame.minY - 16 : scroll.frame.maxY - 16
        for _ in 0..<12 {
            if element.isHittable && element.frame.minY > scroll.frame.minY + 8 && element.frame.maxY < bottom { break }
            if element.exists && element.frame.minY <= scroll.frame.minY + 8 { scroll.swipeDown() }
            else { scroll.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
        XCTAssertLessThan(element.frame.maxY, bottom, "Reveal the entire control above navigation before tapping")
    }
}
