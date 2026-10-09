import Foundation

public struct ProgressionPlanEngine: Sendable {
    public init() {}
    public func targets(history: [ExerciseHistory], exercise: LiveExercise, count: Int, now: Date, recoveryLimited: Bool) -> [SetPerformance]? {
        guard let previous = ProgressionEngine().previous(history, exercise: exercise, now: now), !previous.working.isEmpty else { return nil }
        let suggestion = ProgressionEngine().suggest(history, exercise: exercise, now: now, recoveryLimited: recoveryLimited)
        return (0..<max(0, count)).map { index in
            let set = previous.working[min(index, previous.working.count - 1)]
            let p = set.performance
            guard exercise.mode == .reps || exercise.mode == .weightAndReps else { return p }
            if recoveryLimited { return .init(reps: max(1, p.reps - 1), kilograms: p.kilograms) }
            if let target = suggestion.target, target.kilograms > p.kilograms,
               exercise.weightStep > 0, exercise.weightStep <= p.kilograms * 0.05, (set.rpe ?? 7) < 9,
               target.kilograms >= p.kilograms + exercise.weightStep {
                return .init(reps: target.reps, kilograms: p.kilograms + exercise.weightStep)
            }
            // A difficult final set is an opportunity for stable reps, never an automatic load jump.
            let reps = min(previous.working.first?.performance.reps ?? p.reps, p.reps + (index > 0 ? 1 : 0))
            return .init(reps: max(1, reps), kilograms: p.kilograms)
        }
    }
}
