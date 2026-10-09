import Foundation
import SwiftData

struct ProfileDraft {
    var name: String
    var currentWeight: Double?
    var targetWeight: Double?
    var deadline: Date?
    var weeklyChange: Double
    var calories: Double
    var protein: Double
    var sleepHours: Double
    var aiEnabled: Bool
    var haptics: Bool
    @MainActor init(store: AppStore) {
        name = store.profile.displayName; currentWeight = store.progress.actualWeight
        targetWeight = store.profile.targetWeightKG; deadline = store.profile.targetDeadline
        weeklyChange = store.profile.desiredWeeklyChangeKG; calories = store.profile.calorieGoal
        protein = store.profile.proteinGoal; sleepHours = store.profile.sleepTargetHours
        aiEnabled = store.settings.onDeviceAIEnabled; haptics = store.settings.hapticsEnabled
    }
}
struct ObjectiveDraft {
    var title = ""
    var kind: ObjectiveKind = .custom
    var cadence: ObjectiveCadence = .daily
    var importance: ObjectiveImportance = .standard
    var target: Double = 1
    var unit = "times"
    var startsAt = Date.now
    var weekdays: [Int] = [2, 4, 6]
    var exerciseCatalogID: String?
}

extension AppStore {
    func saveProfile(_ draft: ProfileDraft) -> Bool {
        perform {
            guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw InputError.invalid("Enter a name.") }
            if let weight = draft.currentWeight { try validateWeight(weight) }
            if let target = draft.targetWeight { try validateWeight(target) }
            guard draft.calories.isFinite, (500...10000).contains(draft.calories), draft.protein.isFinite,
                  (10...600).contains(draft.protein), draft.sleepHours.isFinite, (1...16).contains(draft.sleepHours),
                  draft.weeklyChange.isFinite, (0.01...2).contains(abs(draft.weeklyChange)) else {
                throw InputError.invalid("Check calorie, protein, sleep and pace goals.")
            }
            if let deadline = draft.deadline, deadline < policy.start(of: now) { throw InputError.invalid("Choose a future target deadline.") }
            if let weight = draft.currentWeight, abs(weight - (progress.actualWeight ?? 0)) > 0.001 {
                context.insert(BodyWeightEntry(measuredAt: now, kilograms: weight))
                if profile.startingWeightKG == nil { profile.startingWeightKG = weight }
            }
            if profile.targetWeightKG != draft.targetWeight {
                profile.startingWeightKG = draft.currentWeight ?? progress.actualWeight
            }
            profile.displayName = String(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
            profile.targetWeightKG = draft.targetWeight; profile.targetDeadline = draft.deadline
            profile.desiredWeeklyChangeKG = abs(draft.weeklyChange)
            profile.calorieGoal = draft.calories; profile.proteinGoal = draft.protein; profile.sleepTargetHours = draft.sleepHours
            if let entry = todayNutrition { entry.calorieGoal = draft.calories; entry.proteinGoal = draft.protein }
            settings.onDeviceAIEnabled = draft.aiEnabled; settings.hapticsEnabled = draft.haptics
        }
    }
    func logWeight(_ kilograms: Double, at date: Date) -> Bool {
        perform {
            try validateWeight(kilograms); try validateDate(date)
            context.insert(BodyWeightEntry(measuredAt: date, kilograms: kilograms))
            if profile.startingWeightKG == nil { profile.startingWeightKG = kilograms }
        }
    }
    private func validateWeight(_ value: Double) throws {
        guard value.isFinite, (20...400).contains(value) else { throw InputError.invalid("Enter a weight between 20 and 400 kg.") }
    }
    private func validateDate(_ date: Date) throws {
        guard date <= now else { throw InputError.invalid("Logs cannot be in the future.") }
    }
    func logNutrition(calories: Double, protein: Double, on date: Date) -> Bool {
        perform {
            try validateDate(date)
            guard calories.isFinite, protein.isFinite, (0...20000).contains(calories), (0...1000).contains(protein) else {
                throw InputError.invalid("Enter valid calorie and protein totals.")
            }
            let key = policy.key(for: date)
            if let entry = nutrition.first(where: { $0.dayKey == key }) { entry.calories = calories; entry.proteinGrams = protein }
            else { context.insert(NutritionEntry(dayKey: key, date: policy.start(of: date), calories: calories,
                proteinGrams: protein, calorieGoal: profile.calorieGoal, proteinGoal: profile.proteinGoal)) }
        }
    }
    func logSleep(hours: Double, quality: Int, on date: Date, bedtime: Date?, wakeTime: Date?) -> Bool {
        perform {
            try validateDate(date)
            guard hours.isFinite, (0.1...24).contains(hours), (1...5).contains(quality) else { throw InputError.invalid("Check sleep duration and quality.") }
            if let bedtime, let wakeTime, bedtime >= wakeTime { throw InputError.invalid("Wake time must follow bedtime.") }
            if let wakeTime, wakeTime > now { throw InputError.invalid("Wake time cannot be in the future.") }
            if let wakeTime, !policy.sameDay(wakeTime, date) { throw InputError.invalid("The log day must match the day of waking.") }
            let resolvedHours: Double
            if let bedtime, let wakeTime {
                resolvedHours = wakeTime.timeIntervalSince(bedtime) / 3600
                guard (0.1...24).contains(resolvedHours) else { throw InputError.invalid("Bed and wake times must describe at most one day of sleep.") }
            } else { resolvedHours = hours }
            let key = policy.key(for: date)
            if let entry = sleep.first(where: { $0.dayKey == key }) {
                entry.durationHours = resolvedHours; entry.quality = quality; entry.bedtime = bedtime; entry.wakeTime = wakeTime
            } else { context.insert(SleepEntry(dayKey: key, date: policy.start(of: date), durationHours: resolvedHours,
                quality: quality, bedtime: bedtime, wakeTime: wakeTime)) }
        }
    }
    func toggleObjective(_ occurrence: DailyObjectiveCompletion) -> Bool {
        perform {
            guard occurrence.dayKey == policy.key(for: now) else { throw InputError.invalid("This objective's day has closed. Use today's occurrence.") }
            guard occurrence.kindRaw == ObjectiveKind.custom.rawValue, !occurrence.recoveryExempt else { return }
            occurrence.value = occurrence.completedAt == nil ? occurrence.target : 0
        }
    }
    func saveObjective(_ draft: ObjectiveDraft, editing existing: DailyObjective? = nil) -> Bool {
        perform {
            let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, title.count <= 80, draft.target.isFinite, draft.target > 0, draft.target <= 20000,
                  draft.cadence != .weekdays || !draft.weekdays.isEmpty else { throw InputError.invalid("Enter a title, positive target and valid schedule.") }
            if draft.kind == .exercise, draft.exerciseCatalogID == nil { throw InputError.invalid("Select an exercise.") }
            if let existing {
                existing.title = title; existing.kindRaw = draft.kind.rawValue; existing.cadenceRaw = draft.cadence.rawValue
                existing.importanceRaw = draft.importance.rawValue; existing.target = draft.target; existing.unit = draft.unit
                existing.startsAt = draft.startsAt; existing.weekdays = draft.weekdays; existing.exerciseCatalogID = draft.exerciseCatalogID
                // Today's occurrence is editable; closed days retain their original target and importance.
                if let occurrence = todayObjectives.first(where: { $0.objective?.id == existing.id }) {
                    occurrence.title = title; occurrence.kindRaw = draft.kind.rawValue; occurrence.importanceRaw = draft.importance.rawValue
                    occurrence.target = draft.target; occurrence.unit = draft.unit
                    // Preserve the already-materialized day even when the future schedule changes.
                }
            } else {
                context.insert(DailyObjective(title: title, kind: draft.kind, cadence: draft.cadence, importance: draft.importance,
                    target: draft.target, unit: draft.unit, startsAt: draft.startsAt, weekdays: draft.weekdays,
                    exerciseCatalogID: draft.exerciseCatalogID))
            }
        }
    }
    func archiveObjective(_ objective: DailyObjective) -> Bool {
        perform {
            objective.isActive = false
            // Archiving changes future scheduling; today remains an intact snapshot.
        }
    }
    func chooseRecoveryAlternative(_ occurrence: DailyObjectiveCompletion) -> Bool {
        perform {
            guard occurrence.dayKey == policy.key(for: now) else { throw InputError.invalid("Recovery alternatives apply to today's objectives.") }
            occurrence.recoveryExempt = true; occurrence.replacementTitle = "Recovery day · gentle movement"
            occurrence.completedAt = nil
        }
    }
    func logWorkout(exercise: Exercise, sets: [SetPerformance], at date: Date, quick: Bool, exertion: Double, measurement: ActivityMeasurement? = nil) -> Bool {
        perform {
            try validateDate(date)
            guard !sets.isEmpty, sets.count <= 30, (1...10).contains(exertion), sets.allSatisfy({ set in
                set.kilograms.isFinite && set.seconds.isFinite && set.distanceMeters.isFinite &&
                (0...1000).contains(set.kilograms) && (0...2000).contains(set.reps) && (0...86400).contains(set.seconds) &&
                (0...500000).contains(set.distanceMeters) &&
                (exercise.trackingMode == .duration ? set.seconds > 0 : exercise.trackingMode == .distance ? set.distanceMeters > 0 && set.seconds > 0 : set.reps > 0)
            }) else { throw InputError.invalid("Check each set's values and effort.") }
            let session = WorkoutSession(startedAt: date, title: exercise.name, isQuickLog: quick)
            session.completedAt = date
            if let measurement { session.notes = try measurement.encodedNote() }
            let loggedExercise = WorkoutExercise(exercise: exercise, order: 0)
            session.exercises.append(loggedExercise); loggedExercise.session = session
            for (index, performance) in sets.enumerated() {
                let set = WorkoutSet(order: index, performance: performance, completedAt: date, perceivedExertion: exertion)
                loggedExercise.sets.append(set); set.workoutExercise = loggedExercise
            }
            context.insert(session)
            if !quick {
                let liveSets = sets.map { performance -> LiveSet in
                    var set = LiveSet(); set.reps = performance.reps; set.kilograms = performance.kilograms
                    set.seconds = performance.seconds; set.distanceMeters = performance.distanceMeters
                    set.rpe = exertion; set.completedAt = date; return set
                }
                let live = LiveExercise(catalogID: exercise.catalogID, name: exercise.name, mode: exercise.trackingMode,
                    bodyweight: exercise.bodyweightCapable, addedWeight: exercise.additionalWeightAllowed,
                    contributions: exercise.contributions, sets: liveSets)
                for improvement in PersonalRecordEngine().detect(exercise: live, history: exerciseHistory, at: date) {
                    let record = PersonalRecord(exerciseCatalogID: exercise.catalogID, kind: improvement.kind,
                        value: improvement.value, achievedAt: date, sessionID: session.id)
                    record.kindRaw = improvement.storageKey; context.insert(record)
                }
            }
        }
    }
}
