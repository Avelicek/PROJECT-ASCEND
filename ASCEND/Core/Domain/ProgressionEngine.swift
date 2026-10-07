import Foundation

public struct ProgressionSuggestion: Sendable {
    public let target: SetPerformance?
    public let confidence: Confidence
    public let explanation: String
}

public struct ProgressionEngine: Sendable {
    public init() {}
    public func comparable(_ history: [ExerciseHistory], exercise: LiveExercise, now: Date) -> [ExerciseHistory] {
        history.filter { $0.exerciseID == exercise.catalogID && $0.mode == exercise.mode && !$0.quick &&
            $0.date <= now && $0.date >= now.addingTimeInterval(-42 * 86400) && !$0.working.isEmpty }
            .sorted { $0.date > $1.date }
    }
    public func previous(_ history: [ExerciseHistory], exercise: LiveExercise, now: Date) -> ExerciseHistory? {
        comparable(history, exercise: exercise, now: now).first
    }
    public func suggest(_ history: [ExerciseHistory], exercise: LiveExercise, now: Date, recoveryLimited: Bool = false) -> ProgressionSuggestion {
        func hold(_ explanation: String) -> ProgressionSuggestion { .init(target: nil, confidence: .low, explanation: explanation) }
        guard !recoveryLimited else { return hold("Recovery is limited. Consider an easier session before progressing.") }
        guard exercise.mode == .reps || exercise.mode == .weightAndReps else { return hold("Use your previous pace and duration as context; no automatic increase.") }
        let recent = Array(comparable(history, exercise: exercise, now: now).prefix(2))
        guard recent.count == 2, recent.allSatisfy({ $0.working.count >= 2 }) else {
            return hold("Build two comparable sessions before increasing the target.")
        }
        let last = recent[0].working
        guard let anchor = last.first?.performance else { return hold("Log working sets to build a baseline.") }
        let weight = anchor.kilograms
        let comparableSets = recent.map { $0.working.filter { abs($0.performance.kilograms - weight) < 0.001 } }
        guard comparableSets.allSatisfy({ $0.count >= 2 }) else { return hold("Loads differ. Repeat a familiar load before progressing.") }
        let efforts = comparableSets.flatMap { $0 }.compactMap(\.rpe)
        guard !efforts.contains(where: { !$0.isFinite || $0 >= 9 }) else { return hold("Recent sets were near maximum effort. Repeat rather than increase.") }
        let reps = comparableSets.flatMap { $0 }.map { $0.performance.reps }
        guard let minimum = reps.min(), let maximum = reps.max(), minimum > 0, maximum - minimum <= 3,
              maximum <= (exercise.bodyweight ? 30 : 15) else { return hold("Performance varies. Match your last session before progressing.") }
        let confidence: Confidence = efforts.count == reps.count ? .high : .medium
        if !exercise.bodyweight, weight > 0, minimum >= 10,
           exercise.weightStep > 0, exercise.weightStep <= weight * 0.05 {
            return .init(target: .init(reps: 7, kilograms: weight + exercise.weightStep), confidence: confidence,
                explanation: "Two consistent sessions support one small load step. Keep reps lower and stop short of maximum effort.")
        }
        return .init(target: .init(reps: minimum + 1, kilograms: weight), confidence: confidence,
            explanation: "Try one extra rep at the same load. Keep technique and effort comparable; the target is optional.")
    }
    public func progressed(current: ExerciseHistory, prior: [ExerciseHistory]) -> Bool {
        guard !current.quick, current.mode == .reps || current.mode == .weightAndReps,
              let previous = prior.filter({ $0.exerciseID == current.exerciseID && $0.mode == current.mode && !$0.quick &&
                $0.date < current.date && $0.date >= current.date.addingTimeInterval(-42 * 86400) }).max(by: { $0.date < $1.date }) else { return false }
        return current.working.contains { set in
            let matches = previous.working.filter { abs($0.performance.kilograms - set.performance.kilograms) < 0.001 }
            guard let best = matches.map({ $0.performance.reps }).max() else { return false }
            let oldEffort = matches.filter { $0.performance.reps == best }.compactMap(\.rpe).min()
            let effortOK = set.rpe == nil || oldEffort == nil || set.rpe! <= oldEffort!
            return effortOK && (set.performance.reps > best ||
                (set.performance.reps == best && set.rpe != nil && oldEffort != nil && set.rpe! < oldEffort!))
        }
    }
}
