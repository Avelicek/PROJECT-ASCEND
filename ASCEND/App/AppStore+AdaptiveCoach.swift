import Foundation
import SwiftData

extension AppStore {
    func stimulus(for exercise: WorkoutExercise, quick: Bool) -> Double { activityStimulus[exercise.id] ?? 0 }
    var canonicalLoads: [TrainingLoad] { activityLoads }
    func rebuildActivityLoads() {
        var units: [UUID: Double] = [:], loads: [TrainingLoad] = []
        var previous: [String: (Double, Date)] = [:]
        for session in sessions.filter({ $0.hasWorkingSets }).sorted(by: { $0.evaluationDate < $1.evaluationDate }) {
            for exercise in session.exercises {
                let key = (exercise.exercise?.catalogID ?? exercise.exerciseName) + ":" + exercise.trackingModeRaw
                let reference = previous[key].flatMap { session.evaluationDate.timeIntervalSince($0.1) <= 42 * 86400 ? $0.0 : nil }
                let sets = exercise.sets.sorted { $0.order < $1.order }.map { PerformedSet($0.performance, rpe: $0.perceivedExertion, warmup: $0.isWarmup) }
                let stimulus = TrainingLoadEngine().stimulus(sets, mode: exercise.trackingMode, quick: session.isQuickLog, referenceLoad: reference)
                units[exercise.id] = stimulus
                loads.append(.init(date: session.evaluationDate, contributions: exercise.contributions, challengingSets: stimulus, intensity: 1))
                if !session.isQuickLog, let load = sets.first(where: { !$0.warmup && $0.performance.kilograms > 0 })?.performance.kilograms { previous[key] = (load, session.evaluationDate) }
            }
        }
        activityStimulus = units; activityLoads = loads
    }
    func dailyScoreInput(for date: Date, closed: Bool = false) -> DailyELOInput {
        var input = DailyELOInput(); input.facts = evaluationInput(for: date, includeMisses: closed); input.closed = closed
        let daySessions = sessions.filter { $0.hasWorkingSets && policy.sameDay($0.evaluationDate, date) }
        for session in daySessions {
            let load = session.exercises.reduce(0) { $0 + stimulus(for: $1, quick: session.isQuickLog) }
            input.stimulus += load; if session.isQuickLog { input.spontaneousStimulus += load }
        }
        let lower = policy.adding(days: -28, to: policy.start(of: date))
        let prior = sessions.filter { $0.hasWorkingSets && $0.evaluationDate >= lower && $0.evaluationDate < policy.start(of: date) }
        let totals = Dictionary(grouping: prior) { policy.key(for: $0.evaluationDate) }.values.map { group in
            group.reduce(0.0) { total, session in total + session.exercises.reduce(0) { $0 + stimulus(for: $1, quick: session.isQuickLog) } }
        }.sorted()
        input.expectedStimulus = totals.count >= 3 ? totals[totals.count / 2] : (training.profile.goal == .generalFitness ? 6 : 8)
        input.recentTrainingDays = Set(prior.filter { $0.evaluationDate >= policy.adding(days: -6, to: policy.start(of: date)) }.map { policy.key(for: $0.evaluationDate) }).count
        input.sleepHours = sleep.first { $0.dayKey == policy.key(for: date) }?.durationHours; input.sleepTarget = profile.sleepTargetHours
        let recovery = RecoveryEngine().evaluate(loads: canonicalLoads.filter { $0.date < policy.start(of: date) }, context: .init(sleepHours: input.sleepHours, sleepTarget: input.sleepTarget), now: date)
        input.recoveryLimited = ownerSystem.protectsTraining(on: date, policy: policy) || (input.sleepHours.map { $0 < 5 } ?? false) || (recovery.percent.map { $0 < 55 } ?? false)
        input.checkIn = ownerSystem.checkIns?.contains { policy.sameDay($0.date, date) } ?? false
        return input
    }
    var goalProjection: GoalProjection {
        ProjectionEngine().weight(samples: weights.map { .init(date: $0.measuredAt, kilograms: $0.kilograms) }, target: profile.targetWeightKG, now: now, policy: policy)
    }
    func score(for date: Date) -> ELOResult? {
        if policy.sameDay(date, now) { return projectedScore }
        return history.first { policy.sameDay($0.date, date) }.map { finalizedResult($0).elo }
    }
    var checkInToday: MorningCheckIn? { ownerSystem.checkIns?.last { policy.sameDay($0.date, now) } }
    @discardableResult func morningCheckIn(weight: Double?, hours: Double?, feeling: Int, soreness: Int) -> Bool {
        let date = actionDate()
        guard (1...5).contains(feeling), (0...5).contains(soreness), weight.map({ $0.isFinite && (20...400).contains($0) }) ?? true,
              hours.map({ $0.isFinite && (0.1...24).contains($0) }) ?? true else { errorMessage = "Check weight, sleep and feeling values."; return false }
        // Stage the sidecar, then commit database changes. Restore the original sidecar on failure.
        let old = ownerSystem
        guard saveOwnerSystem({ state in
            var entries = state.checkIns ?? []
            if let index = entries.lastIndex(where: { policy.sameDay($0.date, date) }) { entries[index] = .init(date: date, feeling: feeling, soreness: soreness) }
            else { entries.append(.init(date: date, feeling: feeling, soreness: soreness)) }
            state.checkIns = entries
        }) else { return false }
        let saved = perform {
            if let weight {
                context.insert(BodyWeightEntry(measuredAt: date, kilograms: weight))
                if profile.startingWeightKG == nil { profile.startingWeightKG = weight }
            }
            if let hours {
                if let existing = todaySleep {
                    if existing.bedtime != nil && existing.wakeTime != nil && abs(existing.durationHours - hours) > 0.05 { throw InputError.invalid("Sleep already has a recorded interval. Edit that interval in Sleep before changing its duration.") }
                    existing.durationHours = hours; existing.quality = feeling
                }
                else { context.insert(SleepEntry(dayKey: policy.key(for: date), date: policy.start(of: date), durationHours: hours, quality: feeling)) }
            }
        }
        if !saved { _ = saveOwnerSystem { $0 = old } }
        if saved { CoachNotifications.synchronize(store: self, requestPermission: false) }
        return saved
    }
    func setEffort(exerciseID: UUID, setID: UUID, rating: EffortRating?) {
        changeLiveExercise(exerciseID) { entry in
            if let index = entry.sets.firstIndex(where: { $0.id == setID }) { entry.sets[index].rpe = rating.map { Double($0.rawValue) } }
        }
    }
    func startExerciseClock(exerciseID: UUID, setID: UUID) {
        let date = actionDate()
        _ = updateWorkout { $0?.exerciseClock = .init(exerciseID: exerciseID, setID: setID, at: date) }
    }
    func pauseExerciseClock() {
        let date = actionDate()
        _ = updateWorkout { value in
            if value?.exerciseClock?.startedAt == nil { value?.exerciseClock?.resume(at: date) }
            else { value?.exerciseClock?.pause(at: date) }
        }
    }
    @discardableResult func finishExerciseClock() -> Bool {
        guard let clock = activeWorkout?.exerciseClock, let exercise = activeWorkout?.exercises.first(where: { $0.id == clock.exerciseID }),
              let set = exercise.sets.first(where: { $0.id == clock.setID }) else { return false }
        let elapsed = max(1, clock.elapsed(at: actionDate()))
        guard updateWorkout({ value in
            if let e = value?.exercises.firstIndex(where: { $0.id == exercise.id }), let s = value?.exercises[e].sets.firstIndex(where: { $0.id == set.id }) { value?.exercises[e].sets[s].seconds = elapsed }
            value?.exerciseClock = nil
        }) else { return false }
        return completeLiveSet(exerciseID: exercise.id, setID: set.id)
    }
    func acceptAutoregulation(_ advice: AutoregulationAdvice, exerciseID: UUID, lowerLoad: Bool) {
        let date = actionDate()
        _ = updateWorkout { draft in
            if draft?.rest.isActive == true { draft?.rest.add(seconds: advice.extraRest, at: date) }
            else if let exercise = draft?.exercises.first(where: { $0.id == exerciseID }) { draft?.rest.start(seconds: advice.extraRest, exerciseID: exercise.catalogID, at: date) }
            if lowerLoad, let kg = advice.kilograms, let e = draft?.exercises.firstIndex(where: { $0.id == exerciseID }) {
                for s in (draft?.exercises[e].sets.indices ?? 0..<0) where draft?.exercises[e].sets[s].completedAt == nil { draft?.exercises[e].sets[s].kilograms = kg }
            }
        }
    }
}
