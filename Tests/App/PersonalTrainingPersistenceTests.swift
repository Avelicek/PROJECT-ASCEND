import Foundation
import XCTest
@testable import ASCEND

final class PersonalTrainingPersistenceTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_791_288_000)
    @MainActor private func store(storage: PersonalTrainingStorage? = nil) throws -> AppStore {
        let fixed = date
        return try AppStore(container: PersistenceController.makeContainer(inMemory: true), now: fixed, clock: { fixed }, trainingStorage: storage)
    }
    @MainActor func testEquipmentFavoritesHiddenAndRoutinesSurviveStoreRecreation() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("training-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let storage = PersonalTrainingStorage(url: url)
        let first = try store(storage: storage)
        XCTAssertTrue(first.editTraining { $0.profile.equipment.insert(.adjustableDumbbells) })
        first.toggleFavorite("db_row"); first.toggleHidden("bench_press")
        let routine = WorkoutRoutine(name: "My pull", exercises: [.init("db_row", sets: 4, repTarget: 10, restSeconds: 120)])
        XCTAssertTrue(first.saveRoutine(routine)); first.duplicateRoutine(routine)
        let restored = try store(storage: storage)
        XCTAssertTrue(restored.training.favorites.contains("db_row")); XCTAssertTrue(restored.training.hidden.contains("bench_press"))
        XCTAssertTrue(restored.missingEquipment("db_row").isEmpty)
        XCTAssertEqual(restored.training.routines.first { $0.id == routine.id }?.exercises.first?.restSeconds, 120)
        XCTAssertTrue(restored.training.routines.contains { $0.name == "My pull copy" && $0.id != routine.id })
        XCTAssertTrue(restored.sessions.isEmpty)
    }
    @MainActor func testFailedTrainingWriteDoesNotChangePreferences() throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("training.json")
        let store = try store(storage: .init(url: missing))
        XCTAssertFalse(store.editTraining { $0.profile.equipment.insert(.barbell) })
        XCTAssertFalse(store.training.profile.equipment.contains(.barbell))
    }
    func testUnsupportedPersonalFileIsPreserved() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("training-unsupported-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let original = Data("{\"version\":999}".utf8)
        try original.write(to: url)
        XCTAssertThrowsError(try PersonalTrainingStorage(url: url).read())
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    @MainActor func testRoutineStartsOrderedSetsTargetsRestWithoutOverwritingActiveSession() throws {
        let store = try store()
        let routine = WorkoutRoutine(name: "Home", exercises: [.init("push_up", sets: 3, repTarget: 12, restSeconds: 60), .init("plank", sets: 2, restSeconds: 45)])
        XCTAssertTrue(store.startRoutine(routine))
        let draft = try XCTUnwrap(store.activeWorkout)
        XCTAssertEqual(draft.routineID, routine.id); XCTAssertEqual(draft.title, "Home")
        XCTAssertEqual(draft.exercises.map(\.catalogID), ["push_up", "plank"])
        XCTAssertEqual(draft.exercises.first?.sets.count, 3); XCTAssertEqual(draft.exercises.first?.sets.first?.reps, 12)
        XCTAssertEqual(store.preferredRest(for: "push_up"), 60)
        XCTAssertFalse(store.startRoutine(routine)); XCTAssertEqual(store.activeWorkout?.id, draft.id)
        XCTAssertTrue(store.sessions.isEmpty)
    }
    @MainActor func testUnavailableRoutineIsBlockedAndReplacementPreservesOtherItems() throws {
        let store = try store()
        var routine = WorkoutRoutine(name: "Upper", exercises: [.init("bench_press", sets: 4, repTarget: 8), .init("plank")])
        XCTAssertFalse(store.startRoutine(routine)); XCTAssertNil(store.activeWorkout)
        routine.exercises[0].exerciseID = "push_up"
        XCTAssertTrue(store.startRoutine(routine)); XCTAssertEqual(store.activeWorkout?.exercises.first?.sets.count, 4)
        XCTAssertEqual(store.activeWorkout?.exercises.last?.catalogID, "plank")
    }
    @MainActor func testBodyweightCompletionHistoryAndReplacementProtectLoggedSets() throws {
        let store = try store()
        store.startLiveWorkout()
        let push = try XCTUnwrap(store.exercises.first { $0.catalogID == "push_up" })
        store.addLiveExercise(push)
        let entry = try XCTUnwrap(store.activeWorkout?.exercises.first)
        XCTAssertFalse(entry.allowsWeight)
        let close = try XCTUnwrap(store.exercises.first { $0.catalogID == "close_grip_push_up" })
        XCTAssertTrue(store.replaceLiveExercise(entry.id, with: close))
        let replaced = try XCTUnwrap(store.activeWorkout?.exercises.first)
        XCTAssertTrue(store.completeLiveSet(exerciseID: replaced.id, setID: replaced.sets[0].id))
        XCTAssertFalse(store.replaceLiveExercise(replaced.id, with: push))
        XCTAssertEqual(store.activeWorkout?.completedSets, 1)
        XCTAssertTrue(store.finishLiveWorkout())
        let history = try XCTUnwrap(store.exerciseHistory.first)
        XCTAssertEqual(history.exerciseID, "close_grip_push_up"); XCTAssertEqual(history.working.first?.performance.reps, 8)
        XCTAssertEqual(history.working.first?.performance.kilograms, 0)
        XCTAssertEqual(store.recentExerciseIDs.first, "close_grip_push_up")
        XCTAssertGreaterThan(store.weeklyExposure.first { $0.0 == "Arms" }?.1 ?? 0, 0)
    }
    @MainActor func testExistingHistoryAndCatalogSnapshotsSurvivePersonalSetup() throws {
        let store = try store()
        let bench = try XCTUnwrap(store.exercises.first { $0.catalogID == "bench_press" })
        XCTAssertTrue(store.logWorkout(exercise: bench, sets: [.init(reps: 8, kilograms: 55)], at: date.addingTimeInterval(-86400), quick: false, exertion: 7))
        let id = try XCTUnwrap(store.sessions.first?.id)
        let contributions = try XCTUnwrap(store.sessions.first?.exercises.first?.contributions)
        XCTAssertTrue(store.editTraining { $0.profile.equipment = [.bodyweight, .dumbbells]; $0.routines = [] })
        let restored = try AppStore(container: store.container, now: date, clock: { self.date })
        XCTAssertEqual(restored.sessions.first?.id, id); XCTAssertEqual(restored.sessions.first?.exercises.first?.contributions, contributions)
        XCTAssertEqual(restored.sessions.first?.exercises.first?.sets.first?.weightKG, 55)
    }
}
