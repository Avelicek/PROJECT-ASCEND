import XCTest
#if canImport(AscendCore)
@testable import AscendCore
#else
@testable import ASCEND
#endif

final class SemanticStatusTests: XCTestCase {
    func testUnknownDataNeverLooksReady() {
        for value in [nil, Double.nan, Double.infinity] as [Double?] {
            XCTAssertEqual(SemanticStatus.recovery(value), .unknown)
            XCTAssertEqual(SemanticStatus.fatigue(value), .unknown)
            XCTAssertEqual(SemanticStatus.momentum(value), .unknown)
            XCTAssertEqual(SemanticStatus.dailyCompletion(value), .unknown)
        }
        XCTAssertEqual(SemanticStatus.confidence(.low), .unknown)
    }
    func testLowSleepQualityCannotReceiveExcellentStatus() {
        XCTAssertEqual(SemanticStatus.sleep(hours: 8, target: 8, quality: 1), .low)
        XCTAssertEqual(SemanticStatus.sleep(hours: 8, target: 8, quality: 2), .watch)
        XCTAssertEqual(SemanticStatus.sleep(hours: 3, target: 8, quality: 5), .low)
        XCTAssertEqual(SemanticStatus.sleep(hours: nil, target: 8, quality: 5), .unknown)
    }
    func testPartlyLoggedDayNeedsAttentionWithoutFailure() {
        XCTAssertEqual(SemanticStatus.dailyCompletion(0), .watch)
        XCTAssertEqual(SemanticStatus.dailyCompletion(0.4), .watch)
        XCTAssertEqual(SemanticStatus.dailyCompletion(1), .excellent)
    }
    func testFatigueAndRecoveryUseOppositeMeanings() {
        XCTAssertEqual(SemanticStatus.recovery(98), .excellent)
        XCTAssertEqual(SemanticStatus.fatigue(98), .low)
        XCTAssertEqual(SemanticStatus.recovery(10), .low)
        XCTAssertEqual(SemanticStatus.fatigue(10), .good)
    }
}
