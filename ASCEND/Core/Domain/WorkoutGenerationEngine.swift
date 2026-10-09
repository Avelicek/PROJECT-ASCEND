import Foundation

public struct WorkoutGenerationEngine: Sendable {
    public init() {}
    public func decide(_ context: PersonalContext, catalog: [TrainingExercise] = TrainingCatalog.definitions) -> BrainDecision {
        // Existing mode/confidence/progression logic remains the common safety gate.
        var generatedContext = context; generatedContext.training.routines = []
        let base = PersonalBrainEngine().decide(generatedContext, catalog: catalog)
        guard context.archive.settings.enabled, !context.sickMode, !context.sleepMode, !context.activeWorkout,
              base.action != .recover, context.daysSinceLastSession != 0 else { return base }
        let minutes = context.archive.settings.duration == .flexible ? context.training.profile.sessionMinutes : context.archive.settings.duration.rawValue
        let available = catalog.filter {
            TrainingSystem().missing($0, profile: context.training.profile).isEmpty && !context.training.hidden.contains($0.id) && $0.pattern != .locomotion
        }
        func today(_ exercise: TrainingExercise) -> Double {
            exercise.muscles.reduce(0) { $0 + context.todayMuscles[$1.muscle, default: 0] * $1.fraction }
        }
        func value(_ exercise: TrainingExercise) -> Double {
            let readiness = PersonalBrainEngine().readiness(exercise, context: context)
            if (readiness.minimum ?? 75) < 60 || today(exercise) >= 0.7 { return -1000 }
            let weekly = exercise.muscles.reduce(0) { $0 + context.weeklyMuscles[$1.muscle.group, default: 0] * $1.fraction }
            let familiar = context.history.contains { $0.exerciseID == exercise.id } ? 3.0 : 0
            let preferred = context.training.favorites.contains(exercise.id) ? 4.0 : 0
            let learned = context.archive.preferences.filter { $0.key == exercise.id && context.date.timeIntervalSince($0.date) < 42 * 86400 }.reduce(0) { $0 + $1.signal.weight }
            let compound: Set<MovementPattern> = [.horizontalPush, .horizontalPull, .verticalPull, .squat, .hinge, .lunge]
            let goal = context.training.profile.goal == .strength && compound.contains(exercise.pattern) ? 5.0 : 0
            return (readiness.minimum ?? 75) - min(30, weekly * 4) - today(exercise) * 30 + preferred + familiar + FitnessMath.clamp(learned, -6...6) + goal
        }
        let ordered = available.sorted { value($0) == value($1) ? $0.id < $1.id : value($0) > value($1) }
        var entries: [RoutineExercise] = [], patterns = Set<MovementPattern>(), families = Set<String>(), usedMinutes = 5
        let light = base.action == .trainLight || context.feeling.map { $0 <= 2 } == true || context.soreness.map { $0 >= 4 } == true
        for exercise in ordered where value(exercise) > -900 {
            guard !patterns.contains(exercise.pattern), !families.contains(exercise.family ?? exercise.id) else { continue }
            let load = today(exercise)
            let sets = light ? 2 : load >= 0.3 ? 1 : context.training.profile.goal == .generalFitness ? 2 : 3
            let recentRPE = context.history.filter { $0.exerciseID == exercise.id && $0.date <= context.date }.sorted { $0.date > $1.date }.first.flatMap { FitnessMath.average($0.working.compactMap(\.rpe)) }
            let rest = AdaptiveRestEngine().seconds(pattern: exercise.pattern, goal: context.training.profile.goal, rpe: recentRPE, fatigue: nil)
            let cost = 2 + sets * (45 + rest) / 60
            guard usedMinutes + cost <= minutes || entries.isEmpty else { continue }
            var item = RoutineExercise(exercise.id, sets: sets, restSeconds: rest)
            item.id = PersonalBrainEngine.stableID("generated:" + exercise.id)
            entries.append(item); usedMinutes += cost; patterns.insert(exercise.pattern); families.insert(exercise.family ?? exercise.id)
            if entries.count >= 5 { break }
        }
        var reasons = ["Generated from equipment, recovery estimates, recent performance and weekly stimulus; \(minutes)-minute budget."]
        let loaded = context.todayMuscles.filter { $0.value >= 0.25 }.map { $0.key.group }
        if !loaded.isEmpty { reasons.append("\(Set(loaded).sorted().joined(separator: ", ")) already received stimulus today. Overlapping work is reduced or removed.") }
        if let first = entries.first, let metadata = available.first(where: { $0.id == first.exerciseID }) {
            reasons.append("\(metadata.focus.title) has capacity within your recent weekly exposure. This is today's first priority.")
        }
        if light { reasons.append("Keep this session easy while the baseline or check-in indicates caution.") }
        let selected = entries.compactMap { item in available.first { $0.id == item.exerciseID } }
        let groups = Set(selected.map { $0.focus.title }).sorted()
        let focus = groups.count <= 2 ? groups.joined(separator: " + ") : "Balanced training"
        var session = entries.isEmpty ? nil : WorkoutRoutine(name: focus, exercises: entries)
        session?.id = PersonalBrainEngine.stableID(context.dayKey + entries.map(\.exerciseID).joined(separator: ":"))
        let opportunities = selected.compactMap { entry in context.progression.first { $0.exerciseID == entry.id } }
        return .init(id: context.dayKey + ":adaptive:" + entries.map { "\($0.exerciseID):\($0.sets)" }.joined(separator: ":"),
            action: session == nil ? .recover : light ? .trainLight : .train, focus: session == nil ? "Recovery" : focus,
            routineID: nil, session: session, duration: session == nil ? nil : usedMinutes, confidence: base.confidence,
            intensity: light ? .light : base.intensity, reasons: reasons + Array(base.reasons.prefix(1)), warnings: base.warnings,
            missing: base.missing, muscles: base.muscles, opportunities: opportunities)
    }
}
