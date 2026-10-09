import Foundation

public struct TrainedRegion: Codable, Sendable, Identifiable {
    public let name: String
    public let setLoad: Double
    public var id: String { name }
    public var label: String { setLoad >= 5 ? "High" : setLoad >= 2 ? "Medium" : "Light" }
}
public struct CompletedWorkoutSummary: Codable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let durationSeconds: Double
    public let exerciseCount: Int
    public let workingSets: Int
    public let volumeKG: Double
    public let trainingLoad: Double
    public let muscles: [TrainedRegion]
    public let records: [RecordImprovement]
    public let progressedExercises: Int
    public var pendingELO: Int = 0
}
public struct WorkoutSummaryEngine: Sendable {
    public init() {}
    public func summarize(_ workout: LiveWorkout, history: [ExerciseHistory], finishedAt: Date) -> CompletedWorkoutSummary {
        var volume = 0.0, load = 0.0
        var weighted: [String: Double] = [:]
        var records: [RecordImprovement] = []
        var progressed = 0
        let exercises = workout.exercises.filter { $0.sets.contains { $0.completedAt != nil } }
        for exercise in exercises {
            let working = exercise.completedWorkingSets
            if exercise.mode == .reps || exercise.mode == .weightAndReps { volume += WorkoutEngine().volume(working.map(\.performance)) }
            let reference = history.filter { $0.exerciseID == exercise.catalogID && !$0.quick && $0.mode == exercise.mode && $0.date < workout.startedAt && workout.startedAt.timeIntervalSince($0.date) <= 42 * 86400 }.max { $0.date < $1.date }?.working.first?.performance.kilograms
            let setLoad = TrainingLoadEngine().stimulus(working.map { .init($0.performance(for: exercise.mode), rpe: $0.rpe) }, mode: exercise.mode, quick: false, referenceLoad: reference)
            load += setLoad
            for contribution in exercise.contributions { weighted[contribution.muscle.group, default: 0] += setLoad * max(0, contribution.fraction) }
            records += PersonalRecordEngine().detect(exercise: exercise, history: history, at: workout.startedAt)
            let current = ExerciseHistory(sessionID: workout.id, exerciseID: exercise.catalogID, date: finishedAt,
                mode: exercise.mode, sets: working.map { .init($0.performance, rpe: $0.rpe) })
            if ProgressionEngine().progressed(current: current, prior: history) { progressed += 1 }
        }
        return .init(id: workout.id, title: workout.title, durationSeconds: max(0, finishedAt.timeIntervalSince(workout.startedAt)),
            exerciseCount: exercises.count, workingSets: exercises.reduce(0) { $0 + $1.completedWorkingSets.count }, volumeKG: volume,
            trainingLoad: load, muscles: weighted.filter { $0.value > 0 }.map { .init(name: $0.key, setLoad: $0.value) }.sorted { $0.setLoad > $1.setLoad },
            records: records, progressedExercises: progressed)
    }
}
