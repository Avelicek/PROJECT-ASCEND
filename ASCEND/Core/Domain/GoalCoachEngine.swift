import Foundation

public struct GoalNegotiation: Sendable {
    public var requiredPace: Double?
    public var proposedPace: Double?
    public var proposedDate: Date?
    public var calorieAdjustment: Double = 0
    public var headline: String
    public var explanation: String
    public var canAdjust = false
}

/// A bounded plan experiment, never an inferred metabolism or guaranteed deadline.
public struct GoalCoachEngine: Sendable {
    public init() {}
    public func negotiate(projection: GoalProjection, deadline: Date?, faster: Bool,
                          calories: Double, fuelCoverage: Double, protected: Bool,
                          now: Date, policy: DayPolicy) -> GoalNegotiation {
        var result = GoalNegotiation(headline: "Learning your trend", explanation: projection.explanation)
        guard let current = projection.current, let target = projection.target,
              current.isFinite, target.isFinite, current > 0, target > 0,
              calories.isFinite, fuelCoverage.isFinite, abs(target - current) >= 0.15 else {
            if projection.withinGoalRange { result.headline = "You're at your goal"; result.explanation = "Keep a steady routine and review a maintenance goal." }
            return result
        }
        let gaining = target > current
        let limit = min(gaining ? 0.35 : 0.5, current * 0.005)
        let distance = abs(target - current)
        if let deadline {
            let days = Double(policy.calendar.dateComponents([.day], from: policy.start(of: now), to: policy.start(of: deadline)).day ?? 0)
            guard days > 0 else { result.headline = "Choose a future date"; result.explanation = "A deadline needs time for a gradual change."; return result }
            result.requiredPace = distance / (days / 7)
        }
        guard projection.confidence != .low, let weekly = projection.weeklyChange,
              weekly.isFinite, abs(weekly) >= 0.03, weekly * (target - current) > 0 else { return result }
        let observed = abs(weekly)
        let requested = result.requiredPace ?? (faster ? observed * 1.2 : observed)
        let proposed = min(limit, requested)
        result.proposedPace = proposed
        result.proposedDate = policy.adding(days: max(1, Int(ceil(distance / proposed * 7))), to: now)
        if requested > limit {
            result.headline = "That date asks for too much"
            result.explanation = "Your request needs \(requested.formatted(.number.precision(.fractionLength(2)))) kg/week. I would plan no faster than \(limit.formatted(.number.precision(.fractionLength(2)))) kg/week, then review the trend. This is a planning limit, not a promise."
        } else {
            result.headline = requested > observed + 0.01 ? "We can try a gradual adjustment" : "Your current pace is enough"
            result.explanation = "Your recent pace is \(observed.formatted(.number.precision(.fractionLength(2)))) kg/week. \(deadline == nil ? "Let's review it after two weeks." : "The requested date needs about \(requested.formatted(.number.precision(.fractionLength(2)))) kg/week.")"
        }
        guard !protected else { result.headline = "Recovery comes first"; result.explanation = "Keep the current fuel plan while recovering. Revisit your deadline when you feel well."; return result }
        guard requested > observed + 0.01 else { return result }
        guard fuelCoverage >= 0.75 else { result.explanation += " First meet your current fuel target more consistently; I won't raise it while coverage is low."; return result }
        // No automatic restriction for weight loss. A pace/date plan can still be saved.
        result.calorieAdjustment = gaining && calories >= 1500 && calories <= 4900 ? 100 : 0
        result.canAdjust = proposed > observed + 0.01
        return result
    }
}
