import Foundation
import XCTest
import SwiftData
@testable import ASCEND

final class PersistenceTests: XCTestCase {
    @MainActor func testProductionBootstrapContainsNoSampleHistory() throws {
        let store = try AppStore(container: PersistenceController.makeContainer(inMemory: true))
        XCTAssertTrue(store.weights.isEmpty); XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertTrue(store.nutrition.isEmpty); XCTAssertTrue(store.history.isEmpty)
        XCTAssertEqual(store.currentELO, 0); XCTAssertNil(store.readiness.percent)
        XCTAssertEqual(store.exercises.count, ExerciseCatalog.definitions.count)
    }
    @MainActor func testPreviewIsSeparateAndCatalogSeedingIsIdempotent() throws {
        let store = try PreviewData.makeStore()
        XCTAssertTrue(store.isDemo); XCTAssertEqual(store.currentELO, 1084)
        try ExerciseCatalog.seed(in: store.context); try store.context.save()
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<Exercise>()), ExerciseCatalog.definitions.count)
    }
    @MainActor func testDailyEvaluationIsIdempotentAndExplainable() throws {
        let now = Date.now
        let clock = { now }
        let store = try AppStore(container: PersistenceController.makeContainer(inMemory: true), now: now, clock: clock)
        store.profile.createdAt = store.policy.adding(days: -2, to: now)
        let yesterday = store.policy.adding(days: -1, to: now)
        XCTAssertTrue(store.logNutrition(calories: 3000, protein: 130, on: yesterday))
        let count = store.history.count; let elo = store.currentELO; let credits = store.profile.lifetimeCredits
        try store.refresh(at: now); try store.refresh(at: now)
        XCTAssertEqual(store.history.count, count); XCTAssertEqual(store.currentELO, elo)
        XCTAssertEqual(store.profile.lifetimeCredits, credits)
        let evaluation = try XCTUnwrap(store.evaluations.last)
        let components = try JSONDecoder().decode([ScoreComponent].self, from: evaluation.componentData)
        XCTAssertEqual(components.map(\.points).reduce(0, +), evaluation.eloDelta)
    }
    @MainActor func testCancelledDraftDoesNotMutateAndInvalidSaveRollsBack() throws {
        let store = try AppStore(container: PersistenceController.makeContainer(inMemory: true))
        var draft = ProfileDraft(store: store); draft.name = "Edited"
        XCTAssertEqual(store.profile.displayName, "Athlete")
        draft.calories = -1
        XCTAssertFalse(store.saveProfile(draft)); XCTAssertEqual(store.profile.displayName, "Athlete")
        XCTAssertNotNil(store.errorMessage)
    }
    @MainActor func testWorkoutRelationshipsCascadeWithoutDeletingCatalog() throws {
        let now = Date.now
        let store = try AppStore(container: PersistenceController.makeContainer(inMemory: true), now: now, clock: { now })
        let exercise = try XCTUnwrap(store.exercises.first { $0.catalogID == "bench_press" })
        XCTAssertTrue(store.logWorkout(exercise: exercise, sets: [.init(reps: 8, kilograms: 55)], at: now, quick: false, exertion: 7))
        let session = try XCTUnwrap(store.sessions.first)
        XCTAssertEqual(session.exercises.first?.sets.count, 1)
        store.context.delete(session); try store.context.save()
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<WorkoutExercise>()), 0)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<WorkoutSet>()), 0)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<Exercise>()), ExerciseCatalog.definitions.count)
    }
    @MainActor func testObjectiveSnapshotsAndRecoveryExemptionPersist() throws {
        let now = Date.now
        let store = try AppStore(container: PersistenceController.makeContainer(inMemory: true), now: now, clock: { now })
        var draft = ObjectiveDraft(); draft.title = "Train"; draft.kind = .workout; draft.startsAt = now
        XCTAssertTrue(store.saveObjective(draft))
        let occurrence = try XCTUnwrap(store.todayObjectives.first)
        XCTAssertTrue(store.chooseRecoveryAlternative(occurrence)); XCTAssertTrue(occurrence.recoveryExempt)
        let original = occurrence.title
        let tomorrow = store.policy.adding(days: 1, to: now)
        try store.refresh(at: tomorrow)
        let evaluation = try XCTUnwrap(store.evaluations.first)
        XCTAssertGreaterThanOrEqual(evaluation.eloDelta, 0)
        XCTAssertEqual(occurrence.title, original)
    }
}
