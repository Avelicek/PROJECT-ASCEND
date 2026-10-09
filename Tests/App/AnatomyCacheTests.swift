import XCTest
import RealityKit
@testable import ASCEND

final class AnatomyCacheTests: XCTestCase {
    @MainActor func testReopeningReusesDecodeAndProducesIndependentSceneGraphs() async throws {
        let cache = AnatomyAssetCache.shared
        let coldStart = Date(); let first = try await cache.clone(); let firstTime = Date().timeIntervalSince(coldStart)
        let decoded = cache.decodeCount
        let warmStart = Date(); let second = try await cache.clone(); let secondTime = Date().timeIntervalSince(warmStart)
        XCTAssertEqual(cache.decodeCount, decoded, "Reopening must not decode the USDZ again")
        XCTAssertFalse(first === second)
        XCTAssertEqual(first.children.count, second.children.count)
        XCTAssertGreaterThan(first.children.count, 0)
        let bounds = second.visualBounds(relativeTo: nil)
        XCTAssertEqual(bounds.extents.y, 2, accuracy: 0.1)
        first.position.x += 1
        XCTAssertNotEqual(first.position.x, second.position.x)
        print("ANATOMY CACHE: first clone \(firstTime)s; cached clone \(secondTime)s; USDZ decodes \(decoded)")
    }
}
