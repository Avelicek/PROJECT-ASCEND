import Foundation
import XCTest
#if canImport(AscendCore)
@testable import AscendCore
#else
@testable import ASCEND
#endif

final class PersonalBrainTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_791_288_000)
    private let engine = PersonalBrainEngine()
    private func context(chest: Double = 35) -> PersonalContext {
        var value = PersonalContext(date: date)
        value.dayKey = "2026-10-06"; value.sleepHours = 8; value.sleepQuality = 4
        value.nutritionDays = 3; value.calorieAdherence = 1; value.proteinAdherence = 1
        value.sessionDates = [2, 4, 7].map { date.addingTimeInterval(-Double($0) * 86400) }
        value.trainingDays = 3; value.daysSinceLastSession = 2
        value.training.profile.equipment = [.bodyweight, .dumbbells, .latPulldown, .chestPress, .pullUpBar]
        for index in value.training.routines.indices { value.training.routines[index].id = PersonalBrainEngine.stableID(value.training.routines[index].name) }
        value.recovery = .init(percent: 80, state: .ready, muscles: Muscle.allCases.map { muscle in
            let score = muscle.group == "Chest" ? chest : 90.0
            return .init(muscle: muscle, recoveryPercent: score, load: 12, fatigue: 100 - score,
                lastTrainedAt: ["Legs", "Glutes", "Calves"].contains(muscle.group) ? nil : date.addingTimeInterval(-4 * 86400), estimatedRecoveryTime: nil, confidence: .medium)
        }, confidence: .medium)
        return value
    }
    private func live(_ id: String = "db_row") throws -> LiveExercise {
        let entry = try XCTUnwrap(TrainingCatalog.definitions.first { $0.id == id })
        return .init(catalogID: id, name: entry.name, mode: entry.mode, bodyweight: entry.bodyweight,
            addedWeight: entry.additional, weightStep: 1, contributions: entry.muscles)
    }
    private func history(_ id: String = "db_row", reps: Int = 8, rpe: Double = 7, count: Int = 4) -> [ExerciseHistory] {
        (0..<count).map { index in .init(exerciseID: id, date: date.addingTimeInterval(-Double(index + 2) * 86400), mode: .weightAndReps,
            sets: [.init(.init(reps: reps, kilograms: 20), rpe: rpe), .init(.init(reps: reps, kilograms: 20), rpe: rpe)]) }
    }
    func testRecoveredPullWinsOverRecoveringChestAndUnknownLegs() {
        let decision = engine.decide(context())
        XCTAssertEqual(decision.action, .train); XCTAssertEqual(decision.focus, "Pull")
        XCTAssertEqual(decision.session?.name, "Pull"); XCTAssertNotNil(decision.routineID)
        XCTAssertEqual(decision.confidence, .medium)
        XCTAssertTrue(decision.reasons.contains { $0.contains("90%") })
    }
    func testUnavailableEquipmentNeverAppears() {
        var value = context(); value.training.profile.equipment = [.bodyweight]
        let decision = engine.decide(value)
        for item in decision.session?.exercises ?? [] {
            let exercise = TrainingCatalog.definitions.first { $0.id == item.exerciseID }
            XCTAssertTrue(exercise.map { TrainingSystem().missing($0, profile: value.training.profile).isEmpty } ?? false)
        }
        XCTAssertFalse(decision.session?.exercises.contains { $0.exerciseID == "db_row" } ?? false)
    }
    func testSevereRecoveryBlocksAllSessionsEvenWithPreference() {
        var value = context(chest: 10)
        value.recovery = .init(percent: 10, state: .fatigued, muscles: value.recovery.muscles.map {
            .init(muscle: $0.muscle, recoveryPercent: 10, load: 90, fatigue: 90, lastTrainedAt: date, estimatedRecoveryTime: nil, confidence: .medium)
        }, confidence: .medium)
        value.archive.preferences = (0..<20).map { _ in .init(date: date, key: value.training.routines[2].id.uuidString, signal: .accepted) }
        let decision = engine.decide(value)
        XCTAssertEqual(decision.action, .recover); XCTAssertNil(decision.session); XCTAssertFalse(decision.warnings.isEmpty)
    }
    func testLowSleepLowersIntensityAndVeryLowSleepRecovers() {
        var value = context(); value.sleepHours = 5
        XCTAssertEqual(engine.decide(value).action, .trainLight)
        XCTAssertEqual(engine.decide(value).intensity, .light)
        value.sleepHours = 3
        XCTAssertEqual(engine.decide(value).action, .recover)
        value.archive.settings.useSleep = false
        XCTAssertEqual(engine.decide(value).action, .train)
    }
    func testPoorSleepQualityIsAnObservedLimitation() {
        var value = context(); value.sleepQuality = 1
        XCTAssertEqual(engine.decide(value).action, .trainLight)
    }
    func testMissingInputsReduceConfidenceWithoutFabricatingRecovery() {
        let value = PersonalContext(date: date)
        let decision = engine.decide(value)
        XCTAssertEqual(decision.confidence, .low); XCTAssertEqual(decision.action, .trainLight)
        XCTAssertTrue(decision.muscles.allSatisfy { $0.recovery == nil })
        XCTAssertFalse(decision.missing.isEmpty)
        XCTAssertTrue(decision.opportunities.allSatisfy { $0.suggestion.target == nil })
    }
    func testIncompleteMuscleHistoryCannotClaimReadyDespiteGlobalConfidence() {
        var value = context()
        value.recovery = .init(percent: 95, state: .primed, muscles: [], confidence: .high)
        let decision = engine.decide(value)
        XCTAssertEqual(decision.action, .trainLight); XCTAssertEqual(decision.confidence, .low)
    }
    func testPoorClosedNutritionHoldsProgression() {
        var value = context(); value.history = history(); value.proteinAdherence = 0.5
        let decision = engine.decide(value)
        XCTAssertEqual(decision.intensity, .holdLoad)
        XCTAssertTrue(decision.opportunities.allSatisfy { $0.suggestion.target == nil })
        value.archive.settings.useNutrition = false
        XCTAssertEqual(engine.decide(value).intensity, .progressIfReady)
    }
    func testReportedNearMaximumEffortHoldsLoadAndOptionalTargets() {
        var value = context(); value.history = history(rpe: 9)
        let decision = engine.decide(value)
        XCTAssertEqual(decision.intensity, .holdLoad)
        XCTAssertTrue(decision.opportunities.allSatisfy { $0.suggestion.target == nil })
        XCTAssertTrue(decision.warnings.contains { $0.contains("near-maximum") })
    }
    func testRepeatedNutritionAdviceUsesControlledDayVariation() {
        var value = context(); value.proteinAdherence = 0.5
        let first = engine.decide(value).warnings
        XCTAssertEqual(first, engine.decide(value).warnings)
        value.date = date.addingTimeInterval(86400)
        XCTAssertNotEqual(first, engine.decide(value).warnings)
    }
    func testSavedRoutinePreferredAndGeneratedSessionIsStableAndUnsaved() {
        var value = context()
        XCTAssertNotNil(engine.decide(value).routineID)
        value.training.routines = []; value.archive.settings.duration = .short
        let a = engine.decide(value), b = engine.decide(value)
        XCTAssertNil(a.routineID); XCTAssertNotNil(a.session)
        XCTAssertEqual(a.id, b.id); XCTAssertEqual(a.session?.id, b.session?.id)
        XCTAssertEqual(a.session?.exercises.map(\.id), b.session?.exercises.map(\.id))
        XCTAssertTrue((a.session?.exercises.count ?? 100) <= 3)
        XCTAssertTrue(value.training.routines.isEmpty)
    }
    func testGeneratedSessionHonorsHiddenFamiliesAndDuration() {
        var value = context(); value.training.routines = []; value.training.hidden = ["db_row", "pull_up"]
        value.archive.settings.duration = .long
        let decision = engine.decide(value)
        let entries = decision.session?.exercises.compactMap { item in TrainingCatalog.definitions.first { $0.id == item.exerciseID } } ?? []
        XCTAssertFalse(entries.isEmpty)
        XCTAssertFalse(entries.contains { value.training.hidden.contains($0.id) })
        XCTAssertEqual(Set(entries.map(\.pattern)).count, entries.count)
        XCTAssertTrue(entries.count <= 5)
    }
    func testBalanceRemainsWeakAndNeverOverridesRecovery() {
        var value = context(); value.weeklyMovements = [.horizontalPull: 100, .verticalPull: 100]; value.weeklyMuscles = ["Back": 100]
        XCTAssertEqual(engine.decide(value).focus, "Pull")
    }
    func testProgressionTargetComesFromExistingEngine() throws {
        var value = context(); value.history = history()
        let decision = engine.decide(value)
        let opportunity = try XCTUnwrap(decision.opportunities.first { $0.exerciseID == "db_row" })
        let expected = ProgressionEngine().suggest(value.history, exercise: try live(), now: date)
        XCTAssertEqual(opportunity.suggestion.target?.reps, expected.target?.reps)
        XCTAssertEqual(opportunity.suggestion.target?.kilograms, expected.target?.kilograms)
        XCTAssertEqual(decision.intensity, .progressIfReady)
        XCTAssertTrue(opportunity.recordWindow)
        XCTAssertEqual(value.history.first?.working.first?.performance.reps, 8)
    }
    func testPlateauRequiresFourComparableExposuresAndEffort() throws {
        let exercise = try live()
        XCTAssertFalse(engine.plateau(history(count: 1), exercise: exercise, date: date))
        XCTAssertFalse(engine.plateau(history(rpe: 8, count: 3), exercise: exercise, date: date))
        XCTAssertFalse(engine.plateau(history(rpe: 7), exercise: exercise, date: date))
        XCTAssertTrue(engine.plateau(history(rpe: 8), exercise: exercise, date: date))
        var improved = history(rpe: 8); improved.insert(contentsOf: history(reps: 9, rpe: 8, count: 1), at: 0)
        XCTAssertFalse(engine.plateau(improved, exercise: exercise, date: date))
    }
    func testAcceptedAndRejectedPreferencesModestlyRerank() {
        var value = context()
        var a = WorkoutRoutine(name: "Alpha", exercises: [.init("db_row")]); a.id = PersonalBrainEngine.stableID("Alpha")
        var b = WorkoutRoutine(name: "Beta", exercises: [.init("db_row")]); b.id = PersonalBrainEngine.stableID("Beta")
        value.training.routines = [b, a]
        XCTAssertEqual(engine.decide(value).routineID, a.id)
        value.archive.preferences = [.init(date: date, key: b.id.uuidString, signal: .accepted)]
        XCTAssertEqual(engine.decide(value).routineID, b.id)
        value.archive.preferences.append(.init(date: date, key: b.id.uuidString, signal: .rejected))
        XCTAssertEqual(engine.decide(value).routineID, a.id)
        value.archive.preferences = (0..<100).map { _ in .init(date: date, key: b.id.uuidString, signal: .accepted) }
        XCTAssertEqual(engine.preference(b.id.uuidString, context: value), 6)
    }
    func testRecommendationHistoryRecordsOnceAndOnlyExplicitResponse() throws {
        var value = context(); let decision = engine.decide(value)
        value.archive.record(decision, date: date); value.archive.record(decision, date: date)
        XCTAssertEqual(value.archive.history.count, 1); XCTAssertNil(value.archive.history.first?.response)
        value.archive.respond(id: decision.id, signal: .ignored, date: date)
        value.archive.respond(id: decision.id, signal: .accepted, date: date)
        XCTAssertEqual(value.archive.history.first?.response, .ignored)
        let restored = try JSONDecoder().decode(BrainArchive.self, from: JSONEncoder().encode(value.archive))
        XCTAssertEqual(restored.version, 1); XCTAssertEqual(restored.history.first?.response, .ignored)
        let minimal = try JSONDecoder().decode(BrainArchive.self, from: Data("{\"version\":1}".utf8))
        XCTAssertTrue(minimal.settings.enabled); XCTAssertEqual(minimal.settings.duration, .flexible); XCTAssertTrue(minimal.history.isEmpty)
    }
    func testPreferenceWindowsRejectFutureAndExpiredSignals() {
        var value = context()
        value.archive.preferences = [.init(date: date.addingTimeInterval(86400), key: "pull", signal: .accepted),
            .init(date: date.addingTimeInterval(-91 * 86400), key: "pull", signal: .accepted),
            .init(date: date, key: "pull", signal: .ignored)]
        XCTAssertEqual(engine.preference("pull", context: value), -0.5)
    }
    func testCompletedTodayAndFrequentTrainingReduceWork() {
        var value = context(); value.daysSinceLastSession = 0
        XCTAssertEqual(engine.decide(value).action, .maintain); XCTAssertNil(engine.decide(value).session)
        value.daysSinceLastSession = 1; value.trainingDays = 5
        XCTAssertEqual(engine.decide(value).action, .trainLight)
    }
    func testRecoverySubstitutionsNeverSilentlyKeepLimitedFocus() throws {
        let source = try XCTUnwrap(TrainingCatalog.definitions.first { $0.id == "chest_press" })
        let value = context()
        let options = engine.recoveryReplacements(for: source, context: value)
        XCTAssertFalse(options.isEmpty)
        XCTAssertTrue(options.allSatisfy { $0.focus != source.focus && engine.readiness($0, context: value).known && (engine.readiness($0, context: value).minimum ?? 0) >= 70 })
    }
    func testDisabledBrainOffersNoSession() {
        var value = context(); value.archive.settings.enabled = false
        XCTAssertNil(engine.decide(value).session); XCTAssertEqual(engine.decide(value).action, .maintain)
    }
    @MainActor func testFallbackExplainsEngineFactsWithoutChangingDecision() async {
        let decision = engine.decide(context())
        let insight = await FitnessBrain().analyze(.init(trendWeight: nil, momentum: nil, readiness: nil, calories: nil, protein: nil,
            confidence: decision.confidence, observedWeightDays: 0, allowedActions: [], explanationFacts: decision.facts, focus: decision.focus))
        XCTAssertEqual(insight.source, .deterministic); XCTAssertEqual(insight.confidence, decision.confidence)
        XCTAssertEqual(insight.summary, decision.facts.prefix(2).joined(separator: " ")); XCTAssertTrue(insight.recommendations.isEmpty)
    }
    func testSessionAndDayReadOnlyUseRecordedFacts() {
        let summary = CompletedWorkoutSummary(id: UUID(), title: "Pull", durationSeconds: 1200, exerciseCount: 2, workingSets: 6,
            volumeKG: 200, trainingLoad: 6, muscles: [.init(name: "Back", setLoad: 4)], records: [], progressedExercises: 1)
        let facts = engine.sessionRead(summary)
        XCTAssertTrue(facts.first?.contains("6 working sets") ?? false)
        XCTAssertTrue(facts.last?.contains("Back") ?? false)
        let result = DailyGameEngine().evaluate(.init(), previousELO: 1084, momentum: nil, confidence: .low)
        XCTAssertFalse(engine.dayRead(result).contains { $0.contains("91%") })
    }
}
