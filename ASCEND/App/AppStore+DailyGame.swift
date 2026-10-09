import Foundation

extension AppStore {
    var weeklyExplanation: String {
        let recap = weeklyRecap
        if recap.workouts == 0 && recap.fuelDays == 0 { return "Log training and fuel to establish a useful weekly picture." }
        if recap.records > 0 { return "Comparable training produced personal records. Keep repeatable working sets and recovery in the same picture." }
        if recap.trainingDays >= 2 { return "Training consistency is established this week. Keep the next session appropriate to current recovery." }
        return "Coverage is still limited. A repeatable logging rhythm will make next week's comparison more useful."
    }
    func explain(facts: [String], focus: String, confidence: Confidence) async -> BrainInsight {
        let value = BrainContext(trendWeight: nil, momentum: nil, readiness: nil, calories: nil, protein: nil,
            confidence: confidence, observedWeightDays: 0, allowedActions: [], explanationFacts: facts, focus: focus)
        let provider: (any BrainProvider)?
        #if canImport(FoundationModels)
        provider = settings.onDeviceAIEnabled && brainArchive.settings.enabled ? FoundationModelsBrainProvider() : nil
        #else
        provider = nil
        #endif
        return await FitnessBrain(provider: provider).analyze(value)
    }
    var dailyResult: DailyResult { DailyGameEngine().presentation(projectedScore,
        momentum: progress.momentumPercent, confidence: progress.confidence) }
    func finalizedResult(_ entry: ELOHistoryEntry) -> DailyResult {
        let components = entry.evaluation.flatMap { try? JSONDecoder().decode([ScoreComponent].self, from: $0.componentData) } ?? []
        let result = ELOResult(previousELO: entry.previousELO, elo: entry.elo, delta: entry.delta, components: components,
            rank: RankEngine().status(elo: entry.elo, previousELO: entry.previousELO))
        return DailyGameEngine().presentation(result, momentum: nil, confidence: .low)
    }
    var unseenEvaluation: Bool {
        guard !isDemo, let latest = history.last else { return false }
        return (ownerSystem.lastSeenDay ?? localPreferences?.string(forKey: "seen-daily-evaluation-v1")) != latest.dayKey
    }
    func acknowledgeEvaluation() { if let latest = history.last { _ = saveOwnerSystem { $0.lastSeenDay = latest.dayKey }; localPreferences?.set(latest.dayKey, forKey: "seen-daily-evaluation-v1") } }
    private var goodFuel: [NutritionEntry] {
        nutrition.filter { (0.9...1.1).contains($0.calories / max(1, $0.calorieGoal)) && $0.proteinGrams / max(1, $0.proteinGoal) >= 0.9 }
    }
    private var objectiveDays: [Date] {
        Dictionary(grouping: occurrences) { $0.dayKey }.values.compactMap { day in
            day.contains { $0.completedAt != nil } && day.allSatisfy { $0.completedAt != nil || $0.recoveryExempt } ? day.first?.date : nil
        }
    }
    var streaks: [(String, Int, String)] {
        let engine = StreakEngine()
        let protected = protectedDays
        let objectives = Set(objectiveDays.map { policy.key(for: $0) })
        let perfect = goodFuel.filter { objectives.contains($0.dayKey) }.map(\.date)
        return [
            ("Training", engine.workoutWeeks(dates: sessions.filter { $0.hasWorkingSets }.map(\.evaluationDate), now: now, policy: policy, protectedDays: protected), "weeks"),
            ("Nutrition", engine.daily(qualifyingDays: goodFuel.map(\.date), now: now, policy: policy), "days"),
            ("Objectives", engine.daily(qualifyingDays: objectiveDays, now: now, policy: policy, protectedDays: protected), "days"),
            ("Perfect day", engine.daily(qualifyingDays: perfect, now: now, policy: policy), "days")
        ]
    }
    var weeklyRecap: WeeklyRecap {
        let lower = policy.adding(days: -6, to: policy.start(of: now))
        let ledger = history.filter { $0.date >= lower && $0.date <= now }
        let earlierELO = ledger.first?.previousELO ?? currentELO
        let workouts = sessions.filter { $0.hasWorkingSets && $0.evaluationDate >= lower && $0.evaluationDate <= now }
        let food = nutrition.filter { $0.date >= lower && $0.date <= now }
        let validFood = goodFuel.filter { $0.date >= lower && $0.date <= now }
        let due = occurrences.filter { $0.date >= lower && $0.date <= now }
        let earlierTrend = progress.trend.last { $0.date < lower && $0.date >= policy.adding(days: -7, to: lower) }
        let trendChange = progress.confidence != .low ? earlierTrend.flatMap { old in progress.trendWeight.map { $0 - old.kilograms } } : nil
        return WeeklyRecap(eloDelta: ledger.reduce(0) { $0 + $1.delta }, previousRank: RankEngine().status(elo: earlierELO).rank,
            currentRank: rank.rank, workouts: workouts.count, trainingDays: Set(workouts.map { policy.key(for: $0.evaluationDate) }).count,
            fuelDays: food.count, fuelAdherence: food.isEmpty ? nil : Double(validFood.count) / Double(food.count),
            trendChange: trendChange, momentum: progress.confidence == .low ? nil : progress.momentumPercent,
            records: records.filter { $0.achievedAt >= lower && $0.achievedAt <= now }.count,
            objectivesCompleted: due.filter { $0.completedAt != nil }.count, objectivesDue: due.count,
            recoveryProtected: due.filter(\.recoveryExempt).count)
    }
    func recoveryAlternative(for occurrence: DailyObjectiveCompletion) -> (String, Double)? {
        guard occurrence.completedAt == nil, !occurrence.recoveryExempt,
              let id = occurrence.objective?.exerciseCatalogID,
              let exercise = exercises.first(where: { $0.catalogID == id }),
              ObjectiveEngine().shouldExempt(contributions: exercise.contributions, recovery: readiness) else { return nil }
        let impacted = readiness.muscles.filter { muscle in exercise.contributions.contains { $0.muscle == muscle.muscle && $0.fraction >= 0.1 } }
        return impacted.min(by: { $0.recoveryPercent < $1.recoveryPercent }).map { ($0.muscle.group, $0.recoveryPercent) }
    }
}
