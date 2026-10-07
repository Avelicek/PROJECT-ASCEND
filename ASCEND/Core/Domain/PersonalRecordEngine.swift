import Foundation

public struct RecordImprovement: Codable, Sendable, Identifiable {
    public let exerciseID: String
    public let exerciseName: String
    public let kind: RecordKind
    public let contextKG: Double?
    public let previous: Double
    public let value: Double
    public var id: String { exerciseID + ":" + storageKey }
    public var storageKey: String { kind == .reps ? "reps@\(contextKG ?? 0)" : kind.rawValue }
    public var title: String {
        switch kind {
        case .weight: "Heaviest load"
        case .reps: "Most reps · \((contextKG ?? 0).formatted()) kg"
        case .volume: "Session volume"
        case .estimatedOneRepMax: "Estimated 1RM"
        }
    }
    public var unit: String { kind == .reps ? "reps" : "kg" }
}

public struct PersonalRecordEngine: Sendable {
    public init() {}
    public func detect(exercise: LiveExercise, history: [ExerciseHistory], at date: Date) -> [RecordImprovement] {
        let prior = history.filter { $0.exerciseID == exercise.catalogID && $0.mode == exercise.mode && $0.date < date && !$0.quick }
        let sets = exercise.completedWorkingSets.map(\.performance)
        guard !prior.isEmpty, !sets.isEmpty, exercise.mode == .reps || exercise.mode == .weightAndReps else { return [] }
        let previousSets = prior.flatMap { $0.working.map(\.performance) }
        var improvements: [RecordImprovement] = []
        func add(_ kind: RecordKind, _ value: Double, _ previous: Double, context: Double? = nil) {
            if value.isFinite, previous > 0, value > previous + 0.001 {
                improvements.append(.init(exerciseID: exercise.catalogID, exerciseName: exercise.name,
                    kind: kind, contextKG: context, previous: previous, value: value))
            }
        }
        add(.weight, sets.map(\.kilograms).max() ?? 0, previousSets.map(\.kilograms).max() ?? 0)
        add(.volume, WorkoutEngine().volume(sets), prior.map { WorkoutEngine().volume($0.working.map(\.performance)) }.max() ?? 0)
        if exercise.mode == .weightAndReps && !exercise.bodyweight {
            func bestEstimate(_ sets: [SetPerformance]) -> Double {
                sets.filter { (1...12).contains($0.reps) && $0.kilograms > 0 }.map { $0.kilograms * (1 + Double($0.reps) / 30) }.max() ?? 0
            }
            add(.estimatedOneRepMax, bestEstimate(sets), bestEstimate(previousSets))
        }
        for weight in Set(sets.map(\.kilograms)).sorted() {
            let old = previousSets.filter { abs($0.kilograms - weight) < 0.001 }.map(\.reps).max() ?? 0
            let value = sets.filter { abs($0.kilograms - weight) < 0.001 }.map(\.reps).max() ?? 0
            add(.reps, Double(value), Double(old), context: weight)
        }
        return improvements
    }
}
