import Foundation
import XCTest
@testable import ASCEND

final class UXRefinementPersistenceTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_791_288_000)
    @MainActor private func store() throws -> AppStore {
        try AppStore(container: PersistenceController.makeContainer(inMemory: true), demo: true, now: date, clock: { [date] in date })
    }
    @MainActor func testSleepEndAndCurrentWorkoutSurviveBackupRecreation() throws {
        let value = try store()
        value.startLiveWorkout()
        let draft = value.activeWorkout?.id, sessions = value.sessions.map(\.id), weights = value.weights.map(\.id), elo = value.history.map(\.delta)
        value.startSleep(); value.endSleep()
        XCTAssertFalse(value.liveWorkoutPresented)
        let payload = try value.backupEnvelope().payload
        let recreated = try AppStore(container: PersistenceController.makeContainer(inMemory: true), now: date, clock: { [date] in date }, restored: payload, activateServices: false)
        XCTAssertEqual(recreated.ownerSystem.sleepStartedAt, date); XCTAssertEqual(recreated.ownerSystem.sleepEndedAt, date)
        XCTAssertEqual(recreated.activeWorkout?.id, draft); XCTAssertEqual(recreated.sessions.map(\.id), sessions)
        XCTAssertEqual(recreated.weights.map(\.id), weights); XCTAssertEqual(recreated.history.map(\.delta), elo)
        XCTAssertEqual(recreated.nextBestAction.action, .sleep)
    }
    @MainActor func testSleepConfirmationRoutesToMorningAndPreservesDraft() throws {
        let value = try store(); value.startLiveWorkout(); let id = value.activeWorkout?.id
        value.ownerSystem.sleepStartedAt = date.addingTimeInterval(-8 * 3600); value.endSleep()
        XCTAssertTrue(value.finishSleep(start: date.addingTimeInterval(-8 * 3600), end: date, quality: 3, replace: true))
        XCTAssertNil(value.ownerSystem.sleepStartedAt); XCTAssertNil(value.ownerSystem.sleepEndedAt)
        XCTAssertEqual(value.todaySleep?.durationHours, 8); XCTAssertEqual(value.presentedSheet, .checkIn)
        XCTAssertEqual(value.activeWorkout?.id, id)
    }
    @MainActor func testGoalPlanChangesOnlyReviewedSettingsAndPreventsRepeatedFuelIncrease() throws {
        let value = try store()
        value.profile.targetWeightKG = 60
        for index in 0..<15 { XCTAssertTrue(value.logWeight(56 + Double(index) * 0.2 / 7, at: value.policy.adding(days: index - 14, to: date))) }
        for index in 0..<14 { XCTAssertTrue(value.logNutrition(calories: value.profile.calorieGoal, protein: value.profile.proteinGoal, on: value.policy.adding(days: index - 13, to: date))) }
        value.startLiveWorkout()
        let ids = value.sessions.map(\.id), weights = value.weights.map(\.id), draft = value.activeWorkout?.id, elo = value.history.map(\.delta), previous = value.profile.calorieGoal
        XCTAssertTrue(value.applyGoalNegotiation(deadline: nil, faster: true))
        XCTAssertEqual(value.profile.calorieGoal, previous + 100)
        XCTAssertEqual(value.sessions.map(\.id), ids); XCTAssertEqual(value.weights.map(\.id), weights)
        XCTAssertEqual(value.activeWorkout?.id, draft); XCTAssertEqual(value.history.map(\.delta), elo)
        XCTAssertFalse(value.applyGoalNegotiation(deadline: nil, faster: true))
        XCTAssertEqual(value.profile.calorieGoal, previous + 100)
    }
    @MainActor func testGoalConversationNeverChangesDataBeforeExplicitApplication() throws {
        let value = try store(), calories = value.profile.calorieGoal, target = value.profile.targetWeightKG, count = value.weights.count
        _ = value.goalNegotiation(deadline: value.policy.adding(days: 5, to: date), faster: false)
        XCTAssertEqual(value.profile.calorieGoal, calories); XCTAssertEqual(value.profile.targetWeightKG, target); XCTAssertEqual(value.weights.count, count)
        XCTAssertEqual(value.coachContext.projectionEstimateWeeks, value.goalProjection.estimatedWeeks)
    }
}
