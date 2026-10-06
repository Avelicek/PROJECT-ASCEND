import Foundation

public struct PersonalBaseline: Sendable {
    public let days: Int
    public let observedWeightDays: Int
    public let observedNutritionDays: Int
    public let averageWeight: Double?
    public let averageCalories: Double?
    public let averageProtein: Double?
    public let averageSleep: Double?
    public let trainingDays: Int
    public let confidence: Confidence
}
public struct PersonalModel: Sendable {
    public let windows: [PersonalBaseline]
    public var recoveryTolerance: Double { 1 } // Learned calibration awaits enough comparable training outcomes.
    public init(weights: [WeightSample], nutrition: [NutritionSample], sleep: [SleepSample], workoutDates: [Date],
                now: Date, policy: DayPolicy) {
        windows = [7, 14, 28, 90].map { days in
            let lower = policy.adding(days: -(days - 1), to: policy.start(of: now))
            let w = weights.filter { $0.date >= lower && $0.date <= now && $0.kilograms > 0 }
            let n = nutrition.filter { $0.date >= lower && $0.date <= now }
            let s = sleep.filter { $0.date >= lower && $0.date <= now }
            let wDays = Set(w.map { policy.key(for: $0.date) }).count
            let nDays = Set(n.map { policy.key(for: $0.date) }).count
            let usefulCoverage = Double(min(wDays, nDays)) / Double(days)
            return PersonalBaseline(days: days, observedWeightDays: wDays, observedNutritionDays: nDays,
                                    averageWeight: FitnessMath.average(w.map(\.kilograms)),
                                    averageCalories: FitnessMath.average(n.map(\.calories)),
                                    averageProtein: FitnessMath.average(n.map(\.protein)),
                                    averageSleep: FitnessMath.average(s.map(\.hours)),
                                    trainingDays: Set(workoutDates.filter { $0 >= lower && $0 <= now }.map { policy.key(for: $0) }).count,
                                    confidence: usefulCoverage < 0.35 ? .low : usefulCoverage < 0.75 || days < 28 ? .medium : .high)
        }
    }
}
