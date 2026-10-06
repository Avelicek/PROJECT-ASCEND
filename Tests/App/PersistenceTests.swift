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

    @MainActor func testLoadRecordsOrdersAllDatedEntitiesAfterAnUnorderedFetch() throws {
        let now = Date(timeIntervalSince1970: 1_791_288_000)
        let policy = DayPolicy(timeZoneIdentifier: "UTC")
        let store = try AppStore(container: PersistenceController.makeContainer(inMemory: true), now: now, clock: { now })
        let dates = [-3, -2, -1].map { policy.adding(days: $0, to: policy.start(of: now)) }
        let exercise = try XCTUnwrap(store.exercises.first { $0.catalogID == "bench_press" })

        // Persist in neither ascending nor descending order. Call loadRecords directly so
        // daily evaluation/materialization cannot mask the fetch-ordering contract.
        for index in [2, 0, 1] {
            let date = dates[index]
            let dayKey = policy.key(for: date)
            store.context.insert(BodyWeightEntry(measuredAt: date, kilograms: 56 + Double(index)))
            store.context.insert(NutritionEntry(dayKey: dayKey, date: date, calories: 3000,
                proteinGrams: 130, calorieGoal: 3000, proteinGoal: 130))
            store.context.insert(SleepEntry(dayKey: dayKey, date: date, durationHours: 8, quality: 4))

            let session = WorkoutSession(startedAt: date, title: "Ordering \(index)", isQuickLog: true)
            session.completedAt = date
            store.context.insert(session)
            let objective = DailyObjective(title: "Ordering \(index)", kind: .custom, cadence: .daily,
                importance: .standard, target: 1, unit: "entry", startsAt: date)
            store.context.insert(objective)
            store.context.insert(DailyObjectiveCompletion(objective: objective, date: date, policy: policy))

            let elo = 101 + index
            let result = ELOResult(previousELO: elo - 1, elo: elo, delta: 1,
                components: [.init(category: .training, label: "Ordering", points: 1)],
                rank: RankEngine().status(elo: elo, previousELO: elo - 1))
            let evaluation = try DailyEvaluation(dayKey: dayKey, date: date, result: result, evaluatedAt: now)
            let entry = ELOHistoryEntry(dayKey: dayKey, date: date, previousELO: elo - 1, elo: elo, delta: 1)
            evaluation.history = entry; entry.evaluation = evaluation
            store.context.insert(evaluation); store.context.insert(entry)
            store.context.insert(PersonalRecord(exerciseCatalogID: exercise.catalogID, kind: .weight,
                value: 55 + Double(index), achievedAt: date, sessionID: session.id))
        }
        try store.context.save()
        try store.loadRecords()

        XCTAssertEqual(store.weights.map(\.measuredAt), dates)
        XCTAssertEqual(store.nutrition.map(\.date), dates)
        XCTAssertEqual(store.sleep.map(\.date), dates)
        XCTAssertEqual(store.sessions.map(\.startedAt), Array(dates.reversed()))
        XCTAssertEqual(store.objectives.map(\.startsAt), dates)
        XCTAssertEqual(store.occurrences.map(\.date), dates)
        XCTAssertEqual(store.evaluations.map(\.date), dates)
        XCTAssertEqual(store.history.map(\.date), dates)
        XCTAssertEqual(store.currentELO, 103, "The last history entry must remain the newest evaluation")
        XCTAssertEqual(store.records.map(\.achievedAt), Array(dates.reversed()))

        try store.loadRecords()
        XCTAssertEqual(store.history.map(\.date), dates, "Repeated loads preserve chronological ledger order")
        XCTAssertEqual(store.sessions.map(\.startedAt), Array(dates.reversed()))
    }

    @MainActor func testLoadRecordsOrdersExercisesAlphabeticallyIgnoringCase() throws {
        let store = try AppStore(container: PersistenceController.makeContainer(inMemory: true))
        for (identifier, name) in [("zeta", "Zeta"), ("alpha", "alpha"), ("beta", "beta")] {
            store.context.insert(Exercise(catalogID: "ordering.\(identifier)", name: name, category: .strength,
                equipment: .none, trackingMode: .reps, bodyweightCapable: false,
                additionalWeightAllowed: false, contributions: []))
        }
        try store.context.save()
        try store.loadRecords()

        let names = store.exercises.filter { $0.catalogID.hasPrefix("ordering.") }.map(\.name)
        XCTAssertEqual(names, ["alpha", "beta", "Zeta"])
        XCTAssertEqual(store.exercises.count, ExerciseCatalog.definitions.count + 3)
    }
}
