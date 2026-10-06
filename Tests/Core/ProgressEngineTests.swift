import Foundation
import XCTest
#if canImport(AscendCore)
@testable import AscendCore
#else
@testable import ASCEND
#endif

final class ProgressEngineTests: XCTestCase {
    private let policy = DayPolicy(timeZoneIdentifier: "Europe/Prague")
    private let now = Date(timeIntervalSince1970: 1_791_288_000)
    func testGainingAndLosingGoalProgress() throws {
        XCTAssertEqual(try XCTUnwrap(ProgressEngine().goalProgress(start: 56, target: 60, current: 58)), 0.5)
        XCTAssertEqual(try XCTUnwrap(ProgressEngine().goalProgress(start: 80, target: 70, current: 75)), 0.5)
    }
    func testProgressClampAndEqualGoal() {
        let engine = ProgressEngine()
        XCTAssertEqual(engine.goalProgress(start: 56, target: 60, current: 54), 0)
        XCTAssertEqual(engine.goalProgress(start: 56, target: 60, current: 62), 1)
        XCTAssertEqual(engine.goalProgress(start: 60, target: 60, current: 60), 1)
        XCTAssertEqual(engine.goalProgress(start: 60, target: 60, current: 59), 0)
        XCTAssertNil(engine.goalProgress(start: .nan, target: 60, current: 59))
    }
    func testTrendSmoothsFluctuations() {
        let samples = (0..<7).map { WeightSample(date: policy.adding(days: $0 - 6, to: now), kilograms: $0 == 6 ? 62 : 56) }
        let result = ProgressEngine().trend(samples: samples, policy: policy)
        XCTAssertEqual(result.last?.kilograms ?? 0, 56 + 6.0 / 7, accuracy: 0.0001)
    }
    func testDuplicateDaysDoNotOverweightTrend() {
        let yesterday = policy.adding(days: -1, to: now)
        let samples = [WeightSample(date: yesterday, kilograms: 54), .init(date: now, kilograms: 58), .init(date: now, kilograms: 60)]
        XCTAssertEqual(ProgressEngine().trend(samples: samples, policy: policy).last?.kilograms, 56.5)
    }
    func testSparseCalendarWindowDoesNotUseOldMeasurements() {
        let samples = [WeightSample(date: policy.adding(days: -30, to: now), kilograms: 50), .init(date: now, kilograms: 60)]
        XCTAssertEqual(ProgressEngine().trend(samples: samples, policy: policy).last?.kilograms, 60)
    }
    func testMomentumSupportsBothDirectionsAndGoalDirections() throws {
        for slope in [-0.05, 0.05] {
            let samples = (0...20).map { WeightSample(date: policy.adding(days: $0 - 20, to: now), kilograms: 56 + Double($0) * slope) }
            let gaining = ProgressEngine().report(samples: samples, start: 56, target: 60, desiredWeeklyChange: 0.5, now: now, policy: policy)
            let losing = ProgressEngine().report(samples: samples, start: 56, target: 50, desiredWeeklyChange: 0.5, now: now, policy: policy)
            XCTAssertEqual(try XCTUnwrap(gaining.momentumPercent).sign, slope.sign)
            XCTAssertEqual(try XCTUnwrap(losing.momentumPercent).sign, (-slope).sign)
        }
    }
    func testNoDataAndStaleDataHaveNoMomentum() {
        let empty = ProgressEngine().report(samples: [], start: nil, target: nil, desiredWeeklyChange: 0.25, now: now, policy: policy)
        XCTAssertNil(empty.goalProgress); XCTAssertNil(empty.momentumPercent); XCTAssertEqual(empty.confidence, .low)
        let samples = (0...20).map { WeightSample(date: policy.adding(days: $0 - 50, to: now), kilograms: 56 + Double($0) * 0.02) }
        let stale = ProgressEngine().report(samples: samples, start: 56, target: 60, desiredWeeklyChange: 0.25, now: now, policy: policy)
        XCTAssertNil(stale.momentumPercent); XCTAssertEqual(stale.confidence, .low)
    }
    func testInvalidAndFutureWeightsAreIgnored() {
        let samples = [WeightSample(date: now, kilograms: 56), .init(date: now, kilograms: .nan),
                       .init(date: now, kilograms: -4), .init(date: now.addingTimeInterval(100), kilograms: 90)]
        let result = ProgressEngine().report(samples: samples, start: 56, target: 60, desiredWeeklyChange: 0.25, now: now, policy: policy)
        XCTAssertEqual(result.actualWeight, 56); XCTAssertEqual(result.trendWeight, 56)
    }
}
