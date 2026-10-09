import Foundation

public struct GoalProjection: Sendable {
    public var target: Double?
    public var current: Double?
    public var weeklyChange: Double?
    public var earliest: Date?
    public var latest: Date?
    public var confidence: Confidence
    public var explanation: String
    public var observedDays: Int
    public var weeks: ClosedRange<Int>?
}
public struct ProjectionEngine: Sendable {
    public init() {}
    public func weight(samples: [WeightSample], target: Double?, now: Date, policy: DayPolicy) -> GoalProjection {
        let lower = policy.adding(days: -20, to: policy.start(of: now))
        let grouped = Dictionary(grouping: samples.filter { $0.date >= lower && $0.date <= now && $0.kilograms.isFinite && $0.kilograms > 0 }) { policy.start(of: $0.date) }
        let days = grouped.map { WeightSample(date: $0.key, kilograms: FitnessMath.average($0.value.map(\.kilograms)) ?? 0) }.sorted { $0.date < $1.date }
        var result = GoalProjection(target: target, current: days.last?.kilograms, weeklyChange: nil, earliest: nil, latest: nil,
            confidence: .low, explanation: "Learning your trend · \(max(0, 6 - days.count)) more distinct weigh-ins recommended", observedDays: days.count, weeks: nil)
        guard let target, target.isFinite, target > 0, let first = days.first, let last = days.last, days.count >= 6,
              last.date >= policy.adding(days: -3, to: policy.start(of: now)), last.date.timeIntervalSince(first.date) >= 7 * 86400 else { return result }
        let x = days.map { $0.date.timeIntervalSince(first.date) / 86400 }
        let y = days.map(\.kilograms)
        let meanX = FitnessMath.average(x) ?? 0, meanY = FitnessMath.average(y) ?? 0
        let variance = x.reduce(0) { $0 + pow($1 - meanX, 2) }
        guard variance > 0 else { return result }
        let slope = zip(x, y).reduce(0) { $0 + ($1.0 - meanX) * ($1.1 - meanY) } / variance
        let current = meanY + slope * ((now.timeIntervalSince(first.date) / 86400) - meanX)
        result.current = current; result.weeklyChange = slope * 7
        if abs(target - current) < 0.15 { result.explanation = "Your recent trend is within 0.15 kg of the target."; return result }
        guard abs(slope * 7) >= 0.03, abs(slope * 7) <= 1.5, (target - current) * slope > 0 else {
            result.explanation = "Recent trend is flat or moving away from your goal. Review intake and collect more weigh-ins."; return result
        }
        let residual = sqrt(zip(x, y).reduce(0) { $0 + pow($1.1 - (meanY + slope * ($1.0 - meanX)), 2) } / Double(days.count))
        let uncertainty = max(0.25, min(0.8, residual / max(0.05, abs(slope) * 7)))
        let eta = (target - current) / slope
        guard eta <= 730 else { result.explanation = "The current pace is too slow for a useful date estimate."; return result }
        let fast = max(1, eta * (1 - uncertainty)), slow = eta * (1 + uncertainty)
        result.earliest = policy.adding(days: Int(fast.rounded()), to: now)
        result.latest = policy.adding(days: Int(slow.rounded()), to: now)
        result.weeks = max(1, Int(floor(fast / 7)))...max(1, Int(ceil(slow / 7)))
        result.confidence = days.count >= 12 && last.date.timeIntervalSince(first.date) >= 14 * 86400 && uncertainty < 0.4 ? .high : .medium
        result.explanation = "Based on \(days.count) distinct weigh-ins across \(Int(last.date.timeIntervalSince(first.date) / 86400) + 1) days. Dates are a trend estimate, not a promise."
        return result
    }
}
