import Foundation
import XCTest
#if canImport(AscendCore)
@testable import AscendCore
#else
@testable import ASCEND
#endif

final class AdaptiveCoachTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_288_000)
    private let policy = DayPolicy(timeZoneIdentifier: "Europe/Prague")
    func testIndividualEffortChangesStimulusAndRecovery() {
        let sets = Array(repeating: SetPerformance(reps: 12), count: 3)
        let engine = TrainingLoadEngine()
        let easy = engine.stimulus(sets.map { .init($0, rpe: 6) }, mode: .reps, quick: false)
        let hard = engine.stimulus(sets.map { .init($0, rpe: 9) }, mode: .reps, quick: false)
        XCTAssertGreaterThan(hard, easy * 1.5)
        let recovery = RecoveryEngine()
        let contributions: [MuscleContribution] = [.init(.midPectoral, 0.5)]
        let a = recovery.evaluate(loads: [.init(date: now, contributions: contributions, challengingSets: easy, intensity: 1)], context: .init(), now: now)
        let b = recovery.evaluate(loads: [.init(date: now, contributions: contributions, challengingSets: hard, intensity: 1)], context: .init(), now: now)
        XCTAssertLessThan(b.muscles.first { $0.muscle == .midPectoral }!.recoveryPercent, a.muscles.first { $0.muscle == .midPectoral }!.recoveryPercent)
    }
    func testWarmupsAndZeroRepsDoNotCreateStimulus() {
        XCTAssertEqual(TrainingLoadEngine().stimulus([.init(.init(reps: 20), rpe: 10, warmup: true), .init(.init(reps: 0), rpe: 10)], mode: .reps, quick: false), 0)
    }
    func testPushUpContributionsIncludePressingAndCore() throws {
        let exercise = try XCTUnwrap(TrainingCatalog.definitions.first { $0.id == "push_up" })
        let stimulus = TrainingLoadEngine().stimulus([.init(.init(reps: 100), rpe: 8)], mode: .reps, quick: true)
        let muscles = TrainingLoadEngine().muscles(stimulus: stimulus, contributions: exercise.muscles)
        for muscle in [Muscle.midPectoral, .tricepsLongHead, .anteriorDeltoid, .rectusAbdominis] { XCTAssertGreaterThan(muscles[muscle, default: 0], 0) }
        XCTAssertGreaterThan(muscles[.midPectoral, default: 0], muscles[.rectusAbdominis, default: 0])
    }
    func testHardFortyCanExceedEffortlessHundred() {
        let engine = TrainingLoadEngine()
        XCTAssertGreaterThan(engine.stimulus([.init(.init(reps: 40), rpe: 10)], mode: .reps, quick: true), engine.stimulus([.init(.init(reps: 100), rpe: 3)], mode: .reps, quick: true))
    }
    func testDailyScorePersonalizesToObservedBaseline() {
        var input = DailyELOInput(); input.stimulus = 6; input.expectedStimulus = 6
        let a = DailyELOEngine().evaluate(input, previousELO: 100)
        input.expectedStimulus = 15
        XCTAssertGreaterThan(a.delta, DailyELOEngine().evaluate(input, previousELO: 100).delta)
    }
    func testDailyScoreBoundsAndComponentsReconcile() {
        var input = DailyELOInput(); input.stimulus = 100; input.facts.calorieAdherence = 1; input.facts.proteinAdherence = 1
        input.facts.trainingProgressed = true; input.facts.personalRecords = 10; input.sleepHours = 8; input.checkIn = true; input.facts.consistent = true; input.recentTrainingDays = 5
        input.facts.objectives = [.init(title: "Training", completed: true, importance: .major)]
        let result = DailyELOEngine().evaluate(input, previousELO: 100)
        XCTAssertLessThanOrEqual(result.delta, 30); XCTAssertEqual(result.components.reduce(0) { $0 + $1.points }, result.delta)
        XCTAssertEqual(result.elo - result.previousELO, result.delta)
    }
    func testRestOnlyHasModestRewardAndUnknownInactivityHasNone() {
        var input = DailyELOInput()
        XCTAssertEqual(DailyELOEngine().evaluate(input, previousELO: 100).delta, 0)
        input.recoveryLimited = true
        XCTAssertEqual(DailyELOEngine().evaluate(input, previousELO: 100).delta, 2)
        input.stimulus = 8; input.recoveryLimited = false
        XCTAssertGreaterThan(DailyELOEngine().evaluate(input, previousELO: 100).delta, 2)
    }
    func testOpenDayDoesNotPunishUnfinishedFuelAndObjectives() {
        var input = DailyELOInput(); input.facts.calorieAdherence = 0.3; input.facts.proteinAdherence = 0.2
        input.facts.objectives = [.init(title: "Training", completed: false, importance: .major)]
        XCTAssertEqual(DailyELOEngine().evaluate(input, previousELO: 100).delta, 0)
        input.closed = true
        XCTAssertLessThan(DailyELOEngine().evaluate(input, previousELO: 100).delta, 0)
    }
    func testRankFloorRetainsBackupArithmetic() {
        var input = DailyELOInput(); input.closed = true; input.sleepHours = 3
        let result = DailyELOEngine().evaluate(input, previousELO: 1)
        XCTAssertEqual(result.elo, 0); XCTAssertEqual(result.delta, -1)
        XCTAssertEqual(result.components.reduce(0) { $0 + $1.points }, result.delta)
    }
    func testQuickActivityProducesOneComponent() {
        var input = DailyELOInput(); input.stimulus = 6; input.spontaneousStimulus = 6
        let result = DailyELOEngine().evaluate(input, previousELO: 100)
        XCTAssertEqual(result.components.filter { $0.category == .training }.count, 1)
        XCTAssertFalse(result.components.contains { $0.label.contains("execution") })
    }
    func testGeneratorUsesAvailableEquipmentAndRespectsTime() {
        var context = PersonalContext(date: now); context.dayKey = "2026-10-06"; context.training.profile.equipment = [.bodyweight]; context.training.profile.sessionMinutes = 20
        let result = WorkoutGenerationEngine().decide(context)
        XCTAssertNotNil(result.session)
        for item in result.session?.exercises ?? [] {
            let entry = TrainingCatalog.definitions.first { $0.id == item.exerciseID }!
            XCTAssertTrue(TrainingSystem().missing(entry, profile: context.training.profile).isEmpty)
        }
        XCTAssertLessThanOrEqual(result.duration ?? 100, 20)
    }
    func testSpontaneousPushupsRemoveOverlappingPressing() throws {
        var context = PersonalContext(date: now); context.dayKey = "2026-10-06"
        let push = try XCTUnwrap(TrainingCatalog.definitions.first { $0.id == "push_up" })
        let units = TrainingLoadEngine().stimulus([.init(.init(reps: 100), rpe: 8)], mode: .reps, quick: true)
        context.todayMuscles = TrainingLoadEngine().muscles(stimulus: units, contributions: push.muscles)
        let result = WorkoutGenerationEngine().decide(context)
        XCTAssertFalse(result.session?.exercises.contains { ["push_up", "close_grip_push_up", "bench_press", "chest_press"].contains($0.exerciseID) } ?? false)
        XCTAssertTrue(result.reasons.contains { $0.contains("already received stimulus") })
    }
    func testGeneratorIsDeterministicAndPreservesTemplates() {
        var context = PersonalContext(date: now); context.dayKey = "2026-10-06"
        let templates = context.training.routines.map(\.id)
        let first = WorkoutGenerationEngine().decide(context), second = WorkoutGenerationEngine().decide(context)
        XCTAssertEqual(first.id, second.id); XCTAssertEqual(first.session?.id, second.session?.id)
        XCTAssertEqual(first.session?.exercises.map(\.id), second.session?.exercises.map(\.id))
        XCTAssertEqual(context.training.routines.map(\.id), templates); XCTAssertNil(first.routineID)
    }
    func testGeneratorProtectsSickSleepAndActiveSession() {
        var context = PersonalContext(date: now)
        context.sickMode = true; XCTAssertNil(WorkoutGenerationEngine().decide(context).session)
        context.sickMode = false; context.sleepMode = true; XCTAssertNil(WorkoutGenerationEngine().decide(context).session)
        context.sleepMode = false; context.activeWorkout = true; XCTAssertNil(WorkoutGenerationEngine().decide(context).session)
    }
    func testNearFailureSixtyNeverBecomesNinety() {
        let exercise = LiveExercise(catalogID: "chest_press", name: "Chest press", mode: .weightAndReps, bodyweight: false, addedWeight: false, contributions: [])
        let history = [1, 3].map { days in ExerciseHistory(exerciseID: "chest_press", date: now.addingTimeInterval(Double(-days) * 86400), mode: .weightAndReps,
            sets: [.init(.init(reps: 10, kilograms: 60), rpe: 8), .init(.init(reps: 9, kilograms: 60), rpe: 9), .init(.init(reps: 7, kilograms: 60), rpe: 10)]) }
        let result = ProgressionEngine().suggest(history, exercise: exercise, now: now)
        XCTAssertLessThanOrEqual(result.target?.kilograms ?? 60, 60)
        XCTAssertTrue(result.explanation.contains("Repeat"))
    }
    func testRIRMapsExactlyToStoredRPE() { XCTAssertEqual(EffortRating.failure.rir, 0); XCTAssertEqual(EffortRating.hard.rir, 2); XCTAssertEqual(EffortRating.easy.rir, 4) }
    func testDifficultSessionPrescribesStablePerSetRepsAtSixty() throws {
        let exercise = LiveExercise(catalogID: "chest_press", name: "Chest press", mode: .weightAndReps, bodyweight: false, addedWeight: false, contributions: [])
        let history = [ExerciseHistory(exerciseID: "chest_press", date: now.addingTimeInterval(-86400), mode: .weightAndReps,
            sets: [.init(.init(reps: 10, kilograms: 60), rpe: 8), .init(.init(reps: 9, kilograms: 60), rpe: 9), .init(.init(reps: 7, kilograms: 60), rpe: 10)])]
        let targets = try XCTUnwrap(ProgressionPlanEngine().targets(history: history, exercise: exercise, count: 3, now: now, recoveryLimited: false))
        XCTAssertEqual(targets.map(\.kilograms), [60, 60, 60]); XCTAssertEqual(targets.map(\.reps), [10, 10, 8])
    }
    func testRestDependsOnTypeEffortAndPreference() {
        let engine = AdaptiveRestEngine()
        XCTAssertEqual(engine.seconds(pattern: .horizontalPush, goal: .strength, rpe: 9, fatigue: nil), 150)
        XCTAssertEqual(engine.seconds(pattern: .horizontalPull, goal: .strengthAndMuscle, rpe: 7, fatigue: nil), 90)
        XCTAssertEqual(engine.seconds(pattern: .elbowFlexion, goal: .strengthAndMuscle, rpe: 7, fatigue: nil), 60)
        XCTAssertEqual(engine.seconds(pattern: .elbowFlexion, goal: .strength, rpe: 10, fatigue: 90, preference: 75), 75)
    }
    func testAutoregulationIsBoundedAndOnlyForComparableDrop() throws {
        var exercise = LiveExercise(catalogID: "chest_press", name: "Chest press", mode: .weightAndReps, bodyweight: false, addedWeight: false, contributions: [])
        exercise.sets = [10, 9, 5].map { reps in var set = LiveSet(); set.reps = reps; set.kilograms = 60; set.completedAt = now; return set }
        let result = try XCTUnwrap(AdaptiveRestEngine().advice(exercise))
        XCTAssertEqual(result.extraRest, 45); XCTAssertLessThan(result.kilograms ?? 60, 60); XCTAssertGreaterThanOrEqual(result.kilograms ?? 0, 54)
        exercise.sets[2].kilograms = 40; XCTAssertNil(AdaptiveRestEngine().advice(exercise))
    }
    func testAbsoluteExerciseClockPauseResumeAndLegacyDraftDecode() throws {
        var clock = ExerciseClock(exerciseID: UUID(), setID: UUID(), at: now)
        clock.pause(at: now.addingTimeInterval(42)); XCTAssertEqual(clock.elapsed(at: now.addingTimeInterval(3600)), 42)
        clock.resume(at: now.addingTimeInterval(3600)); XCTAssertEqual(clock.elapsed(at: now.addingTimeInterval(3610)), 52)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(LiveWorkout(startedAt: now))) as? [String: Any])
        object.removeValue(forKey: "exerciseClock")
        let restored = try JSONDecoder().decode(LiveWorkout.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(restored.exerciseClock); XCTAssertTrue(restored.isStructurallyValid)
    }
    func testLegacyOwnerSidecarDecodesWithNewOptionalFieldsAbsent() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(OwnerSystem())) as? [String: Any])
        object.removeValue(forKey: "checkIns"); object.removeValue(forKey: "coachPreferences")
        let restored = try JSONDecoder().decode(OwnerSystem.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(restored.checkIns); XCTAssertNil(restored.coachPreferences); XCTAssertNoThrow(try restored.validate())
    }
    func testProjectionRejectsSparseDuplicateDaysAndStaleSamples() {
        let engine = ProjectionEngine(), samples = Array(repeating: WeightSample(date: now, kilograms: 56), count: 12)
        XCTAssertNil(engine.weight(samples: samples, target: 60, now: now, policy: policy).weeks)
        XCTAssertEqual(engine.weight(samples: samples, target: 60, now: now, policy: policy).observedDays, 1)
        let old = (0..<14).map { WeightSample(date: now.addingTimeInterval(Double($0 - 50) * 86400), kilograms: 56 + Double($0) * 0.04) }
        XCTAssertNil(engine.weight(samples: old, target: 60, now: now, policy: policy).weeks)
    }
    func testProjectionSupportsGainingAndLosingAndRejectsWrongDirection() {
        let gaining = (0..<15).map { WeightSample(date: policy.adding(days: $0 - 14, to: now), kilograms: 56 + Double($0) * 0.04) }
        let engine = ProjectionEngine()
        let result = engine.weight(samples: gaining, target: 60, now: now, policy: policy)
        XCTAssertNotNil(result.weeks); XCTAssertNotNil(result.earliest); XCTAssertGreaterThanOrEqual(result.latest!, result.earliest!)
        XCTAssertNil(engine.weight(samples: gaining, target: 50, now: now, policy: policy).weeks)
        let losing = gaining.map { WeightSample(date: $0.date, kilograms: 120 - $0.kilograms) }
        XCTAssertNotNil(engine.weight(samples: losing, target: 60, now: now, policy: policy).weeks)
    }
    func testEveryCatalogExerciseHasExecutionAndCues() {
        for exercise in TrainingCatalog.definitions { let guide = ExerciseEducation.guide(exercise); XCTAssertGreaterThanOrEqual(guide.steps.count, 2); XCTAssertFalse(guide.cues.isEmpty) }
    }
    func testSupplementaryMeasurementRoundTripDoesNotInterpretArbitraryUnitsAsLoad() throws {
        let calories = ActivityMeasurement(mode: .caloriesDuration, value: 220, unit: "kcal")
        XCTAssertEqual(ActivityMeasurement.decodeNote(try calories.encodedNote())?.value, 220)
        let custom = ActivityMeasurement(mode: .custom, value: 42, unit: "laps")
        XCTAssertEqual(ActivityMeasurement.decodeNote(try custom.encodedNote())?.unit, "laps")
        XCTAssertNil(ActivityMeasurement.decodeNote("My original workout notes"))
        XCTAssertFalse(ActivityMeasurement(mode: .custom, value: .nan, unit: "laps").isValid)
        XCTAssertFalse(ActivityMeasurement(mode: .caloriesDuration, value: 100, unit: "kg").isValid)
        XCTAssertFalse(ActivityMeasurement(mode: .custom, value: 1, unit: "").isValid)
        XCTAssertEqual(ExerciseMeasurementMode.allCases.count, 8)
        let plank = try XCTUnwrap(TrainingCatalog.definitions.first { $0.id == "plank" })
        XCTAssertEqual(ExerciseMeasurementMode.standard(for: plank), .hold)
    }

}
