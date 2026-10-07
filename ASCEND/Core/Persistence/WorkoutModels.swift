import Foundation
import SwiftData

@Model final class Exercise {
    @Attribute(.unique) var catalogID: String
    var name: String
    var categoryRaw: String
    var equipmentRaw: String
    var trackingModeRaw: String
    var bodyweightCapable: Bool
    var additionalWeightAllowed: Bool
    var contributionData: Data
    var primaryMuscleNames: [String]
    @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise) var logs: [WorkoutExercise] = []
    var contributions: [MuscleContribution] { (try? JSONDecoder().decode([MuscleContribution].self, from: contributionData)) ?? [] }
    var trackingMode: TrackingMode { TrackingMode(rawValue: trackingModeRaw) ?? .reps }
    init(catalogID: String, name: String, category: ExerciseCategory, equipment: Equipment, trackingMode: TrackingMode,
         bodyweightCapable: Bool, additionalWeightAllowed: Bool, contributions: [MuscleContribution]) {
        self.catalogID = catalogID; self.name = name; self.categoryRaw = category.rawValue; self.equipmentRaw = equipment.rawValue
        self.trackingModeRaw = trackingMode.rawValue; self.bodyweightCapable = bodyweightCapable
        self.additionalWeightAllowed = additionalWeightAllowed
        self.contributionData = (try? JSONEncoder().encode(contributions)) ?? Data()
        self.primaryMuscleNames = contributions.filter { $0.fraction >= 0.25 }.map { $0.muscle.rawValue }
    }
}

@Model final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var completedAt: Date?
    var title: String
    var isQuickLog: Bool
    var notes: String
    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.session) var exercises: [WorkoutExercise] = []
    init(startedAt: Date, title: String, isQuickLog: Bool) {
        self.id = UUID(); self.startedAt = startedAt; self.title = title; self.isQuickLog = isQuickLog; self.notes = ""
    }
}

@Model final class WorkoutExercise {
    @Attribute(.unique) var id: UUID
    var order: Int
    var exerciseName: String
    var contributionData: Data // Snapshot survives future catalog revisions.
    var trackingModeRaw: String
    var session: WorkoutSession?
    var exercise: Exercise?
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.workoutExercise) var sets: [WorkoutSet] = []
    var contributions: [MuscleContribution] { (try? JSONDecoder().decode([MuscleContribution].self, from: contributionData)) ?? [] }
    var trackingMode: TrackingMode { TrackingMode(rawValue: trackingModeRaw) ?? .reps }
    init(exercise: Exercise, order: Int) {
        self.id = UUID(); self.order = order; self.exercise = exercise; self.exerciseName = exercise.name
        self.contributionData = exercise.contributionData; self.trackingModeRaw = exercise.trackingModeRaw
    }
}

@Model final class WorkoutSet {
    @Attribute(.unique) var id: UUID
    var order: Int
    var reps: Int
    var weightKG: Double
    var durationSeconds: Double
    var distanceMeters: Double
    var perceivedExertion: Double?
    var isWarmup: Bool
    var completedAt: Date
    var workoutExercise: WorkoutExercise?
    var performance: SetPerformance { .init(reps: reps, kilograms: weightKG, seconds: durationSeconds, distanceMeters: distanceMeters) }
    init(order: Int, performance: SetPerformance, completedAt: Date, perceivedExertion: Double? = nil) {
        self.id = UUID(); self.order = order; self.reps = performance.reps; self.weightKG = performance.kilograms
        self.durationSeconds = performance.seconds; self.distanceMeters = performance.distanceMeters
        self.perceivedExertion = perceivedExertion; self.isWarmup = false; self.completedAt = completedAt
    }
}

@Model final class PersonalRecord {
    @Attribute(.unique) var id: UUID
    var exerciseCatalogID: String
    var kindRaw: String
    var value: Double
    var achievedAt: Date
    var sessionID: UUID
    init(exerciseCatalogID: String, kind: RecordKind, value: Double, achievedAt: Date, sessionID: UUID) {
        self.id = UUID(); self.exerciseCatalogID = exerciseCatalogID; self.kindRaw = kind.rawValue
        self.value = value; self.achievedAt = achievedAt; self.sessionID = sessionID
    }
}

// Derived properties keep the existing SwiftData schema unchanged.
extension WorkoutSession {
    var evaluationDate: Date { completedAt ?? startedAt }
    var hasWorkingSets: Bool { completedAt != nil && exercises.contains { $0.sets.contains { !$0.isWarmup } } }
}
