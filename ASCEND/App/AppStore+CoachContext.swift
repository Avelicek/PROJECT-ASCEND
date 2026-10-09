import Foundation

extension AppStore {
    var coachContext: CoachContext {
        var today: [String: Double] = [:], recovery: [String: Double] = [:]
        for load in canonicalLoads where policy.sameDay(load.date, now) {
            for (muscle, amount) in TrainingLoadEngine().muscles(stimulus: load.challengingSets, contributions: load.contributions) { today[muscle.group, default: 0] += amount }
        }
        for muscle in readiness.muscles where muscle.lastTrainedAt != nil { recovery[muscle.muscle.group] = min(recovery[muscle.muscle.group] ?? 100, muscle.recoveryPercent) }
        let facts = personalContext.progression.compactMap { opportunity -> CoachExerciseFact? in
            guard let entry = exerciseHistory.filter({ $0.exerciseID == opportunity.exerciseID && !$0.quick && $0.date <= now }).max(by: { $0.date < $1.date }), let first = entry.working.first else { return nil }
            return .init(id: entry.exerciseID, name: opportunity.name, date: entry.date, kilograms: first.performance.kilograms,
                reps: entry.working.map { $0.performance.reps }, rpe: entry.working.compactMap(\.rpe), recommendation: opportunity.suggestion.explanation)
        }
        let projection = goalProjection
        var context = CoachContext(date: now, dailyELO: projectedScore.delta, components: projectedScore.components, checkInCompleted: checkInToday != nil,
            activeWorkout: activeWorkout != nil, sickMode: ownerSystem.sickActive, sleepMode: ownerSystem.sleepStartedAt != nil,
            readiness: readiness.percent, recoveryConfidence: readiness.confidence, sleepHours: personalContext.sleepHours,
            calories: todayNutrition?.calories, calorieGoal: profile.calorieGoal, protein: todayNutrition?.proteinGrams, proteinGoal: profile.proteinGoal,
            weight: progress.actualWeight, targetWeight: profile.targetWeightKG, projectionWeeks: projection.weeks.map { [$0.lowerBound, $0.upperBound] },
            projectionConfidence: projection.confidence, projectionEarliest: projection.earliest, projectionLatest: projection.latest, targetDeadline: profile.targetDeadline, timeZoneIdentifier: policy.timeZoneIdentifier, projectionReason: projection.explanation, workoutTitle: brainDecision.session?.name,
            workoutReasons: brainDecision.reasons + brainDecision.warnings, muscleLoad: today, muscleRecovery: recovery, exercises: facts,
            completedObjectives: todayObjectives.filter { $0.completedAt != nil }.count, dueObjectives: todayObjectives.count)
        context.projectionEstimateWeeks = projection.estimatedWeeks; context.projectionEstimateDate = projection.estimatedDate
        return context
    }
    func coachContext(for question: String) -> CoachContext {
        var result = coachContext
        let q = question.lowercased()
        guard !["bench", "press", "load"].contains(where: { q.contains($0) }),
              let range = q.range(of: #"[0-9]+(?:[.,][0-9]+)?\s*kg"#, options: .regularExpression),
              let target = Double(q[range].filter { $0.isNumber || $0 == "." || $0 == "," }.replacingOccurrences(of: ",", with: ".")),
              (20...400).contains(target) else { return result }
        let projection = ProjectionEngine().weight(samples: weights.map { .init(date: $0.measuredAt, kilograms: $0.kilograms) }, target: target, now: now, policy: policy)
        if result.targetWeight != target { result.targetDeadline = nil }
        result.projectionEstimateWeeks = projection.estimatedWeeks; result.projectionEstimateDate = projection.estimatedDate
        result.targetWeight = target; result.projectionWeeks = projection.weeks.map { [$0.lowerBound, $0.upperBound] }
        result.projectionEarliest = projection.earliest; result.projectionLatest = projection.latest
        result.projectionReason = projection.explanation; result.projectionConfidence = projection.confidence
        return result
    }
    func makeNextBestAction() -> NextBestAction {
        func result(_ action: CoachAction, _ title: String, _ reason: String, _ button: String, simulate: ((inout DailyELOInput) -> Void)? = nil) -> NextBestAction {
            var input = dailyScoreInput(for: now); simulate?(&input)
            let opportunity = simulate.map { _ in max(0, DailyELOEngine().evaluate(input, previousELO: currentELO).delta - projectedScore.delta) }
            return .init(action: action, title: title, reason: reason, button: button, opportunity: opportunity)
        }
        if ownerSystem.sleepStartedAt != nil { return result(.sleep, "Finish your sleep check-in", "A recorded sleep interval is still open.", "End sleep") }
        if activeWorkout != nil { return result(.resume, "Continue your session", "Your saved sets and timer are ready.", "Resume workout") }
        if ownerSystem.sickActive { return result(.recovery, "Prioritize recovery", "Sick Mode protects training objectives. Keep sleep and fuel in view.", "View recovery") }
        if checkInToday == nil && policy.calendar.component(.hour, from: now) < 12 {
            return result(.checkIn, "Start with your morning check-in", "Weight, sleep and how you feel help adjust today's plan.", "Check in") { $0.checkIn = true }
        }
        if let food = todayNutrition, food.calories < food.calorieGoal * 0.9 {
            return result(.nutrition, "Finish your nutrition target", "Approximately \(Int(max(0, food.calorieGoal - food.calories))) kcal remain against your configured goal.", "Log nutrition") { input in
                input.facts.calorieAdherence = 1; input.facts.proteinAdherence = 1
                input.facts.objectives = self.todayObjectives.map { .init(title: $0.title, completed: $0.completedAt != nil || [.calories, .protein].contains(ObjectiveKind(rawValue: $0.kindRaw) ?? .custom), importance: ObjectiveImportance(rawValue: $0.importanceRaw) ?? .standard, recoveryExempt: $0.recoveryExempt) }
            }
        }
        if let plan = brainDecision.session {
            return result(.workout, "Start \(plan.name)", brainDecision.reasons.first ?? "Built for your equipment and current recovery.", "View today's plan") { input in
                input.stimulus += Double(plan.exercises.reduce(0) { $0 + $1.sets }) * 0.8
                input.facts.objectives = self.todayObjectives.map { .init(title: $0.title, completed: $0.completedAt != nil || $0.kindRaw == ObjectiveKind.workout.rawValue, importance: ObjectiveImportance(rawValue: $0.importanceRaw) ?? .standard, recoveryExempt: $0.recoveryExempt) }
            }
        }
        if todayNutrition == nil { return result(.nutrition, "Record today's fuel", "Intake is unknown. Log it to understand your remaining targets.", "Log nutrition") }
        if todayObjectives.contains(where: { $0.completedAt == nil && !$0.recoveryExempt }) { return result(.objectives, "Finish an objective", "Keep your chosen daily rhythm in view.", "View objectives") }
        return result(.recovery, "Let today's work settle", brainDecision.reasons.first ?? "Review recovery before adding more training.", "View recovery")
    }
    func openCoachAction(_ action: CoachAction) {
        switch action {
        case .checkIn: presentedSheet = .checkIn
        case .nutrition: presentedSheet = .nutrition
        case .workout: navigationRequest = .workout
        case .resume: startLiveWorkout()
        case .recovery: navigationRequest = .recovery
        case .objectives: presentedSheet = .objectives
        case .sleep: presentedSheet = ownerSystem.sleepStartedAt == nil ? .sleep : .endSleep
        case .weight: presentedSheet = .weight
        }
    }
}
