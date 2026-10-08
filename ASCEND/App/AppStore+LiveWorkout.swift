import Foundation
import SwiftData

extension AppStore {
    var exerciseHistory: [ExerciseHistory] {
        sessions.filter { $0.completedAt != nil }.flatMap { session in
            session.exercises.compactMap { entry -> ExerciseHistory? in
                guard let id = entry.exercise?.catalogID else { return nil }
                return ExerciseHistory(sessionID: session.id, exerciseID: id, date: session.evaluationDate, mode: entry.trackingMode, quick: session.isQuickLog,
                    sets: entry.sets.sorted { $0.order < $1.order }.map { .init($0.performance, rpe: $0.perceivedExertion, warmup: $0.isWarmup) })
            }
        }
    }
    func startLiveWorkout() {
        completedWorkout = nil
        if activeWorkout == nil { _ = updateWorkout { $0 = LiveWorkout(startedAt: actionDate()) } }
        if activeWorkout != nil { liveWorkoutPresented = true }
    }
    @discardableResult func updateWorkout(_ change: (inout LiveWorkout?) -> Void) -> Bool {
        let hadWorkout = activeWorkout != nil
        let previousDeadline = activeWorkout?.rest.deadline
        let previousExercise = activeWorkout?.rest.exerciseID
        var value = activeWorkout
        change(&value)
        do { try workoutStorage?.write(value); activeWorkout = value
            if value?.rest.deadline != previousDeadline || value?.rest.exerciseID != previousExercise {
                RestNotifications.synchronize(value?.rest, enabled: !isDemo && !AppMotion.snapshotMode && !container.configurations.allSatisfy(\.isStoredInMemoryOnly))
                RestLiveActivity.synchronize(value, enabled: !isDemo && !AppMotion.snapshotMode && !container.configurations.allSatisfy(\.isStoredInMemoryOnly))
            }
            if hadWorkout != (value != nil) { deriveBrain() }
            return true }
        catch { errorMessage = "Workout progress could not be saved: \(error.localizedDescription)"; return false }
    }
    func changeLiveExercise(_ id: UUID, _ change: (inout LiveExercise) -> Void) {
        _ = updateWorkout { value in
            guard let index = value?.exercises.firstIndex(where: { $0.id == id }) else { return }
            change(&value!.exercises[index])
        }
    }
    func addLiveExercise(_ exercise: Exercise) {
        guard let activeWorkout, missingEquipment(exercise.catalogID).isEmpty, activeWorkout.exercises.count < 40,
              !activeWorkout.exercises.contains(where: { $0.catalogID == exercise.catalogID }) else { return }
        let entry = liveExercise(exercise)
        if updateWorkout({ $0?.exercises.append(entry) }) { recordPreference(exercise.catalogID, .exerciseChosen) }
    }
    func addLiveSet(exerciseID: UUID) {
        changeLiveExercise(exerciseID) { exercise in
            guard exercise.sets.count < 40 else { return }
            var set = exercise.sets.last ?? LiveSet()
            set.id = UUID(); set.completedAt = nil; set.isWarmup = false
            exercise.sets.append(set)
        }
    }
    func completeLiveSet(exerciseID: UUID, setID: UUID) -> Bool {
        guard let exercise = activeWorkout?.exercises.first(where: { $0.id == exerciseID }),
              let set = exercise.sets.first(where: { $0.id == setID }), set.completedAt == nil else { return false }
        guard set.isValid(for: exercise.mode, allowsWeight: exercise.allowsWeight, bodyweight: exercise.bodyweight) else {
            errorMessage = "Check reps, load, duration, distance and optional RPE before completing this set."; return false
        }
        let oldRecords = pendingRecords.map(\.id)
        let saved = updateWorkout { value in
            guard let e = value?.exercises.firstIndex(where: { $0.id == exerciseID }),
                  let s = value?.exercises[e].sets.firstIndex(where: { $0.id == setID }) else { return }
            value?.exercises[e].sets[s].completedAt = actionDate()
            if !set.isWarmup && settings.automaticRestTimer {
                value?.rest.start(seconds: preferredRest(for: exercise.catalogID), exerciseID: exercise.catalogID, at: .now)
            }
        }
        if saved {
            let newPR = pendingRecords.contains { !oldRecords.contains($0.id) }
            AppHaptics.reward(enabled: settings.hapticsEnabled && newPR)
            if !newPR { AppHaptics.tap(enabled: settings.hapticsEnabled) }
        }
        return saved
    }
    var pendingRecords: [RecordImprovement] {
        guard let activeWorkout else { return [] }
        return activeWorkout.exercises.flatMap { PersonalRecordEngine().detect(exercise: $0, history: exerciseHistory, at: activeWorkout.startedAt) }
    }
    func preferredRest(for exerciseID: String) -> Int {
        if let routineRest = activeWorkout?.exercises.first(where: { $0.catalogID == exerciseID })?.restSeconds { return routineRest }
        return ownerSystem.exerciseRest[exerciseID] ?? (localPreferences?.dictionary(forKey: "exercise-rest-v1")?[exerciseID] as? Int) ?? settings.restTimerSeconds
    }
    func setPreferredRest(_ seconds: Int, for exerciseID: String) {
        let duration = min(900, max(15, seconds))
        if let id = activeWorkout?.exercises.first(where: { $0.catalogID == exerciseID })?.id { changeLiveExercise(id) { $0.restSeconds = duration } }
        _ = saveOwnerSystem { $0.exerciseRest[exerciseID] = duration }
        if let localPreferences {
            var values = localPreferences.dictionary(forKey: "exercise-rest-v1") ?? [:]
            values[exerciseID] = duration; localPreferences.set(values, forKey: "exercise-rest-v1")
        }
        settings.restTimerSeconds = duration
        do { try context.save() } catch { context.rollback(); errorMessage = error.localizedDescription }
    }
    func tickRest(at date: Date) {
        guard var rest = activeWorkout?.rest, rest.consumeCompletion(at: date) else { return }
        if updateWorkout({ $0?.rest = rest }) { AppHaptics.success(enabled: settings.hapticsEnabled) }
    }
    func discardLiveWorkout() {
        if updateWorkout({ $0 = nil }) { completedWorkout = nil; liveWorkoutPresented = false }
    }
    @discardableResult func finishLiveWorkout() -> Bool {
        guard let draft = activeWorkout, draft.completedSets > 0 else { errorMessage = "Complete at least one set before finishing."; return false }
        let history = exerciseHistory.filter { $0.sessionID != draft.id }
        var summary = WorkoutSummaryEngine().summarize(draft, history: history, finishedAt: actionDate())
        let before = ELOEngine().evaluate(evaluationInput(for: actionDate(), includeMisses: false), previousELO: currentELO).delta
        let saved = perform {
            if sessions.contains(where: { $0.id == draft.id }) { return }
            let session = WorkoutSession(startedAt: draft.startedAt, title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Live training" : String(draft.title.prefix(80)), isQuickLog: false)
            session.id = draft.id; session.completedAt = now
            for (index, live) in draft.exercises.enumerated() {
                guard let exercise = exercises.first(where: { $0.catalogID == live.catalogID }), live.sets.contains(where: { $0.completedAt != nil }) else { continue }
                let entry = WorkoutExercise(exercise: exercise, order: index)
                session.exercises.append(entry); entry.session = session
                for (order, liveSet) in live.sets.filter({ $0.completedAt != nil }).enumerated() {
                    guard liveSet.isValid(for: live.mode, allowsWeight: live.allowsWeight, bodyweight: live.bodyweight) else { throw InputError.invalid("A completed set contains invalid values.") }
                    let set = WorkoutSet(order: order, performance: liveSet.performance(for: live.mode), completedAt: liveSet.completedAt ?? now, perceivedExertion: liveSet.rpe)
                    set.isWarmup = liveSet.isWarmup; entry.sets.append(set); set.workoutExercise = entry
                }
            }
            context.insert(session)
            for pr in summary.records {
                let record = PersonalRecord(exerciseCatalogID: pr.exerciseID, kind: pr.kind, value: pr.value, achievedAt: now, sessionID: session.id)
                record.kindRaw = pr.storageKey; context.insert(record)
            }
        }
        guard saved else { return false }
        summary.pendingELO = projectedScore.delta - before
        completedWorkout = summary
        _ = updateWorkout { $0 = nil }
        AppHaptics.success(enabled: settings.hapticsEnabled)
        return true
    }
}
