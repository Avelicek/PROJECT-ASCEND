import Foundation
import SwiftData

extension AppStore {
    func evaluationInput(for date: Date, includeMisses: Bool = true) -> ELOInput {
        var input = ELOInput()
        let key = policy.key(for: date)
        let food = nutrition.first { $0.dayKey == key }
        input.calorieAdherence = food.map { $0.calories / max(1, $0.calorieGoal) }
        input.proteinAdherence = food.map { $0.proteinGrams / max(1, $0.proteinGoal) }
        input.completedWorkout = sessions.contains { policy.sameDay($0.evaluationDate, date) && $0.hasWorkingSets }
        let dayRecords = records.filter { policy.sameDay($0.achievedAt, date) }
        input.personalRecords = dayRecords.count
        let dailySessions = exerciseHistory.filter { policy.sameDay($0.date, date) }
        input.trainingProgressed = dailySessions.contains { ProgressionEngine().progressed(current: $0, prior: exerciseHistory) }
        let end = min(now, policy.adding(days: 1, to: policy.start(of: date)).addingTimeInterval(-0.001))
        let progress = ProgressEngine().report(samples: weights.map { .init(date: $0.measuredAt, kilograms: $0.kilograms) },
            start: profile.startingWeightKG, target: profile.targetWeightKG, desiredWeeklyChange: profile.desiredWeeklyChangeKG,
            now: end, policy: policy)
        input.momentum = progress.confidence == .low ? nil : progress.momentumPercent
        let recentStart = policy.adding(days: -3, to: policy.start(of: date))
        input.consistent = Set(nutrition.filter { $0.date >= recentStart && $0.date <= end }.map(\.dayKey)).count >= 3
        let due = occurrences.filter { $0.dayKey == key && (includeMisses || $0.completedAt != nil || $0.recoveryExempt) }
        input.recoverySafeChoice = due.contains { $0.recoveryExempt }
        input.objectives = due.map { .init(title: $0.title, completed: $0.completedAt != nil,
            importance: ObjectiveImportance(rawValue: $0.importanceRaw) ?? .standard, recoveryExempt: $0.recoveryExempt) }
        return input
    }

    func finalizeClosedDays() throws {
        // Only actual recorded days are scored. No invented missed days while the app is closed.
        let lastEvaluated = history.last?.date
        let candidates = nutrition.map(\.date) + sleep.map(\.date) + weights.map(\.measuredAt) +
            sessions.filter { $0.hasWorkingSets }.map(\.evaluationDate) + occurrences.map(\.date)
        let days = Set(candidates.map { policy.start(of: $0) }).sorted()
        for date in days where date < policy.start(of: now) && date >= policy.start(of: profile.createdAt) {
            if let lastEvaluated, date <= lastEvaluated { continue }
            let key = policy.key(for: date)
            guard !evaluations.contains(where: { $0.dayKey == key }) else { continue }
            let result = ELOEngine().evaluate(evaluationInput(for: date), previousELO: history.last?.elo ?? 0)
            let evaluation = try DailyEvaluation(dayKey: key, date: date, result: result, evaluatedAt: now)
            let entry = ELOHistoryEntry(dayKey: key, date: date, previousELO: result.previousELO, elo: result.elo, delta: result.delta)
            evaluation.history = entry; entry.evaluation = evaluation
            context.insert(evaluation); context.insert(entry)
            evaluations.append(evaluation); history.append(entry)
            profile.lifetimeCredits += max(0, result.delta)
        }
    }
}
