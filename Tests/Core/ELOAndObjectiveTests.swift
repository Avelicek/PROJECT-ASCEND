import Foundation
import XCTest
#if canImport(AscendCore)
@testable import AscendCore
#else
@testable import ASCEND
#endif

final class ELOAndObjectiveTests: XCTestCase {
    func testRecoveryExemptionNeverPenalizesMissedObjective() {
        var input = ELOInput()
        input.objectives = [.init(title: "Push-ups", completed: false, importance: .major, recoveryExempt: true)]
        XCTAssertEqual(ELOEngine().evaluate(input, previousELO: 100).delta, 0)
    }
    func testComponentsExplainClampedDelta() {
        var input = ELOInput()
        input.objectives = [.init(title: "Train", completed: false, importance: .major)]
        let result = ELOEngine().evaluate(input, previousELO: 1)
        XCTAssertEqual(result.elo, 0); XCTAssertEqual(result.delta, -1)
        XCTAssertEqual(result.components.map(\.points).reduce(0, +), result.delta)
    }
    func testScoringCanCauseRankUpAndDown() {
        var positive = ELOInput(); positive.completedWorkout = true
        XCTAssertTrue(ELOEngine().evaluate(positive, previousELO: 99).rank.rankedUp)
        var negative = ELOInput(); negative.objectives = [.init(title: "Habit", completed: false, importance: .standard)]
        XCTAssertTrue(ELOEngine().evaluate(negative, previousELO: 100).rank.rankedDown)
    }
    func testDuplicateObjectiveTitlesHaveDistinctStableComponentIDs() {
        var input = ELOInput()
        input.objectives = [.init(title: "Habit", completed: true, importance: .minor), .init(title: "Habit", completed: true, importance: .major)]
        let engine = ELOEngine()
        let first = engine.evaluate(input, previousELO: 100)
        let second = engine.evaluate(input, previousELO: 100)
        XCTAssertEqual(Set(first.components.map(\.id)).count, 2)
        XCTAssertEqual(first.components.map(\.id), second.components.map(\.id))
    }
    func testMissingNutritionDoesNotFabricateFailure() {
        XCTAssertEqual(ELOEngine().evaluate(.init(), previousELO: 100).delta, 0)
    }
    func testLifetimeLevelIsMonotonic() {
        let levels = (-10...1000).map { ELOEngine().lifetimeLevel(credits: $0) }
        XCTAssertEqual(levels, levels.sorted()); XCTAssertEqual(levels.first, 1)
    }
    func testSchedulesRespectStartDateAndWeekdays() {
        let policy = DayPolicy(timeZoneIdentifier: "UTC")
        let monday = ISO8601DateFormatter().date(from: "2026-10-05T12:00:00Z")!
        let engine = ObjectiveEngine()
        XCTAssertTrue(engine.isDue(.init(cadence: .once, startsAt: monday), on: monday, policy: policy))
        XCTAssertFalse(engine.isDue(.init(cadence: .once, startsAt: monday), on: policy.adding(days: 1, to: monday), policy: policy))
        XCTAssertTrue(engine.isDue(.init(cadence: .weekly, startsAt: monday), on: policy.adding(days: 7, to: monday), policy: policy))
        XCTAssertFalse(engine.isDue(.init(cadence: .daily, startsAt: monday), on: policy.adding(days: -1, to: monday), policy: policy))
        XCTAssertTrue(engine.isDue(.init(cadence: .weekdays, startsAt: monday, weekdays: [2, 4]), on: monday, policy: policy))
        XCTAssertFalse(engine.isDue(.init(cadence: .weekdays, startsAt: monday, weekdays: [2, 4]), on: policy.adding(days: 1, to: monday), policy: policy))
    }
    func testDayPolicyHandlesDSTWithCalendarDays() throws {
        let policy = DayPolicy(timeZoneIdentifier: "Europe/Prague")
        let formatter = ISO8601DateFormatter()
        let before = try XCTUnwrap(formatter.date(from: "2026-03-28T23:00:00Z"))
        let after = policy.adding(days: 1, to: before)
        XCTAssertEqual(after.timeIntervalSince(before), 23 * 3600)
        XCTAssertEqual(policy.key(for: before), "2026-03-29"); XCTAssertEqual(policy.key(for: after), "2026-03-30")
    }
}
