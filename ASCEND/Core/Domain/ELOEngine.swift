import Foundation

public enum ScoreCategory: String, Codable, Sendable {
    case nutrition, training, consistency, progress, personalRecord, objective, recovery, sleep, adherence
}
public struct ScoreComponent: Codable, Sendable, Identifiable {
    public let category: ScoreCategory
    public let label: String
    public let points: Int
    public let id: String
    public init(category: ScoreCategory, label: String, points: Int, id: String? = nil) {
        self.category = category; self.label = label; self.points = points
        self.id = id ?? "\(category.rawValue):\(label)"
    }
}
public struct ObjectiveScoreInput: Sendable {
    public let title: String
    public let completed: Bool
    public let importance: ObjectiveImportance
    public let recoveryExempt: Bool
    public init(title: String, completed: Bool, importance: ObjectiveImportance, recoveryExempt: Bool = false) {
        self.title = title; self.completed = completed; self.importance = importance; self.recoveryExempt = recoveryExempt
    }
}
public struct ELOInput: Sendable {
    public var calorieAdherence: Double?
    public var proteinAdherence: Double?
    public var completedWorkout: Bool = false
    public var trainingProgressed: Bool = false
    public var personalRecords: Int = 0
    public var momentum: Double?
    public var consistent: Bool = false
    public var recoverySafeChoice: Bool = false
    public var objectives: [ObjectiveScoreInput] = []
    public init() {}
}
public struct ELOConfiguration: Sendable {
    public var caloriePoints = 3
    public var proteinPoints = 3
    public var trainingPoints = 5
    public var progressionPoints = 2
    public var recordPoints = 2
    public var consistencyPoints = 2
    public var progressPoints = 3
    public var objectivePoints = 2
    public var missedObjectivePenalty = 2
    public var recoveryPoints = 1
    public init() {}
}
public struct ELOResult: Sendable {
    public let previousELO: Int
    public let elo: Int
    public let delta: Int
    public let components: [ScoreComponent]
    public let rank: RankStatus
}
public struct ELOEngine: Sendable {
    public let configuration: ELOConfiguration
    public init(configuration: ELOConfiguration = .init()) { self.configuration = configuration }
    // Experimental Build 01 weights; evaluate only a closed local calendar day.
    public func evaluate(_ input: ELOInput, previousELO: Int) -> ELOResult {
        var parts: [ScoreComponent] = []
        func add(_ category: ScoreCategory, _ label: String, _ points: Int) {
            if points != 0 { parts.append(.init(category: category, label: label, points: points, id: "\(parts.count):\(category.rawValue)")) }
        }
        if let ratio = input.calorieAdherence, ratio.isFinite, (0.9...1.1).contains(ratio) {
            add(.nutrition, "Calorie goal", configuration.caloriePoints)
        }
        if let ratio = input.proteinAdherence, ratio.isFinite, ratio >= 0.9 {
            add(.nutrition, "Protein goal", configuration.proteinPoints)
        }
        if input.completedWorkout { add(.training, "Completed workout", configuration.trainingPoints) }
        if input.trainingProgressed { add(.training, "Training progression", configuration.progressionPoints) }
        if input.personalRecords > 0 { add(.personalRecord, "Personal records", min(3, input.personalRecords) * configuration.recordPoints) }
        if input.consistent { add(.consistency, "Consistent logging", configuration.consistencyPoints) }
        if let momentum = input.momentum, momentum > 0 { add(.progress, "Trend toward goal", configuration.progressPoints) }
        if input.recoverySafeChoice { add(.recovery, "Recovery-safe choice", configuration.recoveryPoints) }
        for objective in input.objectives {
            if objective.completed {
                add(.objective, objective.title, Int((Double(configuration.objectivePoints) * objective.importance.weight).rounded()))
            } else if !objective.recoveryExempt {
                add(.objective, "Missed: \(objective.title)", -Int((Double(configuration.missedObjectivePenalty) * objective.importance.weight).rounded()))
            }
        }
        let old = max(0, previousELO)
        let proposed = parts.reduce(0) { $0 + $1.points }
        let addition = old.addingReportingOverflow(proposed)
        let new = addition.overflow ? (proposed > 0 ? Int.max : 0) : max(0, addition.partialValue)
        if new - old != proposed { add(.objective, "ELO floor protection", new - old - proposed) }
        return ELOResult(previousELO: old, elo: new, delta: new - old, components: parts,
                         rank: RankEngine().status(elo: new, previousELO: old))
    }
    public func lifetimeLevel(credits: Int) -> Int { 1 + max(0, credits) / 100 }
}
