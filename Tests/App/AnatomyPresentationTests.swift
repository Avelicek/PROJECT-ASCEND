import XCTest
import SwiftUI
@testable import ASCEND

final class AnatomyPresentationTests: XCTestCase {
    @MainActor func testSelectionAlwaysHasVisibleGeometryAfterModeChanges() {
        for region in BodyRegion.allCases {
            var presentation = AnatomyPresentation()
            presentation.select(region)
            XCTAssertEqual(presentation.selected, region)
            XCTAssertTrue(region.isVisible(in: presentation.mode))
            for mode in BodyViewMode.allCases {
                presentation.show(mode)
                XCTAssertTrue(presentation.selected.isVisible(in: mode))
                XCTAssertTrue(StylizedAnatomyAsset().patches(for: mode).contains { $0.region == presentation.selected })
            }
        }
        var presentation = AnatomyPresentation()
        presentation.select(.glutes)
        XCTAssertEqual(presentation.mode, .back)
        presentation.show(.front)
        XCTAssertEqual(presentation.selected, .chest)
        presentation.select(.arms)
        presentation.show(.back)
        XCTAssertEqual(presentation.selected, .arms)
    }

    @MainActor func testGeometryHasDistinctSurfacesAndCompleteVisibleRegionCoverage() {
        let asset = StylizedAnatomyAsset()
        let rect = CGRect(x: 20, y: 20, width: 200, height: 460)
        for mode in BodyViewMode.allCases {
            let patches = asset.patches(for: mode)
            XCTAssertGreaterThan(patches.count, 30)
            XCTAssertEqual(Set(patches.map(\.id)).count, patches.count)
            XCTAssertEqual(Set(patches.map(\.region)), Set(BodyRegion.allCases.filter { $0.isVisible(in: mode) }))
            for patch in patches {
                XCTAssertFalse(patch.path(in: rect).isEmpty)
                XCTAssertTrue(rect.insetBy(dx: -2, dy: -2).contains(patch.path(in: rect).boundingRect))
            }
        }
        XCTAssertNotEqual(Set(asset.patches(for: .front).map(\.id)), Set(asset.patches(for: .back).map(\.id)))
    }

    @MainActor func testUnknownRegionsExposeNoInventedPercentLoadFatigueOrConfidence() {
        let report = RecoveryEngine().evaluate(loads: [], context: .init(), now: Date())
        for region in BodyRegion.allCases {
            let state = region.visualization(in: report)
            XCTAssertEqual(state.phase, .unknown)
            XCTAssertNil(state.percent)
            XCTAssertNil(state.load)
            XCTAssertNil(state.fatigue)
            XCTAssertNil(state.confidence)
        }
    }

    @MainActor func testRegionUsesLimitingRecoveryAndConservativeConfidence() {
        let now = Date()
        func muscle(_ muscle: Muscle, _ percent: Double, _ confidence: Confidence) -> MuscleRecovery {
            MuscleRecovery(muscle: muscle, recoveryPercent: percent, load: 5, fatigue: 3,
                lastTrainedAt: now, estimatedRecoveryTime: nil, confidence: confidence)
        }
        for (percent, phase) in [(49.0, RegionPhase.recovering), (50.0, .rebuilding), (84.0, .rebuilding), (85.0, .ready)] {
            let report = ReadinessReport(percent: 100, state: .primed, muscles: [muscle(.upperPectoral, 100, .high), muscle(.midPectoral, percent, .low)], confidence: .high)
            let state = BodyRegion.chest.visualization(in: report)
            XCTAssertEqual(state.percent, percent)
            XCTAssertEqual(state.phase, phase)
            XCTAssertEqual(state.confidence, .low)
            XCTAssertEqual(state.load, 10)
            XCTAssertEqual(state.fatigue, 3)
            XCTAssertEqual(state.limitingMuscle, Muscle.midPectoral.title)
        }
    }
}
