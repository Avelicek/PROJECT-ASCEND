import Foundation
import SwiftData
import XCTest
@testable import ASCEND

final class LiveWorkoutPersistenceTests: XCTestCase {
    @MainActor func testTimedExercisePersistsNoUnloggedRepOrDistanceMetric() throws {
        let now = Date.now
        let store = try store(at: now)
        store.startLiveWorkout()
        store.addLiveExercise(try XCTUnwrap(store.exercises.first { $0.catalogID == "plank" }))
        let exercise = try XCTUnwrap(store.activeWorkout?.exercises.first)
        XCTAssertTrue(store.completeLiveSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        XCTAssertTrue(store.finishLiveWorkout())
        let set = try XCTUnwrap(store.sessions.first?.exercises.first?.sets.first)
        XCTAssertEqual(set.durationSeconds, 60); XCTAssertEqual(set.reps, 0)
        XCTAssertEqual(set.distanceMeters, 0); XCTAssertEqual(set.weightKG, 0)
    }
    @MainActor private func store(at now: Date, storage: WorkoutDraftStorage? = nil) throws -> AppStore {
        let value = try AppStore(container: PersistenceController.makeContainer(inMemory: true), now: now, clock: { now }, workoutStorage: storage)
        XCTAssertTrue(value.editTraining { $0.profile.equipment = [.bodyweight, .barbell, .bench] })
        return value
    }
    @MainActor private func begin(_ store: AppStore, reps: Int = 8, kg: Double = 55, warmup: Bool = false) throws -> LiveExercise {
        let bench = try XCTUnwrap(store.exercises.first { $0.catalogID == "bench_press" })
        store.startLiveWorkout(); store.addLiveExercise(bench)
        let entry = try XCTUnwrap(store.activeWorkout?.exercises.first)
        store.changeLiveExercise(entry.id) { exercise in
            exercise.sets[0].reps = reps; exercise.sets[0].kilograms = kg
            exercise.sets[0].isWarmup = warmup; exercise.sets[0].rpe = 7
        }
        return try XCTUnwrap(store.activeWorkout?.exercises.first)
    }
    @MainActor func testDraftAndRestSurviveNewStoreWithoutCreatingHistory() throws {
        let now = Date.now
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ascend-draft-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let storage = WorkoutDraftStorage(url: url)
        let original = try store(at: now, storage: storage)
        let exercise = try begin(original)
        XCTAssertTrue(original.completeLiveSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        let restored = try store(at: now, storage: storage)
        XCTAssertEqual(restored.activeWorkout?.id, original.activeWorkout?.id)
        XCTAssertEqual(restored.activeWorkout?.completedSets, 1)
        XCTAssertEqual(restored.activeWorkout?.rest.deadline, original.activeWorkout?.rest.deadline)
        XCTAssertTrue(restored.sessions.isEmpty); XCTAssertTrue(restored.records.isEmpty)
    }
    @MainActor func testPendingPRCommitsOnlyAtFinishAndNoUnfinishedSetLeaks() throws {
        let now = Date.now
        let store = try store(at: now)
        let bench = try XCTUnwrap(store.exercises.first { $0.catalogID == "bench_press" })
        XCTAssertTrue(store.logWorkout(exercise: bench, sets: [.init(reps: 8, kilograms: 55)], at: now.addingTimeInterval(-86400), quick: false, exertion: 7))
        let exercise = try begin(store, reps: 9)
        XCTAssertTrue(store.completeLiveSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        store.addLiveSet(exerciseID: exercise.id)
        XCTAssertFalse(store.pendingRecords.isEmpty); XCTAssertTrue(store.records.isEmpty)
        XCTAssertTrue(store.finishLiveWorkout())
        XCTAssertEqual(store.sessions.count, 2); XCTAssertEqual(store.sessions.first?.exercises.first?.sets.count, 1)
        XCTAssertTrue(store.records.contains { $0.kindRaw == "reps@55.0" })
        XCTAssertEqual(store.completedWorkout?.workingSets, 1); XCTAssertEqual(store.completedWorkout?.volumeKG, 495)
        XCTAssertGreaterThan(store.completedWorkout?.pendingELO ?? 0, 0)
        XCTAssertNil(store.activeWorkout)
        let recordCount = store.records.count
        try store.refresh(at: now); XCTAssertEqual(store.records.count, recordCount)
        let restored = try AppStore(container: store.container, now: now, clock: { now })
        XCTAssertEqual(restored.records.count, recordCount)
        XCTAssertEqual(restored.sessions.count, 2)
    }
    @MainActor func testDiscardRemovesDraftWithoutGhostRecordsOrHistory() throws {
        let now = Date.now
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ascend-discard-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try store(at: now, storage: .init(url: url))
        let exercise = try begin(store)
        XCTAssertTrue(store.completeLiveSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        store.discardLiveWorkout()
        XCTAssertNil(store.activeWorkout); XCTAssertFalse(store.liveWorkoutPresented)
        XCTAssertTrue(store.sessions.isEmpty); XCTAssertTrue(store.records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
    @MainActor func testWarmupDoesNotStartRestOrEarnTrainingPointsOrObjective() throws {
        let now = Date.now
        let store = try store(at: now)
        var objective = ObjectiveDraft(); objective.title = "Train"; objective.kind = .workout; objective.startsAt = now
        XCTAssertTrue(store.saveObjective(objective))
        let exercise = try begin(store, warmup: true)
        XCTAssertTrue(store.completeLiveSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        XCTAssertFalse(try XCTUnwrap(store.activeWorkout).rest.isActive)
        XCTAssertTrue(store.finishLiveWorkout())
        XCTAssertEqual(store.completedWorkout?.workingSets, 0)
        XCTAssertEqual(store.sessions.first?.exercises.first?.sets.first?.isWarmup, true)
        XCTAssertEqual(store.sessions.first?.exercises.first?.sets.first?.perceivedExertion, 7)
        XCTAssertFalse(store.evaluationInput(for: now).completedWorkout)
        XCTAssertNil(store.todayObjectives.first?.completedAt)
        XCTAssertFalse(store.projectedScore.components.contains { $0.category == .training })
        XCTAssertNil(store.readiness.muscles.first { $0.muscle == .midPectoral }?.lastTrainedAt)
    }
    @MainActor func testAutomaticRestCanBeDisabledAndInvalidSetCannotComplete() throws {
        let now = Date.now
        let store = try store(at: now)
        let exercise = try begin(store, kg: 0)
        XCTAssertFalse(store.completeLiveSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        XCTAssertEqual(store.activeWorkout?.completedSets, 0)
        store.settings.automaticRestTimer = false
        store.changeLiveExercise(exercise.id) { $0.sets[0].kilograms = 55 }
        XCTAssertTrue(store.completeLiveSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        XCTAssertFalse(try XCTUnwrap(store.activeWorkout).rest.isActive)
    }
    @MainActor func testFailedDraftWriteKeepsPreviousInMemoryState() throws {
        let now = Date.now
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true).appendingPathComponent("draft.json")
        let store = try store(at: now, storage: .init(url: missing))
        store.startLiveWorkout()
        XCTAssertNil(store.activeWorkout); XCTAssertFalse(store.liveWorkoutPresented); XCTAssertNotNil(store.errorMessage)
    }
    @MainActor func testCrossMidnightWorkoutScoresCompletionDayOnce() throws {
        let policy = DayPolicy(timeZoneIdentifier: "UTC")
        let finish = Date(timeIntervalSince1970: 1_791_288_000)
        let store = try store(at: finish)
        store.settings.timeZoneIdentifier = "UTC"
        let started = policy.start(of: finish).addingTimeInterval(-600)
        XCTAssertTrue(store.updateWorkout { $0 = LiveWorkout(startedAt: started) })
        let bench = try XCTUnwrap(store.exercises.first { $0.catalogID == "bench_press" }); store.addLiveExercise(bench)
        let exercise = try XCTUnwrap(store.activeWorkout?.exercises.first)
        store.changeLiveExercise(exercise.id) { $0.sets[0].kilograms = 55 }
        XCTAssertTrue(store.completeLiveSet(exerciseID: exercise.id, setID: exercise.sets[0].id))
        XCTAssertTrue(store.finishLiveWorkout())
        XCTAssertTrue(store.evaluationInput(for: finish).completedWorkout)
        XCTAssertFalse(store.evaluationInput(for: started).completedWorkout)
        try store.refresh(at: policy.adding(days: 1, to: finish))
        let elo = store.currentELO
        try store.refresh(at: policy.adding(days: 1, to: finish))
        XCTAssertEqual(store.currentELO, elo)
        XCTAssertEqual(store.history.filter { $0.dayKey == policy.key(for: finish) }.count, 1)
    }
}
