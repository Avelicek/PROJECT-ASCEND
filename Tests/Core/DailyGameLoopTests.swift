import Foundation
import XCTest
#if canImport(AscendCore)
@testable import AscendCore
#else
@testable import ASCEND
#endif

final class DailyGameLoopTests: XCTestCase {
    func testRestArcSpanPersistsAndOlderDraftsRemainDecodable() throws {
        let date = Date(timeIntervalSince1970: 1000)
        var timer = RestClock(); timer.start(seconds: 90, exerciseID: "bench", at: date)
        timer.add(seconds: 30, at: date.addingTimeInterval(30))
        XCTAssertEqual(timer.spanSeconds, 120); XCTAssertEqual(timer.remaining(at: date.addingTimeInterval(30)), 90)
        let data = try JSONEncoder().encode(timer)
        XCTAssertEqual(try JSONDecoder().decode(RestClock.self, from: data).spanSeconds, 120)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]); old.removeValue(forKey: "spanSeconds")
        let restored = try JSONDecoder().decode(RestClock.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(restored.spanSeconds); XCTAssertEqual(restored.remaining(at: date.addingTimeInterval(30)), 90)
    }
    func testTrackingModesDoNotInventRepsOrRequireAddedWeightForBodyweight() {
        var set = LiveSet(); set.reps = 12; set.kilograms = 0
        XCTAssertTrue(set.isValid(for: .weightAndReps, allowsWeight: true, bodyweight: true))
        XCTAssertFalse(set.isValid(for: .weightAndReps, allowsWeight: true, bodyweight: false))
        XCTAssertEqual(set.performance(for: .duration).reps, 0)
        XCTAssertEqual(set.performance(for: .duration).distanceMeters, 0)
        XCTAssertEqual(set.performance(for: .reps).seconds, 0)
        XCTAssertEqual(set.performance(for: .distance).reps, 0)
    }
    private var now: Date { Date(timeIntervalSince1970: 1_791_288_000) }
    private var bench: LiveExercise { .init(catalogID: "bench", name: "Bench", mode: .weightAndReps, bodyweight: false, addedWeight: false, contributions: [.init(.midPectoral, 0.7), .init(.tricepsLongHead, 0.3)]) }
    private func history(days: Int, reps: [Int] = [8, 8], kg: Double = 55, rpe: Double? = 7, quick: Bool = false) -> ExerciseHistory {
        .init(exerciseID: "bench", date: now.addingTimeInterval(Double(days) * 86400), mode: .weightAndReps, quick: quick,
            sets: reps.map { .init(.init(reps: $0, kilograms: kg), rpe: rpe) })
    }
    private func completed(reps: Int, kg: Double, warmup: Bool = false, rpe: Double? = 7) -> LiveSet {
        var value = LiveSet(); value.reps = reps; value.kilograms = kg; value.isWarmup = warmup; value.rpe = rpe; value.completedAt = now
        return value
    }
    func testConservativeRepSuggestionNeedsTwoComparableSessions() throws {
        let engine = ProgressionEngine()
        XCTAssertNil(engine.suggest([history(days: -2)], exercise: bench, now: now).target)
        let result = engine.suggest([history(days: -7), history(days: -2)], exercise: bench, now: now)
        XCTAssertEqual(try XCTUnwrap(result.target).reps, 9)
        XCTAssertEqual(result.target?.kilograms, 55); XCTAssertEqual(result.confidence, .high)
    }
    func testConsistentHigherRepsAllowOnlySmallLoadStep() throws {
        let result = ProgressionEngine().suggest([history(days: -7, reps: [10, 10]), history(days: -2, reps: [10, 11])], exercise: bench, now: now)
        XCTAssertEqual(try XCTUnwrap(result.target).kilograms, 57.5); XCTAssertEqual(result.target?.reps, 7)
        let lightLoad = ProgressionEngine().suggest([history(days: -7, reps: [10, 10], kg: 20), history(days: -2, reps: [10, 10], kg: 20)], exercise: bench, now: now)
        XCTAssertEqual(lightLoad.target?.kilograms, 20); XCTAssertEqual(lightLoad.target?.reps, 11)
    }
    func testHighEffortStaleVariableOrRecoveryLimitedHistoryHolds() {
        let engine = ProgressionEngine()
        for data in [[history(days: -7, rpe: 9), history(days: -2)], [history(days: -60), history(days: -2)], [history(days: -7, reps: [5, 10]), history(days: -2)]] {
            let result = engine.suggest(data, exercise: bench, now: now)
            XCTAssertNil(result.target); XCTAssertEqual(result.confidence, .low)
        }
        XCTAssertNil(engine.suggest([history(days: -7), history(days: -2)], exercise: bench, now: now, recoveryLimited: true).target)
        XCTAssertEqual(engine.suggest([history(days: -7, rpe: nil), history(days: -2, rpe: nil)], exercise: bench, now: now).confidence, .medium)
    }
    func testBodyweightSuggestionNeverAddsExternalLoad() throws {
        let exercise = LiveExercise(catalogID: "pull", name: "Pull", mode: .reps, bodyweight: true, addedWeight: true, contributions: [])
        let data = [-7, -2].map { day in ExerciseHistory(exerciseID: "pull", date: now.addingTimeInterval(Double(day) * 86400), mode: .reps,
            sets: [.init(.init(reps: 10), rpe: 7), .init(.init(reps: 10), rpe: 7)]) }
        let result = ProgressionEngine().suggest(data, exercise: exercise, now: now)
        XCTAssertEqual(try XCTUnwrap(result.target).kilograms, 0); XCTAssertEqual(result.target?.reps, 11)
    }
    func testPreviousLookupExcludesFutureQuickWrongModeAndWarmupOnly() throws {
        let wrongMode = ExerciseHistory(exerciseID: "bench", date: now, mode: .duration, sets: [.init(.init(reps: 0, seconds: 60))])
        let warmup = ExerciseHistory(exerciseID: "bench", date: now, mode: .weightAndReps, sets: [.init(.init(reps: 8, kilograms: 20), warmup: true)])
        let data = [history(days: -6), history(days: 1), history(days: -1, quick: true), wrongMode, warmup, history(days: -2)]
        XCTAssertEqual(try XCTUnwrap(ProgressionEngine().previous(data, exercise: bench, now: now)).date, history(days: -2).date)
    }
    func testProgressionComparesBestPreviousSetAndMatchedEffort() {
        let previous = history(days: -2, reps: [8, 6])
        XCTAssertFalse(ProgressionEngine().progressed(current: history(days: 0, reps: [8, 8]), prior: [previous]))
        XCTAssertTrue(ProgressionEngine().progressed(current: history(days: 0, reps: [9, 8]), prior: [previous]))
        XCTAssertTrue(ProgressionEngine().progressed(current: history(days: 0, rpe: 6), prior: [previous]))
        XCTAssertFalse(ProgressionEngine().progressed(current: history(days: 0, reps: [9, 8], rpe: 9), prior: [previous]))
    }
    func testPRsExcludeWarmupsAndCompareRepsAtSameExternalLoad() throws {
        var exercise = bench
        exercise.sets = [completed(reps: 9, kg: 55), completed(reps: 8, kg: 55), completed(reps: 20, kg: 100, warmup: true)]
        let records = PersonalRecordEngine().detect(exercise: exercise, history: [history(days: -7)], at: now)
        XCTAssertEqual(Set(records.map(\.kind)), Set([.reps, .volume, .estimatedOneRepMax]))
        let reps = try XCTUnwrap(records.first { $0.kind == .reps }); XCTAssertEqual(reps.contextKG, 55); XCTAssertEqual(reps.previous, 8); XCTAssertEqual(reps.value, 9)
        exercise.sets = [completed(reps: 12, kg: 60)]
        let changedLoad = PersonalRecordEngine().detect(exercise: exercise, history: [history(days: -7)], at: now)
        XCTAssertFalse(changedLoad.contains { $0.kind == .reps }); XCTAssertTrue(changedLoad.contains { $0.kind == .weight })
    }
    func testNoHistoryNoPRAndBodyweightNeverInventsOneRepMax() {
        var exercise = bench; exercise.sets = [completed(reps: 8, kg: 55)]
        XCTAssertTrue(PersonalRecordEngine().detect(exercise: exercise, history: [], at: now).isEmpty)
        var bodyweight = LiveExercise(catalogID: "pull", name: "Pull", mode: .reps, bodyweight: true, addedWeight: true, contributions: [])
        bodyweight.sets = [completed(reps: 11, kg: 0)]
        let previous = ExerciseHistory(exerciseID: "pull", date: now.addingTimeInterval(-86400), mode: .reps, sets: [.init(.init(reps: 10))])
        XCTAssertEqual(PersonalRecordEngine().detect(exercise: bodyweight, history: [previous], at: now).map(\.kind), [.reps, .totalReps])
    }
    func testSummaryIncludesOnlyCompletedWorkingVolumeAndEffortLoad() throws {
        var draft = LiveWorkout(startedAt: now.addingTimeInterval(-600))
        var exercise = bench
        exercise.sets = [completed(reps: 8, kg: 55, rpe: 8), completed(reps: 10, kg: 20, warmup: true), LiveSet()]
        draft.exercises = [exercise]
        let summary = WorkoutSummaryEngine().summarize(draft, history: [], finishedAt: now)
        XCTAssertEqual(summary.durationSeconds, 600); XCTAssertEqual(summary.exerciseCount, 1); XCTAssertEqual(summary.workingSets, 1)
        XCTAssertEqual(summary.volumeKG, 440); XCTAssertEqual(summary.trainingLoad, 1)
        XCTAssertEqual(try XCTUnwrap(summary.muscles.first { $0.name == "Chest" }).setLoad, 0.7, accuracy: 0.001)
    }
    func testDailyGradeELOBreakdownAndMomentumConfidence() {
        var input = ELOInput(); input.calorieAdherence = 1; input.proteinAdherence = 1; input.completedWorkout = true
        input.personalRecords = 1
        let result = DailyGameEngine().evaluate(input, previousELO: 99, momentum: 18, confidence: .medium)
        XCTAssertEqual(result.grade, "A"); XCTAssertEqual(result.status, "PROGRESS"); XCTAssertEqual(result.momentum, 18)
        XCTAssertEqual(result.elo.delta, 13); XCTAssertEqual(result.elo.components.reduce(0) { $0 + $1.points }, result.elo.delta)
        XCTAssertTrue(result.elo.rank.rankedUp)
        XCTAssertNil(DailyGameEngine().evaluate(input, previousELO: 99, momentum: 18, confidence: .low).momentum)
        input = ELOInput(); input.objectives = [.init(title: "Due", completed: false, importance: .standard)]
        let negative = DailyGameEngine().evaluate(input, previousELO: 100, momentum: nil, confidence: .low)
        XCTAssertEqual(negative.grade, "D"); XCTAssertEqual(negative.status, "DOWNGRADE"); XCTAssertTrue(negative.elo.rank.rankedDown)
    }
    func testRecoveryRecommendationNeedsHistoryAndExplicitExemptionProtectsELO() {
        let load = TrainingLoad(date: now, contributions: [.init(.midPectoral, 1)], challengingSets: 10, intensity: 1)
        let supported = RecoveryContext(sleepHours: 8, sleepQuality: 4, calorieAdherence: 1, proteinAdherence: 1, historyDays: 28, trainingSessions: 6)
        let full = RecoveryEngine().evaluate(loads: [load], context: supported, now: now)
        XCTAssertEqual(full.confidence, .medium)
        XCTAssertTrue(ObjectiveEngine().shouldExempt(contributions: [.init(.midPectoral, 0.7)], recovery: full))
        let sparse = RecoveryEngine().evaluate(loads: [load], context: .init(), now: now)
        XCTAssertFalse(ObjectiveEngine().shouldExempt(contributions: [.init(.midPectoral, 0.7)], recovery: sparse))
        var input = ELOInput(); input.recoverySafeChoice = true
        input.objectives = [.init(title: "Push-ups", completed: false, importance: .major, recoveryExempt: true)]
        XCTAssertEqual(ELOEngine().evaluate(input, previousELO: 100).delta, 1)
    }
    func testRawRecoveryLoadStaysDistinctFromElapsedFatigueAndZeroLoadUnlogged() throws {
        let load = TrainingLoad(date: now.addingTimeInterval(-48 * 3600), contributions: [.init(.midPectoral, 1)], challengingSets: 4, intensity: 1)
        let muscle = try XCTUnwrap(RecoveryEngine().evaluate(loads: [load], context: .init(), now: now).muscles.first { $0.muscle == .midPectoral })
        XCTAssertEqual(muscle.load, 36); XCTAssertLessThan(muscle.fatigue, muscle.load)
        let zero = TrainingLoad(date: now, contributions: [.init(.midPectoral, 1)], challengingSets: 0, intensity: 1)
        XCTAssertNil(RecoveryEngine().evaluate(loads: [zero], context: .init(), now: now).muscles.first { $0.muscle == .midPectoral }?.lastTrainedAt)
    }
    func testRestDeadlinePauseAddResumeCompletionOnceAndCodableRestore() throws {
        var timer = RestClock(); timer.start(seconds: 90, exerciseID: "bench", at: now)
        timer.pause(at: now.addingTimeInterval(30)); XCTAssertEqual(timer.remaining(at: now.addingTimeInterval(300)), 60)
        timer.add(seconds: 30, at: now); timer.resume(at: now.addingTimeInterval(300))
        var restored = try JSONDecoder().decode(RestClock.self, from: JSONEncoder().encode(timer))
        XCTAssertEqual(restored.remaining(at: now.addingTimeInterval(330)), 60)
        XCTAssertTrue(restored.consumeCompletion(at: now.addingTimeInterval(390)))
        XCTAssertFalse(restored.consumeCompletion(at: now.addingTimeInterval(391))); XCTAssertFalse(restored.isActive)
    }
    func testDailyStreakUsesCalendarDaysAcrossDSTAndDoesNotCountFuture() throws {
        let policy = DayPolicy(timeZoneIdentifier: "Europe/Prague")
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-03-30T10:00:00Z"))
        let days = [-3, -2, -1, 1].map { policy.adding(days: $0, to: date) }
        XCTAssertEqual(StreakEngine().daily(qualifyingDays: days, now: date, policy: policy), 3)
        XCTAssertEqual(StreakEngine().daily(qualifyingDays: days + [date], now: date, policy: policy), 4)
        XCTAssertEqual(StreakEngine().daily(qualifyingDays: [policy.adding(days: -2, to: date)], now: date, policy: policy), 0)
    }
    func testTrainingStreakCountsDistinctDaysAndAllowsCurrentWeekRest() {
        let policy = DayPolicy(timeZoneIdentifier: "UTC")
        let week = policy.calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let dates = [-13, -11, -6, -4].map { policy.adding(days: $0, to: week) }
        XCTAssertEqual(StreakEngine().workoutWeeks(dates: dates, now: now, policy: policy), 2)
        XCTAssertEqual(StreakEngine().workoutWeeks(dates: [dates[2], dates[2]], now: now, policy: policy), 0)
    }
    func testFocusedExplanationFallbackOnlyUsesSuppliedFacts() {
        let context = BrainContext(trendWeight: nil, momentum: nil, readiness: nil, calories: nil, protein: nil, confidence: .low,
            observedWeightDays: 0, allowedActions: [], explanationFacts: ["Two sessions are required before increasing the target."], focus: "Progression")
        let result = DeterministicBrainProvider().insight(context)
        XCTAssertEqual(result.summary, context.explanationFacts.first); XCTAssertEqual(result.confidence, .low); XCTAssertTrue(result.recommendations.isEmpty)
    }
}
