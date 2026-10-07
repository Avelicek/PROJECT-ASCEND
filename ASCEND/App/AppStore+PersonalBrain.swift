import Foundation

extension AppStore {
    func deriveBrain() {
        var value = PersonalContext(date: now)
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
            let loads = sessions.filter { $0.completedAt != nil }.flatMap { session in session.exercises.map { entry in
                let sets = entry.sets.filter { !$0.isWarmup }
                return TrainingLoad(date: session.evaluationDate, contributions: entry.contributions,
                    challengingSets: WorkoutEngine().load(sets: sets.map(\.performance), mode: entry.trackingMode, quick: session.isQuickLog),
                    intensity: (FitnessMath.average(sets.compactMap(\.perceivedExertion)) ?? 7) / 8)
            } }
            value.recovery = RecoveryEngine().evaluate(loads: loads, context: .init(
                sleepHours: brainArchive.settings.useSleep ? value.sleepHours : nil,
                sleepQuality: brainArchive.settings.useSleep ? value.sleepQuality : nil, sleepTarget: profile.sleepTargetHours,
                calorieAdherence: brainArchive.settings.useNutrition ? value.calorieAdherence : nil,
                proteinAdherence: brainArchive.settings.useNutrition ? value.proteinAdherence : nil,
                tolerance: personalModel.recoveryTolerance, historyDays: 0, trainingSessions: value.sessionDates.count), now: now)
        }
        value.weeklyMuscles = Dictionary(uniqueKeysWithValues: weeklyExposure)
        value.weeklyMovements = Dictionary(uniqueKeysWithValues: weeklyMovementExposure)
        value.training = training; value.archive = brainArchive
        value.progression = PersonalBrainEngine().progressionFacts(value)
        personalContext = value; brainDecision = PersonalBrainEngine().decide(value)
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
