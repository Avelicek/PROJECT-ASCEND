import XCTest
import UIKit
@testable import ASCEND

final class VisualIntegrationTests: XCTestCase {
    @MainActor func testExplicitRankArtworkContractAtEveryBoundary() {
        let contract: [(RankTier, Int, RankBadgeAsset, String)] = [
            (.bronze, 1, .bronzeI, "bronze (1).png"), (.bronze, 2, .bronzeII, "bronze (2).png"), (.bronze, 3, .bronzeIII, "bronze (3).png"),
            (.silver, 1, .silverI, "silver (1).png"), (.silver, 2, .silverII, "silver (2).png"), (.silver, 3, .silverIII, "silver (3).png"),
            (.gold, 1, .goldI, "gold (1).png"), (.gold, 2, .goldII, "gold (2).png"), (.gold, 3, .goldIII, "gold (3).png"),
            (.platinum, 1, .platinumI, "plat (1).png"), (.platinum, 2, .platinumII, "plat (2).png"), (.platinum, 3, .platinumIII, "plat (3).png"),
            (.diamond, 1, .diamondI, "diamond (1).png"), (.diamond, 2, .diamondII, "diamond (2).png"), (.diamond, 3, .diamondIII, "diamond (3).png"),
            (.conqueror, 1, .conquerorI, "conq1.png"), (.conqueror, 2, .conquerorII, "conq2.png"), (.conqueror, 3, .conquerorIII, "conq3.png")
        ]
        for (tier, division, asset, filename) in contract {
            let rank = RankEngine.ranks.first { $0.tier == tier && $0.division == division }!
            XCTAssertEqual(RankBadgeAsset.resolve(rank), asset)
            XCTAssertEqual(asset.sourceFilename, filename)
            XCTAssertEqual(RankBadgeAsset.resolve(RankEngine().status(elo: rank.threshold).rank), asset)
            XCTAssertNotNil(UIImage(named: asset.rawValue))
        }
        XCTAssertEqual(RankBadgeAsset.resolve(RankEngine().status(elo: 1084).rank), .platinumII)
        XCTAssertEqual(RankBadgeAsset.resolve(RankEngine().status(elo: 1199).rank), .platinumII)
        XCTAssertEqual(RankBadgeAsset.resolve(RankEngine().status(elo: 1200).rank), .platinumIII)
        XCTAssertNil(RankBadgeAsset.resolve(Rank(tier: .platinum, division: 4, threshold: 0)))
    }

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
