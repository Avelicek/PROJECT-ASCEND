import Foundation
import XCTest
import SwiftData
@testable import ASCEND

final class OwnerSystemPersistenceTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_791_288_000)
    @MainActor private func empty() throws -> AppStore { try AppStore(container: PersistenceController.makeContainer(inMemory: true), now: date, clock: { [date] in date }) }
    @MainActor func testFreshSetupAndExistingV1OwnerMigration() throws {
        let first = try empty(); XCTAssertFalse(first.ownerSystem.onboardingComplete)
        let upgraded = try AppStore(container: first.container, now: date, clock: { [date] in date })
        XCTAssertTrue(upgraded.ownerSystem.onboardingComplete)
        XCTAssertEqual(upgraded.profile.displayName, first.profile.displayName)
        XCTAssertTrue(upgraded.sessions.isEmpty)
    }
    @MainActor func testStructuredRoundTripPreservesImportantCollectionsAndRelationships() throws {
        let source = try AppStore(container: PersistenceController.makeContainer(inMemory: true), demo: true, now: date, clock: { [date] in date })
        XCTAssertTrue(source.addMeasurement(.init(date: date, chest: 96, waist: 75, hips: 90, biceps: 33, thigh: 54)))
        source.startSick(note: "Taking a break")
        source.startSleep()
        source.startLiveWorkout()
        let backup = try source.backupEnvelope()
        let decoded = try AscendBackupEnvelope.decode(JSONEncoder().encode(backup))
        XCTAssertTrue(source.replaceOwnerData(with: decoded))
        let restored = try XCTUnwrap(source.replacementStore)
        XCTAssertEqual(restored.profile.displayName, source.profile.displayName)
        XCTAssertEqual(restored.weights.count, source.weights.count); XCTAssertEqual(restored.nutrition.count, source.nutrition.count)
        XCTAssertEqual(restored.sleep.count, source.sleep.count); XCTAssertEqual(restored.sessions.count, source.sessions.count)
        XCTAssertEqual(restored.records.count, source.records.count); XCTAssertEqual(restored.history.count, source.history.count)
        XCTAssertEqual(restored.objectives.count, source.objectives.count); XCTAssertEqual(restored.occurrences.count, source.occurrences.count)
        XCTAssertEqual(restored.sessions.flatMap(\.exercises).flatMap(\.sets).count, source.sessions.flatMap(\.exercises).flatMap(\.sets).count)
        XCTAssertEqual(restored.training.routines.map(\.id), source.training.routines.map(\.id))
        XCTAssertEqual(restored.training.profile.equipment, source.training.profile.equipment)
        XCTAssertEqual(restored.ownerSystem.measurements.count, 1); XCTAssertTrue(restored.ownerSystem.sickActive)
        XCTAssertEqual(restored.ownerSystem.sleepStartedAt, date); XCTAssertEqual(restored.activeWorkout?.id, source.activeWorkout?.id)
        XCTAssertTrue(restored.sessions.flatMap(\.exercises).allSatisfy { $0.session != nil && $0.exercise != nil })
    }
    @MainActor func testInvalidUnsupportedTamperedAndBrokenReferenceLeaveDataUntouched() throws {
        let store = try empty(); XCTAssertTrue(store.logWeight(70, at: date))
        XCTAssertThrowsError(try AscendBackupEnvelope.decode(Data("not JSON".utf8)))
        var bad = try store.backupEnvelope(); bad.schemaVersion = 99
        XCTAssertFalse(store.replaceOwnerData(with: bad)); XCTAssertEqual(store.weights.first?.kilograms, 70); XCTAssertNil(store.replacementStore)
        bad = try store.backupEnvelope(); bad.payload.profile.displayName = "Tampered"
        XCTAssertThrowsError(try bad.validate())
        var payload = try store.backupEnvelope().payload
        payload.training.favorites = ["missing-exercise"]
        let malformed = try AscendBackupEnvelope(payload: payload, date: date)
        XCTAssertFalse(store.replaceOwnerData(with: malformed)); XCTAssertEqual(store.weights.count, 1)
    }
    @MainActor func testEmptyOwnerBackupResetAndRestoreAfterReset() throws {
        let source = try empty(); let emptyBackup = try source.backupEnvelope()
        XCTAssertNoThrow(try emptyBackup.validate())
        XCTAssertTrue(source.logWeight(68, at: date)); XCTAssertTrue(source.logNutrition(calories: 2900, protein: 140, on: date))
        let backup = try source.backupEnvelope()
        XCTAssertTrue(source.replaceOwnerData(with: nil)); let reset = try XCTUnwrap(source.replacementStore)
        XCTAssertFalse(reset.ownerSystem.onboardingComplete); XCTAssertTrue(reset.weights.isEmpty); XCTAssertTrue(reset.sessions.isEmpty)
        XCTAssertTrue(reset.nutrition.isEmpty); XCTAssertTrue(reset.history.isEmpty); XCTAssertTrue(reset.training.routines.isEmpty)
        XCTAssertTrue(reset.brainArchive.preferences.isEmpty); XCTAssertNil(reset.activeWorkout); XCTAssertEqual(reset.currentELO, 0)
        XCTAssertTrue(reset.replaceOwnerData(with: backup)); let restored = try XCTUnwrap(reset.replacementStore)
        XCTAssertEqual(restored.weights.first?.kilograms, 68); XCTAssertEqual(restored.nutrition.count, 1)
    }
    @MainActor func testCanonicalObjectiveEightyPlusTwentyCountsOneHundredOnce() throws {
        let store = try empty(); let pushUp = try XCTUnwrap(store.exercises.first { $0.catalogID == "push_up" })
        var objective = ObjectiveDraft(); objective.title = "100 push-ups"; objective.kind = .exercise; objective.target = 100; objective.unit = "reps"; objective.exerciseCatalogID = pushUp.catalogID; objective.startsAt = date
        XCTAssertTrue(store.saveObjective(objective))
        XCTAssertTrue(store.logWorkout(exercise: pushUp, sets: Array(repeating: .init(reps: 20), count: 4), at: date, quick: false, exertion: 7))
        XCTAssertEqual(store.todayObjectives.first?.value, 80)
        XCTAssertTrue(store.logWorkout(exercise: pushUp, sets: [.init(reps: 20)], at: date, quick: true, exertion: 7))
        XCTAssertEqual(store.todayObjectives.first?.value, 100); XCTAssertNotNil(store.todayObjectives.first?.completedAt)
        let load = store.readiness.muscles.first { $0.muscle == .midPectoral }?.load
        try store.refresh(at: date); XCTAssertEqual(store.todayObjectives.first?.value, 100)
        XCTAssertEqual(store.readiness.muscles.first { $0.muscle == .midPectoral }?.load, load)
        XCTAssertEqual(store.sessions.count, 2); XCTAssertEqual(store.exerciseHistory.filter { $0.exerciseID == "push_up" }.flatMap(\.working).count, 5)
        XCTAssertGreaterThan(store.weeklyExposure.first { $0.0 == "Chest" }?.1 ?? 0, 0)
    }
    @MainActor func testSickModeProtectsTrainingWithoutChangingRecoveryOrAwardingFreeELO() throws {
        let store = try empty()
        for kind in [ObjectiveKind.workout, .protein] { var objective = ObjectiveDraft(); objective.title = kind.rawValue; objective.kind = kind; objective.startsAt = date; objective.target = kind == .workout ? 1 : 130; XCTAssertTrue(store.saveObjective(objective)) }
        let before = store.readiness.percent
        store.startSick(note: "")
        XCTAssertEqual(store.readiness.percent, before); XCTAssertEqual(store.brainDecision.action, .recover); XCTAssertNil(store.brainDecision.session)
        XCTAssertEqual(store.todayObjectives.first { $0.kindRaw == "workout" }?.recoveryExempt, true)
        XCTAssertEqual(store.todayObjectives.first { $0.kindRaw == "protein" }?.recoveryExempt, false)
        let input = store.evaluationInput(for: date, includeMisses: true)
        XCTAssertFalse(input.recoverySafeChoice)
        XCTAssertFalse(ELOEngine().evaluate(input, previousELO: 100).components.contains { $0.label == "Missed: workout" })
        store.endSick(); XCTAssertFalse(store.ownerSystem.sickActive)
        XCTAssertEqual(store.todayObjectives.first { $0.kindRaw == "workout" }?.recoveryExempt, true)
    }
    @MainActor func testSleepPersistenceWakeDayReplacementAndFailureRetainActiveInterval() throws {
        let store = try empty()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true); defer { try? FileManager.default.removeItem(at: folder) }
        store.ownerStorage = .init(url: folder.appendingPathComponent("owner.json"))
        store.startSleep(); XCTAssertEqual(try store.ownerStorage?.read()?.sleepStartedAt, date)
        XCTAssertFalse(store.finishSleep(start: date, end: date, quality: 3, replace: false)); XCTAssertNotNil(store.ownerSystem.sleepStartedAt)
        XCTAssertTrue(store.logSleep(hours: 7, quality: 3, on: date, bedtime: nil, wakeTime: nil))
        let start = date.addingTimeInterval(-8 * 3600)
        XCTAssertFalse(store.finishSleep(start: start, end: date, quality: 4, replace: false))
        XCTAssertTrue(store.finishSleep(start: start, end: date, quality: 4, replace: true))
        XCTAssertEqual(store.todaySleep?.durationHours, 8); XCTAssertEqual(store.todaySleep?.quality, 4); XCTAssertNil(store.ownerSystem.sleepStartedAt)
        XCTAssertEqual(store.sleep.count, 1)
    }
    @MainActor func testLegacyBuild06ProfileLogsTrainingAndBrainSurviveSidecarMigration() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let container = try PersistenceController.makeContainer(inMemory: true)
        let old = try AppStore(container: container, now: date, clock: { [date] in date }, storageFolder: folder)
        old.profile.displayName = "Legacy owner"
        XCTAssertTrue(old.logWeight(74, at: date))
        XCTAssertTrue(old.logNutrition(calories: 2800, protein: 145, on: date))
        let exercise = try XCTUnwrap(old.exercises.first { $0.catalogID == "push_up" })
        XCTAssertTrue(old.logWorkout(exercise: exercise, sets: [.init(reps: 20)], at: date, quick: false, exertion: 7))
        XCTAssertTrue(old.editTraining { $0.favorites.insert("push_up"); $0.profile.equipment.insert(.dumbbells) })
        old.editBrainSettings { $0.useSleep = false }
        let sessionID = try XCTUnwrap(old.sessions.first?.id)
        // Build 06 had the same SchemaV1 and existing training/Brain JSON, without this new owner sidecar.
        try FileManager.default.removeItem(at: folder.appendingPathComponent("owner-system-v1.json"))
        let migrated = try AppStore(container: container, now: date, clock: { [date] in date }, storageFolder: folder)
        XCTAssertTrue(migrated.ownerSystem.onboardingComplete)
        XCTAssertEqual(migrated.profile.displayName, "Legacy owner")
        XCTAssertEqual(migrated.weights.first?.kilograms, 74); XCTAssertEqual(migrated.nutrition.count, 1)
        XCTAssertEqual(migrated.sessions.first?.id, sessionID)
        XCTAssertTrue(migrated.training.favorites.contains("push_up")); XCTAssertTrue(migrated.training.profile.equipment.contains(.dumbbells))
        XCTAssertFalse(migrated.brainArchive.settings.useSleep)
    }
    @MainActor func testDurationObjectiveUsesRecordedSecondsAndManualCountsStaySeparate() throws {
        let store = try empty()
        let exercise = try XCTUnwrap(store.exercises.first { $0.catalogID == "plank" })
        var objective = ObjectiveDraft(); objective.title = "Two-minute plank"; objective.kind = .exercise; objective.target = 120; objective.unit = "seconds"; objective.exerciseCatalogID = exercise.catalogID; objective.startsAt = date
        XCTAssertTrue(store.saveObjective(objective))
        XCTAssertTrue(store.logWorkout(exercise: exercise, sets: [.init(reps: 0, seconds: 60)], at: date, quick: true, exertion: 6))
        XCTAssertEqual(store.todayObjectives.first?.value, 60); XCTAssertNil(store.todayObjectives.first?.completedAt)
        XCTAssertTrue(store.logWorkout(exercise: exercise, sets: [.init(reps: 0, seconds: 60)], at: date, quick: false, exertion: 6))
        XCTAssertEqual(store.todayObjectives.first?.value, 120); XCTAssertNotNil(store.todayObjectives.first?.completedAt)
        let sessions = store.sessions.count
        var count = ObjectiveDraft(); count.title = "Read 10 pages"; count.kind = .count; count.target = 10; count.startsAt = date
        XCTAssertTrue(store.saveObjective(count))
        let occurrence = try XCTUnwrap(store.todayObjectives.first { $0.kindRaw == "count" })
        XCTAssertTrue(store.changeManualObjective(occurrence, adding: 4)); XCTAssertEqual(occurrence.value, 4)
        XCTAssertTrue(store.changeManualObjective(occurrence, adding: 6)); XCTAssertNotNil(occurrence.completedAt)
        XCTAssertEqual(store.sessions.count, sessions)
    }
    @MainActor func testBrokenWorkoutParentAndUnsafeDraftCannotReplaceCurrentOwner() throws {
        let source = try empty()
        let exercise = try XCTUnwrap(source.exercises.first { $0.catalogID == "push_up" })
        XCTAssertTrue(source.logWorkout(exercise: exercise, sets: [.init(reps: 20)], at: date, quick: true, exertion: 7))
        var payload = try source.backupEnvelope().payload
        payload.sets[0].parentID = UUID()
        XCTAssertFalse(source.replaceOwnerData(with: try .init(payload: payload, date: date)))
        XCTAssertNil(source.replacementStore); XCTAssertEqual(source.sessions.count, 1)
        payload = try source.backupEnvelope().payload
        var draft = LiveWorkout(startedAt: date); draft.rest.pausedSeconds = 1e100; payload.live = draft
        XCTAssertFalse(source.replaceOwnerData(with: try .init(payload: payload, date: date)))
        XCTAssertEqual(source.sessions.count, 1)
        XCTAssertThrowsError(try AscendBackupEnvelope.decode(Data()))
    }
    @MainActor func testIdenticalBrainContextKeepsDecisionAndHistoryAndChangesInvalidateCache() throws {
        let source = try empty()
        let key = source.brainInputKey, id = source.brainDecision.id, entries = source.brainArchive.history.count
        source.deriveBrain(); XCTAssertEqual(source.brainInputKey, key); XCTAssertEqual(source.brainDecision.id, id); XCTAssertEqual(source.brainArchive.history.count, entries)
        source.startSleep(); XCTAssertNotEqual(source.brainInputKey, key); XCTAssertEqual(source.brainDecision.focus, "Sleep")
    }

    @MainActor func testContextualPersonalRecordKeysAndHistoricalValuesRoundTrip() throws {
        let source = try empty(), benchID = "bench_press"
        let bench = try XCTUnwrap(source.exercises.first { $0.catalogID == benchID })
        XCTAssertTrue(source.logWorkout(exercise: bench, sets: [.init(reps: 8, kilograms: 55)], at: date.addingTimeInterval(-86400), quick: false, exertion: 7))
        XCTAssertTrue(source.logWorkout(exercise: bench, sets: [.init(reps: 10, kilograms: 55)], at: date, quick: false, exertion: 7))
        let pr = try XCTUnwrap(source.records.first { $0.kindRaw == "reps@55.0" })
        let backup = try AscendBackupEnvelope.decode(JSONEncoder().encode(source.backupEnvelope()))
        XCTAssertTrue(source.replaceOwnerData(with: backup))
        let restored = try XCTUnwrap(source.replacementStore)
        XCTAssertEqual(restored.records.first { $0.id == pr.id }?.kindRaw, "reps@55.0")
        XCTAssertEqual(restored.records.first { $0.id == pr.id }?.value, 10)
        XCTAssertEqual(restored.occurrences.map(\.value), source.occurrences.map(\.value))
    }

    @MainActor func testProtectedExerciseStillDerivesRealManualPerformanceExactlyOnce() throws {
        let source = try empty(), pushID = "push_up"
        let exercise = try XCTUnwrap(source.exercises.first { $0.catalogID == pushID })
        var objective = ObjectiveDraft(); objective.title = "100 push-ups"; objective.kind = .exercise; objective.target = 100; objective.exerciseCatalogID = pushID; objective.unit = "reps"; objective.startsAt = date
        XCTAssertTrue(source.saveObjective(objective)); source.startSick(note: "")
        XCTAssertEqual(source.todayObjectives.first?.recoveryExempt, true)
        XCTAssertTrue(source.logWorkout(exercise: exercise, sets: [.init(reps: 60)], at: date, quick: true, exertion: 6))
        XCTAssertEqual(source.todayObjectives.first?.value, 60); XCTAssertNil(source.todayObjectives.first?.completedAt)
        XCTAssertTrue(source.logWorkout(exercise: exercise, sets: [.init(reps: 40)], at: date, quick: true, exertion: 6))
        XCTAssertEqual(source.todayObjectives.first?.value, 100); XCTAssertNotNil(source.todayObjectives.first?.completedAt)
        XCTAssertEqual(source.todayObjectives.first?.recoveryExempt, false)
        XCTAssertFalse(source.evaluationInput(for: date).recoverySafeChoice)
        XCTAssertEqual(source.sessions.count, 2)
        XCTAssertEqual(source.brainDecision.focus, "Recovery protection")
    }

}
