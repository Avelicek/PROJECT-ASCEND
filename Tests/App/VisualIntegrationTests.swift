import XCTest
import UIKit
@testable import ASCEND

final class VisualIntegrationTests: XCTestCase {
    @MainActor func testEveryRankResolvesToPackagedOwnerArtwork() {
        let ranked = RankEngine.ranks.filter { $0.tier != .unranked }
        XCTAssertEqual(ranked.count, 18)
        XCTAssertEqual(RankBadgeAsset.allCases.count, 18)
        for rank in ranked {
            let asset = RankBadgeAsset.resolve(rank)
            XCTAssertEqual(asset?.rawValue, rank.assetName)
            XCTAssertNotNil(asset)
            if let asset { XCTAssertNotNil(UIImage(named: asset.rawValue), "Missing compiled artwork for \(rank.title)") }
        }
        XCTAssertNil(RankBadgeAsset.resolve(RankEngine.ranks[0]))
    }

    @MainActor func testBodyMapKeepsUnloggedRegionsUnknownAndUsesLowestLoggedMuscle() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let load = TrainingLoad(date: now, contributions: [
            MuscleContribution(.upperPectoral, 0.7),
            MuscleContribution(.midPectoral, 0.3)
        ], challengingSets: 5, intensity: 1)
        let report = RecoveryEngine().evaluate(loads: [load], context: RecoveryContext(), now: now)
        let lowest = report.muscles.filter { $0.muscle.group == "Chest" && $0.lastTrainedAt != nil }.map(\.recoveryPercent).min()
        XCTAssertEqual(BodyRegion.chest.recovery(in: report), lowest)
        XCTAssertNil(BodyRegion.legs.recovery(in: report))
        XCTAssertEqual(Set(BodyRegion.allCases.map(\.rawValue)), Set(Muscle.allCases.map(\.group)))
    }
}
