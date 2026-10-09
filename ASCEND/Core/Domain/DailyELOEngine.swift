import Foundation

public struct DailyELOInput: Sendable {
    public var facts = ELOInput()
    public var stimulus = 0.0
    public var spontaneousStimulus = 0.0
    public var expectedStimulus = 8.0
    public var recentTrainingDays = 0
    public var sleepHours: Double?
    public var sleepTarget = 8.0
    public var recoveryLimited = false
    public var checkIn = false
    public var closed = false
    public init() {}
}

/// V2 applies only to the open day / newly finalized days. V1 ledger entries are immutable.
public struct DailyELOEngine: Sendable {
    public init() {}
    public func evaluate(_ input: DailyELOInput, previousELO: Int) -> ELOResult {
        var parts: [ScoreComponent] = []
        func add(_ category: ScoreCategory, _ label: String, _ points: Double) {
            let value = Int(points.rounded()); if value != 0 { parts.append(.init(category: category, label: label, points: value)) }
        }
        let expected = FitnessMath.clamp(input.expectedStimulus, 3...18)
        let formal = max(0, input.stimulus - input.spontaneousStimulus)
        add(.training, "Training execution · relative to your baseline", min(14, formal / expected * 14))
        add(.training, "Spontaneous activity · shared training load", min(6, input.spontaneousStimulus / expected * 10))
        if input.facts.trainingProgressed { add(.training, "Comparable performance improved", 2) }
        if input.facts.personalRecords > 0 { add(.personalRecord, "Observed personal record", 1) }
        func adherence(_ ratio: Double?, maximum: Double, label: String, energy: Bool) {
            guard let ratio, ratio.isFinite else { return } // Unknown never becomes an invented failure.
            let quality = energy ? max(0, 1 - abs(1 - ratio) / 0.5) : min(1, max(0, ratio))
            let points = quality >= 0.8 ? quality * maximum : input.closed ? -(1 - quality) * maximum : 0
            add(.nutrition, label, points)
        }
        adherence(input.facts.calorieAdherence, maximum: 4, label: "Energy coverage", energy: true)
        adherence(input.facts.proteinAdherence, maximum: 3, label: "Protein coverage", energy: false)
        if let hours = input.sleepHours, hours.isFinite {
            let ratio = hours / max(1, input.sleepTarget)
            add(.sleep, "Recorded sleep", ratio >= 0.9 ? 2 : ratio < 0.7 ? -3 : 0)
        }
        if input.stimulus == 0 && input.recoveryLimited { add(.recovery, "Recovery is the appropriate decision", 2) }
        if input.recoveryLimited && input.stimulus > expected * 1.5 { add(.recovery, "High load while recovery is limited", -4) }
        if input.stimulus > 0 && input.recentTrainingDays >= 2 { add(.consistency, "Repeatable training rhythm", 2) }
        if input.checkIn { add(.consistency, "Morning check-in", 1) }
        if input.facts.consistent { add(.consistency, "Consistent fuel logging", 1) }
        let due = input.facts.objectives.filter { !$0.recoveryExempt || $0.completed }
        if !due.isEmpty {
            let total = due.reduce(0) { $0 + $1.importance.weight }
            let done = due.filter(\.completed).reduce(0) { $0 + $1.importance.weight }
            add(.objective, "Daily objectives", input.closed ? (done / total * 8 - 4) : done / total * 4)
        }
        let raw = parts.reduce(0) { $0 + $1.points }
        let bounded = min(30, max(-30, raw))
        if raw != bounded { add(.adherence, "Daily range adjustment", Double(bounded - raw)) }
        let old = max(0, previousELO)
        let safe = old.addingReportingOverflow(bounded)
        let next = safe.overflow ? Int.max : max(0, safe.partialValue)
        // Preserve the existing rank floor and exact ledger arithmetic / backup contract.
        if next - old != bounded { add(.adherence, "Rank floor protection", Double(next - old - bounded)) }
        return .init(previousELO: old, elo: next, delta: next - old, components: parts, rank: RankEngine().status(elo: next, previousELO: old))
    }
    public func description(_ score: Int) -> String {
        switch score { case 25...: "Exceptional day"; case 15...24: "Excellent day"; case 6...14: "Good day"; case -5...5: "Building your day"; case -14...(-6): "Needs attention"; default: "Reset your rhythm" }
    }
}
