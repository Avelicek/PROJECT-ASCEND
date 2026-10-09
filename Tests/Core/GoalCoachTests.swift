import Foundation
import XCTest
#if canImport(AscendCore)
@testable import AscendCore
#else
@testable import ASCEND
#endif

final class GoalCoachTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_288_000)
    private let policy = DayPolicy(timeZoneIdentifier: "Europe/Prague")
    private func projection(rate: Double = 0.2, target: Double = 60) -> GoalProjection {
        let samples = (0..<15).map { index in WeightSample(date: policy.adding(days: index - 14, to: now), kilograms: 56 + Double(index) * rate / 7) }
        return ProjectionEngine().weight(samples: samples, target: target, now: now, policy: policy)
    }
    private func negotiate(_ p: GoalProjection, days: Int? = nil, fuel: Double = 1, protected: Bool = false) -> GoalNegotiation {
        GoalCoachEngine().negotiate(projection: p, deadline: days.map { policy.adding(days: $0, to: now) }, faster: days == nil, calories: 2500, fuelCoverage: fuel, protected: protected, now: now, policy: policy)
    }
    func testPrimaryETAFollowsRegressionAndRetainsBounds() throws {
        let p = projection()
        let date = try XCTUnwrap(p.estimatedDate)
        let weeks = try XCTUnwrap(p.estimatedWeeks)
        XCTAssertEqual(weeks, Int(((60 - (p.current ?? 0)) / 0.2).rounded()))
        XCTAssertGreaterThan(date, try XCTUnwrap(p.earliest)); XCTAssertLessThan(date, try XCTUnwrap(p.latest))
    }
    func testSparseAndStaleTrendNeverInventPointEstimate() {
        let sparse = ProjectionEngine().weight(samples: [.init(date: now, kilograms: 56)], target: 60, now: now, policy: policy)
        XCTAssertNil(sparse.estimatedDate); XCTAssertNil(sparse.estimatedWeeks); XCTAssertFalse(negotiate(sparse).canAdjust)
        let old = (0..<15).map { WeightSample(date: policy.adding(days: $0 - 21, to: now), kilograms: 56 + Double($0) * 0.03) }
        XCTAssertNil(ProjectionEngine().weight(samples: old, target: 60, now: now, policy: policy).estimatedDate)
    }
    func testImpossibleDeadlineOffersBoundedLaterPlan() throws {
        let result = negotiate(projection(), days: 7)
        XCTAssertGreaterThan(try XCTUnwrap(result.requiredPace), 1)
        XCTAssertLessThanOrEqual(try XCTUnwrap(result.proposedPace), 0.35)
        XCTAssertGreaterThan(try XCTUnwrap(result.proposedDate), policy.adding(days: 7, to: now))
        XCTAssertTrue(result.canAdjust); XCTAssertEqual(result.calorieAdjustment, 100)
    }
    func testFasterPlanUsesSmallExperimentWithoutInventingMetabolism() throws {
        let result = negotiate(projection())
        XCTAssertEqual(try XCTUnwrap(result.proposedPace), 0.24, accuracy: 0.001)
        XCTAssertEqual(result.calorieAdjustment, 100); XCTAssertTrue(result.canAdjust)
    }
    func testPoorCoverageAndRecoveryBlockAcceleration() {
        XCTAssertFalse(negotiate(projection(), fuel: 0.5).canAdjust)
        XCTAssertFalse(negotiate(projection(), protected: true).canAdjust)
    }
    func testLossPlanningNeverAutomaticallyCutsFuel() {
        let result = negotiate(projection(rate: -0.2, target: 50))
        XCTAssertTrue(result.canAdjust); XCTAssertEqual(result.calorieAdjustment, 0)
    }
    func testLegacyOwnerDecodesAdditiveStateAndInvalidEndRejected() throws {
        let data = try JSONEncoder().encode(OwnerSystem())
        let decoded = try JSONDecoder().decode(OwnerSystem.self, from: data)
        XCTAssertNil(decoded.sleepEndedAt); XCTAssertNil(decoded.goalPlanReviewAt); XCTAssertNil(decoded.weeklyWorkoutTarget)
        var bad = decoded; bad.sleepEndedAt = now
        XCTAssertThrowsError(try bad.validate())
        bad.sleepStartedAt = now.addingTimeInterval(1); XCTAssertThrowsError(try bad.validate())
    }
}
