import Foundation
import SwiftData
import XCTest
@testable import ASCEND

final class AdaptiveCoachPersistenceTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_791_288_000)
    @MainActor private func store() throws -> AppStore { try AppStore(container: PersistenceController.makeContainer(inMemory: true), now: date, clock: { [date] in date }) }
    @MainActor func testTodaysWorkoutObjectivesWeightsAndDraftSurviveRecreation() throws {
        let value = try store()
        let push = try XCTUnwrap(value.exercises.first { $0.catalogID == "push_up" })
        XCTAssertTrue(value.logWorkout(exercise: push, sets: [.init(reps: 100)], at: date, quick: true, exertion: 8))
        XCTAssertTrue(value.logWeight(56.8, at: date))
        var objective = ObjectiveDraft(); objective.title = "My real work"; objective.startsAt = date
        XCTAssertTrue(value.saveObjective(objective)); let occurrence = try XCTUnwrap(value.todayObjectives.first)
        XCTAssertTrue(value.toggleObjective(occurrence))
        value.startLiveWorkout(); value.addLiveExercise(push)
        let draft = try XCTUnwrap(value.activeWorkout), ids = value.sessions.map(\.id), keys = value.todayObjectives.map(\.occurrenceKey)
        let payload = try value.backupEnvelope().payload
        let restored = try AppStore(container: PersistenceController.makeContainer(inMemory: true), now: date, clock: { [date] in date }, restored: payload, activateServices: false)
        XCTAssertEqual(restored.sessions.map(\.id), ids); XCTAssertEqual(restored.sessions.first?.exercises.first?.sets.first?.reps, 100)
        XCTAssertEqual(restored.weights.first?.kilograms, 56.8); XCTAssertEqual(restored.todayObjectives.map(\.occurrenceKey), keys)
        XCTAssertNotNil(restored.todayObjectives.first?.completedAt); XCTAssertEqual(restored.activeWorkout?.id, draft.id)
        XCTAssertEqual(restored.projectedScore.delta, value.projectedScore.delta)
    }
    @MainActor func testLegacyPlusFourLedgerIsNeverRewritten() throws {
        let value = try store(), yesterday = value.policy.adding(days: -1, to: date), key = value.policy.key(for: yesterday)
        let result = ELOResult(previousELO: 96, elo: 100, delta: 4, components: [.init(category: .training, label: "Legacy earned work", points: 4)], rank: RankEngine().status(elo: 100))
        let evaluation = try DailyEvaluation(dayKey: key, date: yesterday, result: result, evaluatedAt: date)
        let entry = ELOHistoryEntry(dayKey: key, date: yesterday, previousELO: 96, elo: 100, delta: 4)
        entry.evaluation = evaluation; evaluation.history = entry; value.context.insert(evaluation); value.context.insert(entry); try value.context.save()
        let bytes = evaluation.componentData
        try value.refresh(at: date); try value.refresh(at: date)
        XCTAssertEqual(value.history.last?.delta, 4); XCTAssertEqual(evaluation.scoringVersion, 1); XCTAssertEqual(evaluation.componentData, bytes)
        XCTAssertEqual(value.score(for: yesterday)?.delta, 4); XCTAssertEqual(value.finalizedResult(entry).elo.delta, 4)
    }
    @MainActor func testAllTodayPresentationsUseSameScoreAndRefreshDoesNotDuplicateLoad() throws {
        let value = try store(), push = try XCTUnwrap(value.exercises.first { $0.catalogID == "push_up" })
        XCTAssertTrue(value.logWorkout(exercise: push, sets: [.init(reps: 100)], at: date, quick: true, exertion: 9))
        let delta = value.projectedScore.delta, exposure = value.weeklyExposure.first { $0.0 == "Chest" }?.1
        XCTAssertEqual(value.dailyResult.elo.delta, delta); XCTAssertEqual(value.coachContext.dailyELO, delta)
        XCTAssertEqual(value.score(for: date)?.delta, delta)
        try value.refresh(at: date); XCTAssertEqual(value.projectedScore.delta, delta)
        XCTAssertEqual(value.weeklyExposure.first { $0.0 == "Chest" }?.1, exposure); XCTAssertEqual(value.sessions.count, 1)
        XCTAssertTrue(value.brainDecision.reasons.contains { $0.contains("already received stimulus") })
    }
    @MainActor func testNewClosedDayPersistsVersionTwoAndBackupAcceptsMixedHistory() throws {
        let value = try store(), push = try XCTUnwrap(value.exercises.first { $0.catalogID == "push_up" })
        XCTAssertTrue(value.logWorkout(exercise: push, sets: [.init(reps: 100)], at: date, quick: true, exertion: 8))
        let id = value.sessions.first?.id
        try value.refresh(at: value.policy.adding(days: 1, to: date))
        XCTAssertEqual(value.evaluations.last?.scoringVersion, 2); XCTAssertEqual(value.history.count, 1)
        XCTAssertEqual(value.sessions.first?.id, id)
        let saved = value.history.last?.delta, credits = value.profile.lifetimeCredits
        try value.refresh(at: value.now); XCTAssertEqual(value.history.last?.delta, saved); XCTAssertEqual(value.profile.lifetimeCredits, credits)
        XCTAssertNoThrow(try value.backupEnvelope().validate())
    }
    @MainActor func testCheckInAddsMeasurementsWithoutDeletingTodayActivity() throws {
        let value = try store(), push = try XCTUnwrap(value.exercises.first { $0.catalogID == "push_up" })
        XCTAssertTrue(value.logWorkout(exercise: push, sets: [.init(reps: 30)], at: date, quick: true, exertion: 7))
        let id = value.sessions.first?.id
        XCTAssertTrue(value.morningCheckIn(weight: 56.8, hours: 7.5, feeling: 2, soreness: 4))
        XCTAssertEqual(value.sessions.first?.id, id); XCTAssertEqual(value.todaySleep?.durationHours, 7.5)
        XCTAssertEqual(value.checkInToday?.soreness, 4); XCTAssertEqual(value.personalContext.feeling, 2)
        XCTAssertEqual(value.brainDecision.intensity, .light)
        XCTAssertNoThrow(try value.backupEnvelope().validate())
    }
    @MainActor func testCheckInDoesNotAlterRecordedSleepInterval() throws {
        let value = try store()
        XCTAssertTrue(value.logSleep(hours: 8, quality: 3, on: date, bedtime: date.addingTimeInterval(-8 * 3600), wakeTime: date))
        XCTAssertFalse(value.morningCheckIn(weight: nil, hours: 6, feeling: 3, soreness: 0))
        XCTAssertEqual(value.todaySleep?.durationHours, 8); XCTAssertNotNil(value.todaySleep?.bedtime)
        XCTAssertNil(value.checkInToday)
    }
    @MainActor func testEffortReviewAndExerciseClockSurviveBackupAndDriveLoad() throws {
        let value = try store(), plank = try XCTUnwrap(value.exercises.first { $0.catalogID == "plank" })
        value.startLiveWorkout(); value.addLiveExercise(plank)
        let exercise = try XCTUnwrap(value.activeWorkout?.exercises.first), set = exercise.sets[0]
        value.startExerciseClock(exerciseID: exercise.id, setID: set.id)
        XCTAssertNotNil(try value.backupEnvelope().payload.live?.exerciseClock)
        XCTAssertTrue(value.finishExerciseClock())
        value.setEffort(exerciseID: exercise.id, setID: set.id, rating: .nearFailure)
        XCTAssertEqual(value.activeWorkout?.exercises.first?.sets.first?.rpe, 9)
        XCTAssertTrue(value.finishLiveWorkout()); XCTAssertEqual(value.sessions.first?.exercises.first?.sets.first?.perceivedExertion, 9)
        XCTAssertNil(value.activeWorkout); XCTAssertGreaterThan(value.canonicalLoads.first?.challengingSets ?? 0, 0)
    }
    @MainActor func testAutoregulationNeverOverwritesCompletedSetsOrActsWithoutConsent() throws {
        let value = try store(), press = try XCTUnwrap(value.exercises.first { $0.catalogID == "chest_press" })
        XCTAssertTrue(value.editTraining { $0.profile.equipment.insert(.chestPress) }); value.startLiveWorkout(); value.addLiveExercise(press)
        let id = try XCTUnwrap(value.activeWorkout?.exercises.first?.id)
        value.changeLiveExercise(id) { exercise in exercise.sets = [10, 9, 5, 8].enumerated().map { index, reps in var set = LiveSet(); set.reps = reps; set.kilograms = 60; set.completedAt = index < 3 ? self.date : nil; return set } }
        let exercise = try XCTUnwrap(value.activeWorkout?.exercises.first), advice = try XCTUnwrap(AdaptiveRestEngine().advice(exercise))
        XCTAssertEqual(value.activeWorkout?.exercises.first?.sets.last?.kilograms, 60)
        value.acceptAutoregulation(advice, exerciseID: id, lowerLoad: true)
        XCTAssertEqual(value.activeWorkout?.exercises.first?.sets.prefix(3).map(\.kilograms), [60, 60, 60])
        XCTAssertLessThan(value.activeWorkout?.exercises.first?.sets.last?.kilograms ?? 60, 60)
    }
    @MainActor func testAskAscendReferencesRealScoreNutritionAndUnknownBench() throws {
        let value = try store()
        XCTAssertTrue(value.logNutrition(calories: 1800, protein: 100, on: date))
        let context = value.coachContext, engine = CoachReasoningEngine()
        XCTAssertTrue(engine.answer("What should I eat today?", context: context).observed.contains { $0.contains("1800") })
        XCTAssertTrue(engine.answer("Why did I lose ELO?", context: context).observed.contains { $0.contains(String(context.dailyELO)) })
        XCTAssertTrue(engine.answer("Should I increase my bench?", context: context).recommendation.contains("Without observed loads"))
        XCTAssertNil(value.goalProjection.weeks)
    }
    @MainActor func testMalformedNewSidecarFieldsAreRejectedWithoutChangingOwner() throws {
        let value = try store(); let sessions = value.sessions.map(\.id)
        XCTAssertFalse(value.saveOwnerSystem { $0.checkIns = [.init(date: self.date, feeling: 99, soreness: 0)] })
        XCTAssertNil(value.ownerSystem.checkIns); XCTAssertEqual(value.sessions.map(\.id), sessions)
    }
}
