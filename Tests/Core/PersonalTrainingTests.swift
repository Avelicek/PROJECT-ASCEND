import Foundation
import XCTest
#if canImport(AscendCore)
@testable import AscendCore
#else
@testable import ASCEND
#endif

final class PersonalTrainingTests: XCTestCase {
    private let engine = TrainingSystem()
    private let now = Date(timeIntervalSince1970: 1_791_288_000)
    private func exercise(_ id: String) throws -> TrainingExercise { try XCTUnwrap(TrainingCatalog.definitions.first { $0.id == id }) }
    func testCatalogHasUsefulUniqueMetadataAndStableLegacyIDs() {
        let catalog = TrainingCatalog.definitions
        XCTAssertEqual(catalog.count, 149); XCTAssertEqual(Set(catalog.map(\.id)).count, catalog.count)
        XCTAssertEqual(Set(catalog.map(\.focus)), Set(TrainingFocus.allCases))
        for entry in catalog {
            XCTAssertFalse(entry.required.isEmpty, entry.id); XCTAssertFalse(entry.muscles.isEmpty, entry.id)
            XCTAssertEqual(Set(entry.muscles.map(\.muscle)).count, entry.muscles.count)
            XCTAssertTrue(entry.muscles.allSatisfy { $0.fraction > 0 && $0.fraction.isFinite })
            XCTAssertEqual(entry.muscles.map(\.fraction).reduce(0, +), 1, accuracy: 0.001, entry.id)
        }
        XCTAssertTrue(["bench_press", "push_up", "pull_up", "goblet_squat", "plank"].allSatisfy { id in catalog.contains { $0.id == id } })
    }
    func testAvailabilityRequiresAllEquipmentAndResolvesAdjustableDumbbells() throws {
        var profile = TrainingProfile()
        XCTAssertTrue(engine.missing(try exercise("push_up"), profile: profile).isEmpty)
        XCTAssertEqual(engine.missing(try exercise("pull_up"), profile: profile), [.pullUpBar])
        profile.equipment = [.barbell]
        XCTAssertEqual(engine.missing(try exercise("bench_press"), profile: profile), [.bench])
        profile.equipment = [.adjustableDumbbells]
        XCTAssertTrue(engine.missing(try exercise("db_row"), profile: profile).isEmpty)
        XCTAssertEqual(engine.missing(try exercise("db_bench_press"), profile: profile), [.bench])
        XCTAssertFalse(engine.missing(try exercise("lat_pulldown"), profile: profile).isEmpty)
    }
    func testDiscoveryFiltersAndPriorityRespectFavoritesHiddenRecentAvailability() {
        var state = PersonalTrainingState(); state.profile.equipment.insert(.dumbbells)
        state.favorites = ["db_row"]; state.hidden = ["push_up"]
        var query = ExerciseQuery()
        let values = engine.filter(TrainingCatalog.definitions, state: state, query: query, recent: ["plank"])
        XCTAssertEqual(Array(values.prefix(2).map(\.id)), ["db_row", "plank"])
        XCTAssertFalse(values.contains { $0.id == "push_up" })
        query.availableOnly = true; query.focus = .back; query.equipment = .dumbbells
        XCTAssertTrue(engine.filter(TrainingCatalog.definitions, state: state, query: query).allSatisfy { $0.focus == .back && $0.required.contains(.dumbbells) && engine.missing($0, profile: state.profile).isEmpty })
        query = .init(); query.bodyweightOnly = true; query.search = "push-up"; query.showHidden = true
        XCTAssertTrue(engine.filter(TrainingCatalog.definitions, state: state, query: query).contains { $0.id == "push_up" })
        query = .init(); query.favoritesOnly = true
        XCTAssertEqual(engine.filter(TrainingCatalog.definitions, state: state, query: query).map(\.id), ["db_row"])
        query = .init(); query.preferredFocus = .core
        let preferred = engine.filter(TrainingCatalog.definitions, state: state, query: query)
        XCTAssertEqual(preferred.first?.id, "db_row", "Favorites precede a relevant available muscle group")
        XCTAssertEqual(preferred.dropFirst().first?.focus, .core)
    }
    func testSubstitutionsAreDeterministicCompatibleAndPreferSamePattern() throws {
        var state = PersonalTrainingState(); state.profile.equipment = [.bodyweight, .dumbbells, .chestPress]
        let source = try exercise("bench_press")
        let result = engine.substitutes(for: source, catalog: TrainingCatalog.definitions, state: state)
        XCTAssertTrue(result.contains { $0.exercise.id == "chest_press" }); XCTAssertTrue(result.contains { $0.exercise.id == "db_floor_press" })
        XCTAssertEqual(result.first?.exercise.pattern, .horizontalPush)
        XCTAssertTrue(result.allSatisfy { engine.missing($0.exercise, profile: state.profile).isEmpty && $0.exercise.id != source.id })
        XCTAssertEqual(result.map { $0.exercise.id }, engine.substitutes(for: source, catalog: TrainingCatalog.definitions.reversed(), state: state).map { $0.exercise.id })
        state.hidden.insert("chest_press")
        XCTAssertFalse(engine.substitutes(for: source, catalog: TrainingCatalog.definitions, state: state).contains { $0.exercise.id == "chest_press" })
    }
    func testPulldownSubstitutesRequireActualOwnedEquipment() throws {
        var state = PersonalTrainingState(); state.profile.equipment = [.bodyweight, .pullUpBar, .bands, .dumbbells, .bench]
        let result = engine.substitutes(for: try exercise("lat_pulldown"), catalog: TrainingCatalog.definitions, state: state)
        for id in ["pull_up", "db_pullover", "band_pulldown"] { XCTAssertTrue(result.contains { $0.exercise.id == id }) }
        XCTAssertFalse(result.contains { $0.exercise.required.contains(.cable) })
    }
    private func history(_ id: String, reps: Int = 22, kg: Double = 0, rpe: Double = 7, count: Int = 3) -> [ExerciseHistory] {
        (1...count).map { day in .init(exerciseID: id, date: now.addingTimeInterval(Double(-day) * 86400), mode: .reps,
            sets: (0..<3).map { _ in .init(.init(reps: reps, kilograms: kg), rpe: rpe) }) }
    }
    func testFamiliesNeedThreeConsistentSessionsAndAvailableHarderVariant() throws {
        let push = try exercise("push_up")
        var state = PersonalTrainingState()
        XCTAssertNil(engine.harderVariation(for: push, history: history("push_up", count: 2), state: state, now: now))
        XCTAssertNil(engine.harderVariation(for: push, history: history("push_up"), state: state, now: now))
        state.profile.equipment.insert(.bench)
        XCTAssertEqual(engine.harderVariation(for: push, history: history("push_up"), state: state, now: now)?.id, "decline_push_up")
        XCTAssertNil(engine.harderVariation(for: push, history: history("push_up", rpe: 9), state: state, now: now))
        state.hidden.insert("decline_push_up")
        XCTAssertNil(engine.harderVariation(for: push, history: history("push_up"), state: state, now: now))
    }
    func testBodyweightRepAndOptionalSetProgressionDoNotInventKilograms() throws {
        let exercise = LiveExercise(catalogID: "push_up", name: "Push-up", mode: .reps, bodyweight: true, addedWeight: true, contributions: [])
        XCTAssertFalse(exercise.allowsWeight)
        let suggestion = ProgressionEngine().suggest(history("push_up"), exercise: exercise, now: now)
        XCTAssertEqual(suggestion.target?.reps, 23); XCTAssertEqual(suggestion.target?.kilograms, 0)
        XCTAssertTrue(suggestion.additionalSetSuggested)
        XCTAssertFalse(ProgressionEngine().suggest(history("push_up", count: 2), exercise: exercise, now: now).additionalSetSuggested)
        XCTAssertNil(ProgressionEngine().suggest(history("push_up"), exercise: exercise, now: now, recoveryLimited: true).target)
    }
    func testTotalBodyweightRepsCanImproveWithoutSingleSetPR() {
        var exercise = LiveExercise(catalogID: "push_up", name: "Push-up", mode: .reps, bodyweight: true, addedWeight: true, contributions: [])
        exercise.sets = (0..<3).map { _ in var value = LiveSet(); value.reps = 8; value.completedAt = now; return value }
        let prior = ExerciseHistory(exerciseID: "push_up", date: now.addingTimeInterval(-86400), mode: .reps, sets: [.init(.init(reps: 10)), .init(.init(reps: 10))])
        let records = PersonalRecordEngine().detect(exercise: exercise, history: [prior], at: now)
        XCTAssertEqual(records.map(\.kind), [.totalReps]); XCTAssertEqual(records.first?.value, 24)
        XCTAssertEqual(records.first?.storageKey, "totalReps@0.0")
    }
    func testWeightedBodyweightRecordsSeparateAddedLoadFromBodyMass() {
        var exercise = LiveExercise(catalogID: "pull_up", name: "Pull-up", mode: .reps, bodyweight: true, addedWeight: true, contributions: [])
        var row = LiveSet(); row.kilograms = 5; row.reps = 8; row.completedAt = now; exercise.sets = [row]
        XCTAssertTrue(exercise.allowsWeight, "Older loaded drafts still show their added weight")
        let prior = ExerciseHistory(exerciseID: "pull_up", date: now.addingTimeInterval(-86400), mode: .reps, sets: [.init(.init(reps: 10))])
        let records = PersonalRecordEngine().detect(exercise: exercise, history: [prior], at: now)
        XCTAssertEqual(Set(records.map(\.kind)), [.weight, .addedWeightPerformance])
        XCTAssertEqual(records.first { $0.kind == .addedWeightPerformance }?.value, 40)
        XCTAssertFalse(records.contains { $0.kind == .estimatedOneRepMax || $0.kind == .volume || $0.kind == .reps })
    }
    func testRoutineValidationAndStateDecodeDefaultsPreserveEmptyUserChoices() throws {
        var routine = WorkoutRoutine(name: "Push", exercises: [.init("push_up", sets: 3, repTarget: 12, restSeconds: 60)])
        XCTAssertTrue(routine.isValid); routine.exercises.append(.init("push_up")); XCTAssertFalse(routine.isValid)
        let state = try JSONDecoder().decode(PersonalTrainingState.self, from: Data("{\"profile\":{},\"routines\":[]}".utf8))
        XCTAssertEqual(state.profile.resolvedEquipment, [.bodyweight]); XCTAssertTrue(state.routines.isEmpty)
        let defaults = try JSONDecoder().decode(PersonalTrainingState.self, from: Data("{}".utf8))
        XCTAssertEqual(defaults.routines.count, 4)
    }
    func testRecoveryRecommendationNeverTreatsUnknownMusclesAsReady() {
        let state = PersonalTrainingState()
        let context = RecoveryContext(sleepHours: 8, sleepQuality: 4, calorieAdherence: 1, proteinAdherence: 1, historyDays: 28, trainingSessions: 8)
        let report = RecoveryEngine().evaluate(loads: [], context: context, now: now)
        XCTAssertEqual(report.confidence, .medium)
        XCTAssertNil(engine.recommend(routines: state.routines, catalog: TrainingCatalog.definitions, state: state, recovery: report))
    }
    func testRecoveryRecommendationUsesObservedRecoveryAndAvailableRoutines() throws {
        let state = PersonalTrainingState()
        let loads = [TrainingLoad(date: now.addingTimeInterval(-7 * 86400), contributions: Muscle.allCases.map { .init($0, 1) }, challengingSets: 2, intensity: 1)]
        let context = RecoveryContext(sleepHours: 8, sleepQuality: 4, calorieAdherence: 1, proteinAdherence: 1, historyDays: 28, trainingSessions: 8)
        let report = RecoveryEngine().evaluate(loads: loads, context: context, now: now)
        let recommendation = try XCTUnwrap(engine.recommend(routines: state.routines, catalog: TrainingCatalog.definitions, state: state, recovery: report))
        let routine = try XCTUnwrap(state.routines.first { $0.id == recommendation.routineID })
        XCTAssertTrue(routine.exercises.allSatisfy { item in TrainingCatalog.definitions.first { $0.id == item.exerciseID }.map { engine.missing($0, profile: state.profile).isEmpty } ?? false })
        XCTAssertNil(engine.recommend(routines: state.routines.filter { $0.name == "Upper body" }, catalog: TrainingCatalog.definitions, state: state, recovery: report))
    }
    func testOldWorkoutDraftDecodesWithoutRoutineAndAddedWeightSettings() throws {
        var draft = LiveWorkout(startedAt: now)
        draft.exercises = [.init(catalogID: "push_up", name: "Push-up", mode: .reps, bodyweight: true, addedWeight: true, contributions: [])]
        let data = try JSONEncoder().encode(draft)
        let value = try JSONDecoder().decode(LiveWorkout.self, from: data)
        XCTAssertNil(value.routineID); XCTAssertNil(value.exercises.first?.restSeconds)
        XCTAssertFalse(try XCTUnwrap(value.exercises.first).allowsWeight)
    }
}
