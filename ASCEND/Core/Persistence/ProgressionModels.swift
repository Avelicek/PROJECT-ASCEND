import Foundation
import SwiftData

@Model final class DailyObjective {
    @Attribute(.unique) var id: UUID
    var title: String
    var kindRaw: String
    var cadenceRaw: String
    var importanceRaw: String
    var target: Double
    var unit: String
    var startsAt: Date
    var weekdays: [Int]
    var isActive: Bool
    var exerciseCatalogID: String?
    @Relationship(deleteRule: .nullify, inverse: \DailyObjectiveCompletion.objective) var completions: [DailyObjectiveCompletion] = []
    var kind: ObjectiveKind { ObjectiveKind(rawValue: kindRaw) ?? .custom }
    var importance: ObjectiveImportance { ObjectiveImportance(rawValue: importanceRaw) ?? .standard }
    var schedule: ObjectiveSchedule { .init(cadence: ObjectiveCadence(rawValue: cadenceRaw) ?? .daily, startsAt: startsAt, weekdays: weekdays) }
    init(title: String, kind: ObjectiveKind, cadence: ObjectiveCadence, importance: ObjectiveImportance, target: Double,
         unit: String, startsAt: Date, weekdays: [Int] = [], exerciseCatalogID: String? = nil) {
        self.id = UUID(); self.title = title; self.kindRaw = kind.rawValue; self.cadenceRaw = cadence.rawValue
        self.importanceRaw = importance.rawValue; self.target = target; self.unit = unit; self.startsAt = startsAt
        self.weekdays = weekdays; self.isActive = true; self.exerciseCatalogID = exerciseCatalogID
    }
}

@Model final class DailyObjectiveCompletion {
    @Attribute(.unique) var occurrenceKey: String
    var dayKey: String
    var date: Date
    var title: String
    var kindRaw: String
    var importanceRaw: String
    var target: Double
    var unit: String
    var value: Double
    var completedAt: Date?
    var recoveryExempt: Bool
    var replacementTitle: String?
    var objective: DailyObjective?
    init(objective: DailyObjective, date: Date, policy: DayPolicy) {
        self.dayKey = policy.key(for: date); self.occurrenceKey = "\(objective.id.uuidString):\(policy.key(for: date))"
        self.date = policy.start(of: date); self.title = objective.title; self.kindRaw = objective.kindRaw
        self.importanceRaw = objective.importanceRaw; self.target = objective.target; self.unit = objective.unit
        self.value = 0; self.recoveryExempt = false; self.objective = objective
    }
}

@Model final class DailyEvaluation {
    @Attribute(.unique) var dayKey: String
    var date: Date
    var evaluatedAt: Date
    var scoringVersion: Int
    var componentData: Data
    var eloDelta: Int
    @Relationship(deleteRule: .cascade, inverse: \ELOHistoryEntry.evaluation) var history: ELOHistoryEntry?
    init(dayKey: String, date: Date, result: ELOResult, evaluatedAt: Date) throws {
        self.dayKey = dayKey; self.date = date; self.evaluatedAt = evaluatedAt; self.scoringVersion = 1
        self.componentData = try JSONEncoder().encode(result.components); self.eloDelta = result.delta
    }
}

@Model final class ELOHistoryEntry {
    @Attribute(.unique) var dayKey: String
    var date: Date
    var previousELO: Int
    var elo: Int
    var delta: Int
    var evaluation: DailyEvaluation?
    init(dayKey: String, date: Date, previousELO: Int, elo: Int, delta: Int) {
        self.dayKey = dayKey; self.date = date; self.previousELO = previousELO; self.elo = elo; self.delta = delta
    }
}

@Model final class MuscleState {
    @Attribute(.unique) var muscleRaw: String
    var recoveryPercent: Double
    var load: Double
    var fatigue: Double
    var lastTrainedAt: Date?
    var estimatedRecoveryTime: Date?
    var confidenceRaw: String
    var calculatedAt: Date
    init(result: MuscleRecovery, calculatedAt: Date) {
        self.muscleRaw = result.muscle.rawValue; self.recoveryPercent = result.recoveryPercent
        self.load = result.load; self.fatigue = result.fatigue; self.lastTrainedAt = result.lastTrainedAt
        self.estimatedRecoveryTime = result.estimatedRecoveryTime; self.confidenceRaw = result.confidence.rawValue
        self.calculatedAt = calculatedAt
    }
}

@Model final class BrainInsightRecord {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var contextFingerprint: String
    var payload: Data
    init(insight: BrainInsight, createdAt: Date, contextFingerprint: String) throws {
        self.id = UUID(); self.createdAt = createdAt; self.contextFingerprint = contextFingerprint
        self.payload = try JSONEncoder().encode(insight)
    }
}
