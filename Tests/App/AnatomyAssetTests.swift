import Foundation
import XCTest
import RealityKit
@testable import ASCEND

final class AnatomyAssetTests: XCTestCase {
    @MainActor func testBundledLicensedMuscleAssetLoadsWithRealMappedMeshesAndYUpBounds() async throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "AscendMuscles", withExtension: "usdz", subdirectory: "Anatomy"))
        let entity = try await Entity(contentsOf: url)
        var names = Set<String>(), modelCount = 0
        func inspect(_ item: Entity) {
            names.insert(item.name)
            if item is ModelEntity { modelCount += 1 }
            for child in item.children { inspect(child) }
        }
        inspect(entity)
        XCTAssertGreaterThanOrEqual(modelCount, 400)
        XCTAssertTrue(Set(AnatomyMeshMapping.muscles.keys).isSubset(of: names))
        let bounds = entity.visualBounds(relativeTo: nil)
        XCTAssertGreaterThan(bounds.extents.y, 1.5)
        XCTAssertLessThan(bounds.extents.y, 2.2)
        XCTAssertLessThan(bounds.extents.x, bounds.extents.y)
        XCTAssertLessThan(bounds.extents.z, bounds.extents.y)
    }
}
