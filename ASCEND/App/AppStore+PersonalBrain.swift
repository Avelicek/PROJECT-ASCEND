import Foundation

extension AppStore {
    // Event-driven cache. Recovery age advances on foreground refresh, with a one-minute
    // presentation tolerance; this never schedules a timer or requests model inference.
    private func currentBrainInputKey() -> Int {
        var hash = Hasher()
        hash.combine((now.timeIntervalSince1970 / 60).rounded(.down))
        hash.combine(policy.key(for: now)); hash.combine(currentELO); hash.combine(activeWorkout?.id)
        hash.combine(profile.startingWeightKG); hash.combine(profile.desiredWeeklyChangeKG); hash.combine(profile.targetDeadline); hash.combine(profile.targetWeightKG); hash.combine(profile.calorieGoal); hash.combine(profile.proteinGoal); hash.combine(profile.sleepTargetHours)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        // JSONEncoder's Set order is not stable. Encode sorted set values separately.
        var profile = training.profile
        let equipment = profile.equipment.map(\.rawValue).sorted(); profile.equipment = []
        hash.combine(try? encoder.encode(profile)); hash.combine(equipment)
        hash.combine(try? encoder.encode(training.routines)); hash.combine(training.favorites.sorted()); hash.combine(training.hidden.sorted())
        hash.combine(try? encoder.encode(brainArchive.settings)); hash.combine(try? encoder.encode(brainArchive.preferences))
        hash.combine(ownerSystem.sickActive); hash.combine(ownerSystem.sleepStartedAt); hash.combine(try? encoder.encode(ownerSystem.checkIns))
        for entry in weights { hash.combine(entry.id); hash.combine(entry.measuredAt); hash.combine(entry.kilograms) }
        for entry in nutrition { hash.combine(entry.dayKey); hash.combine(entry.date); hash.combine(entry.calories); hash.combine(entry.proteinGrams); hash.combine(entry.calorieGoal); hash.combine(entry.proteinGoal) }
        for entry in sleep { hash.combine(entry.dayKey); hash.combine(entry.date); hash.combine(entry.durationHours); hash.combine(entry.quality) }
        for session in sessions {
            hash.combine(session.id); hash.combine(session.startedAt); hash.combine(session.completedAt); hash.combine(session.isQuickLog)
            for exercise in session.exercises.sorted(by: { $0.order < $1.order }) {
                hash.combine(exercise.id); hash.combine(exercise.exercise?.catalogID); hash.combine(exercise.trackingModeRaw); hash.combine(exercise.contributionData)
                for set in exercise.sets.sorted(by: { $0.order < $1.order }) { hash.combine(set.id); hash.combine(set.reps); hash.combine(set.weightKG); hash.combine(set.durationSeconds); hash.combine(set.distanceMeters); hash.combine(set.perceivedExertion); hash.combine(set.isWarmup); hash.combine(set.completedAt) }
            }
        }
        for exercise in exercises { hash.combine(exercise.catalogID); hash.combine(exercise.contributionData); hash.combine(exercise.trackingModeRaw) }
        return hash.finalize()
    }
    func deriveBrain() {
        let key = currentBrainInputKey()
        guard key != brainInputKey else { return }
        brainInputKey = key
        var value = PersonalContext(date: now)
        value.sickMode = ownerSystem.sickActive; value.sleepMode = ownerSystem.sleepStartedAt != nil; value.activeWorkout = activeWorkout != nil
        value.dayKey = policy.key(for: now); value.currentELO = currentELO; value.rank = rank.rank.title
        value.weight = progress.actualWeight; value.targetWeight = profile.targetWeightKG; value.weightMomentum = progress.momentumPercent
        let recentSleep = sleep.last { $0.date <= now && $0.date >= policy.adding(days: -1, to: policy.start(of: now)) }
        value.sleepHours = recentSleep?.durationHours; value.sleepQuality = recentSleep?.quality; value.sleepTarget = profile.sleepTargetHours
        value.sleepConfidence = recentSleep == nil ? .low : .medium
        value.calories = todayNutrition?.calories; value.calorieGoal = profile.calorieGoal
        value.protein = todayNutrition?.proteinGrams; value.proteinGoal = profile.proteinGoal
        // Closed days avoid treating an unfinished morning's intake as a daily failure.
        let recentFuel = nutrition.filter { $0.date < policy.start(of: now) && $0.date >= policy.adding(days: -3, to: policy.start(of: now)) }
        value.nutritionDays = recentFuel.count
        value.calorieAdherence = FitnessMath.average(recentFuel.map { $0.calories / max(1, $0.calorieGoal) })
        value.proteinAdherence = FitnessMath.average(recentFuel.map { $0.proteinGrams / max(1, $0.proteinGoal) })
        value.history = exerciseHistory
        value.sessionDates = sessions.filter { $0.completedAt != nil && $0.hasWorkingSets && !$0.isQuickLog && $0.evaluationDate <= now }.map(\.evaluationDate)
        let recentDates = value.sessionDates.filter { $0 >= policy.adding(days: -6, to: policy.start(of: now)) }
        value.trainingDays = Set(recentDates.map { policy.key(for: $0) }).count
        value.daysSinceLastSession = value.sessionDates.max().map { policy.calendar.dateComponents([.day], from: policy.start(of: $0), to: policy.start(of: now)).day ?? 0 }
        value.recovery = readiness
        // Disabling a support input also removes its indirect influence on the recovery estimate used by Brain.
        if !brainArchive.settings.useSleep || !brainArchive.settings.useNutrition {
            let loads = canonicalLoads
            value.recovery = RecoveryEngine().evaluate(loads: loads, context: .init(
                sleepHours: brainArchive.settings.useSleep ? value.sleepHours : nil,
                sleepQuality: brainArchive.settings.useSleep ? value.sleepQuality : nil, sleepTarget: profile.sleepTargetHours,
                calorieAdherence: brainArchive.settings.useNutrition ? value.calorieAdherence : nil,
                proteinAdherence: brainArchive.settings.useNutrition ? value.proteinAdherence : nil,
                tolerance: personalModel.recoveryTolerance, historyDays: 0, trainingSessions: value.sessionDates.count), now: now)
        }
        value.weeklyMuscles = Dictionary(uniqueKeysWithValues: weeklyExposure)
        value.weeklyMovements = Dictionary(uniqueKeysWithValues: weeklyMovementExposure)
        for load in canonicalLoads where policy.sameDay(load.date, now) {
            for (muscle, amount) in TrainingLoadEngine().muscles(stimulus: load.challengingSets, contributions: load.contributions) { value.todayMuscles[muscle, default: 0] += amount }
        }
        value.feeling = checkInToday?.feeling; value.soreness = checkInToday?.soreness
        value.training = training; value.archive = brainArchive
        value.progression = PersonalBrainEngine().progressionFacts(value)
        personalContext = value; brainDecision = WorkoutGenerationEngine().decide(value)
        if brainArchive.settings.enabled {
            var archive = brainArchive; archive.record(brainDecision, date: now)
            if archive.history.count != brainArchive.history.count || archive.history.last?.id != brainArchive.history.last?.id {
                _ = saveBrainArchive(archive)
            }
        }
    }
    @discardableResult func saveBrainArchive(_ value: BrainArchive) -> Bool {
        guard !brainStorageUnavailable else { return false }
        do { try brainStorage?.write(value); brainArchive = value; return true }
        catch { errorMessage = "Brain preferences could not be saved: \(error.localizedDescription)"; return false }
    }
    func editBrainSettings(_ change: (inout BrainSettings) -> Void) {
        var archive = brainArchive; change(&archive.settings)
        if saveBrainArchive(archive) { refreshSafely() }
    }
    func respondToBrain(_ signal: PreferenceSignal, id: String? = nil) {
        var archive = brainArchive; archive.respond(id: id ?? brainDecision.id, signal: signal, date: actionDate())
        if saveBrainArchive(archive) { deriveBrain() }
    }
    func recordPreference(_ key: String, _ signal: PreferenceSignal) {
        guard brainArchive.settings.enabled else { return }
        var archive = brainArchive
        archive.preferences.append(.init(date: actionDate(), key: key, signal: signal))
        archive.preferences = Array(archive.preferences.suffix(300))
        if saveBrainArchive(archive) { deriveBrain() }
    }
    func startBrainSession() {
        guard activeWorkout == nil else { startLiveWorkout(); return }
        let decision = brainDecision
        guard brainArchive.settings.enabled, let session = decision.session else { return }
        if startRoutine(session, generated: decision.routineID == nil) { respondToBrain(.accepted, id: decision.id) }
    }
    func brainHint(_ exercise: LiveExercise) -> String? {
        guard brainArchive.settings.enabled, let entry = brainDecision.opportunities.first(where: { $0.exerciseID == exercise.catalogID }) else { return nil }
        if let target = entry.suggestion.target {
            return "\(entry.recordWindow ? "OPTIONAL PR WINDOW" : "OPTIONAL TARGET") · \(target.kilograms > 0 ? target.kilograms.formatted() + " kg × " : "")\(target.reps) reps"
        }
        return "\(brainDecision.intensity.title.uppercased()) · \(entry.suggestion.explanation)"
    }
    func brainRecoveryWarning(_ exercise: LiveExercise) -> String? {
        guard brainArchive.settings.enabled, let metadata = trainingMetadata(exercise.catalogID),
              let minimum = PersonalBrainEngine().readiness(metadata, context: personalContext).minimum, minimum < 55 else { return nil }
        return "Recorded muscle recovery is limited (\(Int(minimum.rounded()))% minimum estimate). Consider skipping this movement or replacing it with a recovered focus."
    }
    func brainDayRead(_ result: DailyResult, date: Date) -> [String] {
        let food = nutrition.first { policy.sameDay($0.date, date) }
        let completed = sessions.filter { $0.completedAt != nil && $0.hasWorkingSets && policy.sameDay($0.evaluationDate, date) }
        var load: [String: Double] = [:]
        for session in completed { for entry in session.exercises { for part in entry.contributions {
            load[part.muscle.group, default: 0] += Double(entry.sets.filter { !$0.isWarmup }.count) * part.fraction
        } } }
        let muscle = load.keys.sorted().max { load[$0, default: 0] < load[$1, default: 0] }
        return PersonalBrainEngine().dayRead(result, calories: food?.calories, protein: food?.proteinGrams,
            calorieGoal: food?.calorieGoal, proteinGoal: food?.proteinGoal, trained: !completed.isEmpty, loadedMuscle: muscle)
    }
}
