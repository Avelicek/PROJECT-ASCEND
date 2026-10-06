import Foundation

public struct ProgressReport: Sendable {
    public let actualWeight: Double?
    public let trendWeight: Double?
    public let goalProgress: Double?
    public let momentumPercent: Double?
    public let confidence: Confidence
    public let trend: [WeightSample]
}
public struct ProgressEngine: Sendable {
    public init() {}
    public func goalProgress(start: Double, target: Double, current: Double) -> Double? {
        guard [start, target, current].allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
        guard abs(target - start) > 0.001 else { return abs(current - target) < 0.1 ? 1 : 0 }
        return FitnessMath.clamp((current - start) / (target - start), 0...1)
    }
    // Average duplicate days first, then use a calendar-based trailing window.
    public func trend(samples: [WeightSample], policy: DayPolicy) -> [WeightSample] {
        let usable = samples.filter { $0.kilograms.isFinite && $0.kilograms > 0 }
        let days = Dictionary(grouping: usable) { policy.start(of: $0.date) }
            .map { WeightSample(date: $0.key, kilograms: $0.value.map(\.kilograms).reduce(0, +) / Double($0.value.count)) }
            .sorted { $0.date < $1.date }
        return days.map { point in
            let cutoff = policy.adding(days: -6, to: point.date)
            let window = days.filter { $0.date >= cutoff && $0.date <= point.date }
            return WeightSample(date: point.date, kilograms: window.map(\.kilograms).reduce(0, +) / Double(window.count))
        }
    }
    public func report(samples: [WeightSample], start: Double?, target: Double?, desiredWeeklyChange: Double,
                       window: EvaluationWindow = .week, now: Date, policy: DayPolicy) -> ProgressReport {
        let eligible = samples.filter { $0.date <= now && $0.kilograms.isFinite && $0.kilograms > 0 }
        let smoothed = trend(samples: eligible, policy: policy)
        let latest = smoothed.last
        let cutoff = policy.adding(days: -window.rawValue, to: policy.start(of: now))
        let previous = smoothed.last { $0.date <= cutoff }
        let fresh = latest.map { $0.date >= policy.adding(days: -7, to: policy.start(of: now)) } ?? false
        var momentum: Double?
        if fresh, let latest, let previous, let target, let start, abs(target - start) > 0.001,
           previous.date >= policy.adding(days: -window.rawValue - 7, to: policy.start(of: now)),
           desiredWeeklyChange.isFinite, abs(desiredWeeklyChange) > 0.001 {
            let expected = abs(desiredWeeklyChange) * Double(window.rawValue) / 7
            let direction = target >= start ? 1.0 : -1.0
            momentum = FitnessMath.clamp((latest.kilograms - previous.kilograms) * direction / expected * 100, -100...100)
        }
        let recentDays = smoothed.filter { $0.date >= policy.adding(days: -27, to: policy.start(of: now)) }.count
        let confidence: Confidence = !fresh || recentDays < 4 ? .low : recentDays < 12 ? .medium : .high
        let goal = latest.flatMap { latest in
            start.flatMap { start in target.flatMap { goalProgress(start: start, target: $0, current: latest.kilograms) } }
        }
        return ProgressReport(actualWeight: eligible.sorted { $0.date < $1.date }.last?.kilograms,
                              trendWeight: latest?.kilograms, goalProgress: goal, momentumPercent: momentum,
                              confidence: confidence, trend: smoothed)
    }
}
