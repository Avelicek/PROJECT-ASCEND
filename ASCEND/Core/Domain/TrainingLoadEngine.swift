import Foundation

public enum EffortRating: Int, CaseIterable, Hashable, Sendable {
    case easy = 6, moderate = 7, hard = 8, nearFailure = 9, failure = 10
    public var rir: Int { 10 - rawValue }
    public var title: String { switch self { case .easy: "Easy · 4+ left"; case .moderate: "Moderate · 3 left"; case .hard: "Hard · 2 left"; case .nearFailure: "Near failure · 1 left"; case .failure: "Failure · 0 left" } }
}

/// Comparable estimated stimulus units, not measured muscle damage or calories.
/// Every consumer uses this same function for formal, home and quick activities.
public struct TrainingLoadEngine: Sendable {
    public init() {}
    public func stimulus(_ sets: [PerformedSet], mode: TrackingMode, quick: Bool, referenceLoad: Double? = nil) -> Double {
        sets.filter { !$0.warmup }.reduce(0) { sum, set in
            let p = set.performance
            let amount: Double
            switch mode {
            case .reps, .weightAndReps:
                guard p.reps > 0 else { return sum }
                amount = quick ? min(10, Double(p.reps) / 15) : FitnessMath.clamp(Double(p.reps) / 10, 0.4...1.5)
            case .duration, .distance:
                guard p.seconds > 0 else { return sum }
                amount = min(10, p.seconds / (quick ? 180 : 60))
            }
            let rpe = FitnessMath.clamp(set.rpe ?? 7, 1...10)
            let effort = rpe < 6 ? 0.4 : 0.55 + (rpe - 6) * 0.25
            // External kilograms alone never compare unrelated exercises or estimate body mass.
            let loadRatio = referenceLoad.flatMap { $0 > 0 && p.kilograms > 0 ? p.kilograms / $0 : nil } ?? 1
            return sum + amount * effort * FitnessMath.clamp(loadRatio, 0.75...1.25)
        }
    }
    public func muscles(stimulus: Double, contributions: [MuscleContribution]) -> [Muscle: Double] {
        var result: [Muscle: Double] = [:]
        for part in contributions { result[part.muscle, default: 0] += max(0, stimulus) * FitnessMath.clamp(part.fraction, 0...1) }
        return result
    }
}

public struct AutoregulationAdvice: Sendable {
    public let id: UUID
    public let explanation: String
    public let extraRest: Int
    public let kilograms: Double?
}
public struct AdaptiveRestEngine: Sendable {
    public init() {}
    public func seconds(pattern: MovementPattern?, goal: TrainingGoal, rpe: Double?, fatigue: Double?, preference: Int? = nil) -> Int {
        if let preference { return min(900, max(15, preference)) }
        let compound: Set<MovementPattern> = [.horizontalPush, .verticalPush, .horizontalPull, .verticalPull, .squat, .hinge, .lunge]
        var seconds = pattern.map { compound.contains($0) ? (goal == .strength || (rpe ?? 7) >= 9 ? 150 : 90) : 60 } ?? 90
        if (fatigue ?? 0) >= 50 { seconds += 30 }
        return seconds
    }
    public func advice(_ exercise: LiveExercise) -> AutoregulationAdvice? {
        let sets = exercise.completedWorkingSets
        guard sets.count >= 3, let first = sets.first, let last = sets.last,
              exercise.mode == .reps || exercise.mode == .weightAndReps,
              first.reps >= 5, Double(last.reps) / Double(first.reps) < 0.65,
              abs(first.kilograms - last.kilograms) < 0.001 else { return nil }
        let step = min(exercise.weightStep, last.kilograms * 0.1)
        let lower = step > 0 ? max(0, last.kilograms - step * max(1, floor(last.kilograms * 0.08 / step))) : nil
        return .init(id: last.id, explanation: "Reps fell from \(first.reps) to \(last.reps) at the same load. Take 45 seconds more rest before continuing; an optional small load reduction is available. If the next set still declines or form breaks down, stop here instead of adding work.", extraRest: 45, kilograms: lower)
    }
}

/// Absolute elapsed-time clock survives suspension and a restored workout draft.
public struct ExerciseClock: Codable, Sendable {
    public var exerciseID: UUID
    public var setID: UUID
    public var startedAt: Date?
    public var accumulated: Double = 0
    public init(exerciseID: UUID, setID: UUID, at date: Date) { self.exerciseID = exerciseID; self.setID = setID; startedAt = date }
    public func elapsed(at date: Date) -> Double { FitnessMath.clamp(accumulated + (startedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0), 0...86400) }
    public mutating func pause(at date: Date) { accumulated = elapsed(at: date); startedAt = nil }
    public mutating func resume(at date: Date) { if startedAt == nil { startedAt = date } }
    public var isValid: Bool { accumulated.isFinite && (0...86400).contains(accumulated) && (startedAt.map(OwnerDates.valid) ?? true) }
}
