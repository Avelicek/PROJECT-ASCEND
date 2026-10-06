import Foundation
import XCTest
#if canImport(AscendCore)
@testable import AscendCore
#else
@testable import ASCEND
#endif

final class RankEngineTests: XCTestCase {
    private let ladder: [(RankTier, Int, Int)] = [
        (.bronze, 1, 100), (.bronze, 2, 150), (.bronze, 3, 250),
        (.silver, 1, 350), (.silver, 2, 450), (.silver, 3, 550),
        (.gold, 1, 650), (.gold, 2, 750), (.gold, 3, 850),
        (.platinum, 1, 950), (.platinum, 2, 1050), (.platinum, 3, 1200),
        (.diamond, 1, 1350), (.diamond, 2, 1500), (.diamond, 3, 1700),
        (.conqueror, 1, 2000), (.conqueror, 2, 2150), (.conqueror, 3, 2400)
    ]
    func testExactLadderAndEveryBoundary() {
        let engine = RankEngine()
        XCTAssertEqual(RankEngine.ranks.dropFirst().map(\.threshold), ladder.map { $0.2 })
        for (index, entry) in ladder.enumerated() {
            let at = engine.status(elo: entry.2)
            XCTAssertEqual(at.rank.tier, entry.0); XCTAssertEqual(at.rank.division, entry.1)
            XCTAssertEqual(at.lowerThreshold, entry.2)
            XCTAssertEqual(at.progress, index == 17 ? 1 : 0)
            let below = engine.status(elo: entry.2 - 1)
            XCTAssertEqual(below.rank.tier, index == 0 ? .unranked : ladder[index - 1].0)
            XCTAssertEqual(below.rank.division, index == 0 ? 0 : ladder[index - 1].1)
            let above = engine.status(elo: entry.2 + 1)
            XCTAssertEqual(above.rank, at.rank)
        }
    }
    func testEveryBoundaryTransitionsBothDirections() {
        for entry in ladder {
            let up = RankEngine().status(elo: entry.2, previousELO: entry.2 - 1)
            XCTAssertTrue(up.rankedUp); XCTAssertFalse(up.rankedDown)
            let down = RankEngine().status(elo: entry.2 - 1, previousELO: entry.2)
            XCTAssertTrue(down.rankedDown); XCTAssertFalse(down.rankedUp)
        }
    }
    func testUnrankedAndNegativeInputs() {
        for elo in [Int.min, -1, 0, 99] {
            let result = RankEngine().status(elo: elo)
            XCTAssertEqual(result.rank.tier, .unranked); XCTAssertEqual(result.elo, max(0, elo))
            XCTAssertEqual(result.nextThreshold, 100)
        }
    }
    func testProgressUsesCurrentDivisionWidth() {
        let result = RankEngine().status(elo: 1125)
        XCTAssertEqual(result.rank.title, "PLATINUM II")
        XCTAssertEqual(result.progress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(result.amountToNext, 75)
    }
    func testTopRankHasNoCeiling() {
        for elo in [2400, 2401, 100_000, Int.max] {
            let result = RankEngine().status(elo: elo)
            XCTAssertEqual(result.rank.title, "CONQUEROR III"); XCTAssertEqual(result.elo, elo)
            XCTAssertEqual(result.progress, 1); XCTAssertNil(result.nextThreshold); XCTAssertNil(result.amountToNext)
        }
    }
    func testAssetNamesAreStableAndUnique() {
        let names = RankEngine.ranks.compactMap(\.assetName)
        XCTAssertEqual(names.count, 18); XCTAssertEqual(Set(names).count, 18)
        XCTAssertEqual(names.first, "rank_bronze_1"); XCTAssertEqual(names.last, "rank_conqueror_3")
    }
    func testUnchangedAndMultiRankTransitions() {
        XCTAssertFalse(RankEngine().status(elo: 149, previousELO: 101).rankedUp)
        XCTAssertTrue(RankEngine().status(elo: 2200, previousELO: 100).rankedUp)
        XCTAssertTrue(RankEngine().status(elo: 90, previousELO: 2200).rankedDown)
    }
    func testProgressIsBoundedAcrossLadder() {
        for elo in -10...5000 { XCTAssertTrue((0...1).contains(RankEngine().status(elo: elo).progress)) }
    }
}
