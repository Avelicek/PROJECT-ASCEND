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
    }
}
