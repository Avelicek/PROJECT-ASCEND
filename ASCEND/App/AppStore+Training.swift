import Foundation

extension AppStore {
    func trainingMetadata(_ id: String) -> TrainingExercise? { TrainingCatalog.definitions.first { $0.id == id } }
    func missingEquipment(_ id: String) -> Set<GymEquipment> {
        guard let entry = trainingMetadata(id) else { return [] }
        return TrainingSystem().missing(entry, profile: training.profile)
    }
    var recentExerciseIDs: [String] {
        var seen = Set<String>()
        return exerciseHistory.filter { $0.date <= now }.sorted { $0.date > $1.date }.compactMap { seen.insert($0.exerciseID).inserted ? $0.exerciseID : nil }
    }
    func library(_ query: ExerciseQuery) -> [Exercise] {
        let ids = TrainingSystem().filter(TrainingCatalog.definitions, state: training, query: query, recent: recentExerciseIDs).map(\.id)
        return ids.compactMap { id in exercises.first { $0.catalogID == id } }
    }
    @discardableResult func editTraining(_ change: (inout PersonalTrainingState) -> Void) -> Bool {
        var value = training; change(&value)
        guard value.version == 1, value.routines.count <= 100, value.routines.allSatisfy(\.isValid), (15...180).contains(value.profile.sessionMinutes) else {
            errorMessage = "Use a routine name, distinct exercises, 1–40 sets, positive reps and 15–900 seconds of rest."; return false
        }
        do { try trainingStorage?.write(value); training = value; deriveBrain(); return true }
        catch { errorMessage = "Training preferences could not be saved: \(error.localizedDescription)"; return false }
    }
    func toggleFavorite(_ id: String) { _ = editTraining { if !$0.favorites.insert(id).inserted { $0.favorites.remove(id) } } }
    func toggleHidden(_ id: String) { _ = editTraining { if !$0.hidden.insert(id).inserted { $0.hidden.remove(id) } } }
    @discardableResult func saveRoutine(_ routine: WorkoutRoutine) -> Bool {
        editTraining { state in
            if let index = state.routines.firstIndex(where: { $0.id == routine.id }) { state.routines[index] = routine }
            else { state.routines.append(routine) }
        }
    }
    func duplicateRoutine(_ routine: WorkoutRoutine) {
        var copy = routine; copy.id = UUID(); copy.name = String((routine.name + " copy").prefix(80))
        for index in copy.exercises.indices { copy.exercises[index].id = UUID() }
        _ = saveRoutine(copy)
    }
    @discardableResult func startRoutine(_ routine: WorkoutRoutine, generated: Bool = false) -> Bool {
        guard activeWorkout == nil else { errorMessage = "Resume or finish your saved workout before starting another routine."; return false }
        guard routine.isValid else { errorMessage = "Add a name and exercises to this routine."; return false }
        var draft = LiveWorkout(startedAt: actionDate(), title: routine.name); draft.routineID = generated ? nil : routine.id
        for item in routine.exercises {
            guard let catalog = exercises.first(where: { $0.catalogID == item.exerciseID }), missingEquipment(item.exerciseID).isEmpty else {
                errorMessage = "Replace unavailable exercises or update My Gym before starting."; return false
            }
            var entry = liveExercise(catalog)
            let baseline = entry.sets.first ?? LiveSet()
            entry.sets = (0..<item.sets).map { _ in var value = baseline; value.id = UUID(); if let reps = item.repTarget { value.reps = reps }; return value }
            if generated, let targets = ProgressionPlanEngine().targets(history: exerciseHistory, exercise: entry, count: item.sets, now: actionDate(), recoveryLimited: brainDecision.intensity == .light || brainDecision.intensity == .recoverySession) {
                for index in entry.sets.indices {
                    let target = targets[index]; entry.sets[index].reps = target.reps; entry.sets[index].kilograms = target.kilograms
                    entry.sets[index].seconds = target.seconds; entry.sets[index].distanceMeters = target.distanceMeters
                }
            }
            entry.restSeconds = item.restSeconds; draft.exercises.append(entry)
        }
        draft.selectedExerciseID = draft.exercises.first?.id
        guard updateWorkout({ $0 = draft }) else { return false }
        completedWorkout = nil; liveWorkoutPresented = true
        if !generated { recordPreference(routine.id.uuidString, .routineStarted) }
        return true
    }
    func liveExercise(_ exercise: Exercise) -> LiveExercise {
        var entry = LiveExercise(catalogID: exercise.catalogID, name: exercise.name, mode: exercise.trackingMode,
            bodyweight: exercise.bodyweightCapable, addedWeight: exercise.additionalWeightAllowed,
            weightStep: (trainingMetadata(exercise.catalogID)?.required.contains(.dumbbells) == true || exercise.equipmentRaw == Equipment.dumbbell.rawValue) ? 1 : 2.5, contributions: exercise.contributions)
        if let previous = ProgressionEngine().previous(exerciseHistory, exercise: entry, now: actionDate())?.working.first {
            entry.sets[0].reps = previous.performance.reps; entry.sets[0].kilograms = previous.performance.kilograms
            entry.sets[0].seconds = previous.performance.seconds; entry.sets[0].distanceMeters = previous.performance.distanceMeters
            if entry.bodyweight && previous.performance.kilograms > 0 { entry.usesAddedWeight = true }
        }
        return entry
    }
    @discardableResult func replaceLiveExercise(_ id: UUID, with exercise: Exercise) -> Bool {
        guard let old = activeWorkout?.exercises.first(where: { $0.id == id }), old.sets.allSatisfy({ $0.completedAt == nil }),
              missingEquipment(exercise.catalogID).isEmpty, activeWorkout?.exercises.contains(where: { $0.catalogID == exercise.catalogID }) == false else {
            errorMessage = "Only unfinished exercises can be replaced with an available, distinct exercise. Keep logged sets and add another exercise instead."; return false
        }
        var replacement = liveExercise(exercise); replacement.id = id; replacement.restSeconds = old.restSeconds
        let baseline = replacement.sets.first ?? LiveSet()
        replacement.sets = old.sets.map { _ in var row = baseline; row.id = UUID(); return row }
        let saved = updateWorkout { draft in
            guard let index = draft?.exercises.firstIndex(where: { $0.id == id }) else { return }
            draft?.exercises[index] = replacement; draft?.selectedExerciseID = id; draft?.rest.skip()
        }
        if saved { recordPreference(old.catalogID, .exerciseSkipped); recordPreference(exercise.catalogID, .substitutionAccepted) }
        return saved
    }
    var recommendedRoutine: TrainingRecommendation? {
        guard !ownerSystem.sickActive, ownerSystem.sleepStartedAt == nil else { return nil }
        return TrainingSystem().recommend(routines: training.routines, catalog: TrainingCatalog.definitions, state: training, recovery: readiness)
    }
    var nextTrainingRoutine: WorkoutRoutine? {
        if let recommendation = recommendedRoutine { return training.routines.first { $0.id == recommendation.routineID } }
        return training.routines.first { routine in routine.exercises.allSatisfy { trainingMetadata($0.exerciseID) != nil && missingEquipment($0.exerciseID).isEmpty && !training.hidden.contains($0.exerciseID) } }
    }
    var weeklyExposure: [(String, Double)] {
        let lower = policy.adding(days: -(policy.calendar.component(.weekday, from: now) + 5) % 7, to: policy.start(of: now))
        var totals: [String: Double] = [:]
        for session in sessions where session.hasWorkingSets && session.evaluationDate >= lower && session.evaluationDate <= now {
            for exercise in session.exercises {
                let count = stimulus(for: exercise, quick: session.isQuickLog)
                for contribution in exercise.contributions { totals[contribution.muscle.group, default: 0] += count * contribution.fraction }
            }
        }
        return ["Chest", "Back", "Shoulders", "Arms", "Legs", "Glutes", "Calves", "Core"].map { ($0, totals[$0, default: 0]) }
    }
    var weeklyMovementExposure: [(MovementPattern, Int)] {
        let weekday = (policy.calendar.component(.weekday, from: now) + 5) % 7
        let lower = policy.adding(days: -weekday, to: policy.start(of: now))
        var totals: [MovementPattern: Int] = [:]
        for session in sessions where session.hasWorkingSets && session.evaluationDate >= lower && session.evaluationDate <= now {
            for exercise in session.exercises {
                if let id = exercise.exercise?.catalogID, let metadata = trainingMetadata(id) { totals[metadata.pattern, default: 0] += exercise.sets.filter { !$0.isWarmup }.count }
            }
        }
        return MovementPattern.allCases.map { ($0, totals[$0, default: 0]) }
    }
}
