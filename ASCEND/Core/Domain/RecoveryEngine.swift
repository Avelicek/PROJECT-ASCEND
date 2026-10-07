import Foundation

public struct TrainingLoad: Sendable {
    public let date: Date
    public let contributions: [MuscleContribution]
    public let challengingSets: Double
    public let intensity: Double
    public init(date: Date, contributions: [MuscleContribution], challengingSets: Double, intensity: Double) {
        self.date = date; self.contributions = contributions; self.challengingSets = challengingSets; self.intensity = intensity
    }
}
public struct RecoveryContext: Sendable {
    public var sleepHours: Double?
    public var sleepQuality: Int?
    public var sleepTarget: Double
    public var calorieAdherence: Double?
    public var proteinAdherence: Double?
    public var tolerance: Double
    public var historyDays: Int
    public var trainingSessions: Int
    public init(sleepHours: Double? = nil, sleepQuality: Int? = nil, sleepTarget: Double = 8,
                calorieAdherence: Double? = nil, proteinAdherence: Double? = nil, tolerance: Double = 1, historyDays: Int = 0, trainingSessions: Int = 0) {
        self.sleepHours = sleepHours; self.sleepQuality = sleepQuality; self.sleepTarget = sleepTarget
        self.calorieAdherence = calorieAdherence; self.proteinAdherence = proteinAdherence
        self.tolerance = tolerance; self.historyDays = historyDays
        self.trainingSessions = trainingSessions
    }
}
public struct MuscleRecovery: Sendable, Identifiable {
    public let muscle: Muscle
    public let recoveryPercent: Double
    public let load: Double
    public let fatigue: Double
    public let lastTrainedAt: Date?
    public let estimatedRecoveryTime: Date?
    public let confidence: Confidence
    public var id: String { muscle.rawValue }
}
public enum ReadinessState: String, Sendable { case primed, ready, recovering, fatigued }
public struct ReadinessReport: Sendable {
    public let percent: Double?
    public let state: ReadinessState?
    public let muscles: [MuscleRecovery]
    public let confidence: Confidence
}
public struct RecoveryConfiguration: Sendable {
    public var baseHalfLifeHours: Double = 24
    public var loadPerChallengingSet: Double = 9
    public init() {}
}
public struct RecoveryEngine: Sendable {
    public let configuration: RecoveryConfiguration
    public init(configuration: RecoveryConfiguration = .init()) { self.configuration = configuration }
    public func evaluate(loads: [TrainingLoad], context: RecoveryContext, now: Date) -> ReadinessReport {
        let sleep = context.sleepHours.map { FitnessMath.clamp($0 / max(1, context.sleepTarget), 0...1) }
        let quality = context.sleepQuality.map { FitnessMath.clamp(Double($0) / 5, 0...1) }
        let protein = context.proteinAdherence.map { FitnessMath.clamp($0, 0...1) }
        let calories = context.calorieAdherence.map { FitnessMath.clamp($0, 0...1) }
        let support = FitnessMath.average([sleep, quality, protein, calories].compactMap { $0 }) ?? 0.65
        let halfLife = max(1, configuration.baseHalfLifeHours) * (1.4 - 0.5 * support) / FitnessMath.clamp(context.tolerance, 0.75...1.25)
        let usable = loads.filter { $0.date <= now && $0.date >= now.addingTimeInterval(-14 * 86400) }
        // Overlapping sessions accumulate decaying load. No rep count maps directly to recovery time.
        let supported = sleep != nil && quality != nil && protein != nil && calories != nil
        let confidence: Confidence = supported && context.historyDays >= 14 && context.trainingSessions >= 6 ? .medium : .low
        let muscles = Muscle.allCases.map { muscle in
            let sessions = usable.compactMap { load -> (Date, Double)? in
                let weight = load.contributions.filter { $0.muscle == muscle }.map { max(0, $0.fraction) }.reduce(0, +)
                guard weight > 0 else { return nil }
                let raw = FitnessMath.clamp(load.challengingSets, 0...40) * min(weight, 1) *
                    FitnessMath.clamp(load.intensity, 0.25...1.5) * max(0, configuration.loadPerChallengingSet)
                guard raw > 0 else { return nil }
                let hours = max(0, now.timeIntervalSince(load.date) / 3600)
                return (load.date, raw * pow(0.5, hours / halfLife))
            }
            let fatigue = FitnessMath.clamp(sessions.map { $0.1 }.reduce(0, +), 0...100)
            let rawLoad = usable.reduce(0.0) { total, entry in
                let fraction = min(1, entry.contributions.filter { $0.muscle == muscle }.map { max(0, $0.fraction) }.reduce(0, +))
                return total + FitnessMath.clamp(entry.challengingSets, 0...40) * fraction * FitnessMath.clamp(entry.intensity, 0.25...1.5) * max(0, configuration.loadPerChallengingSet)
            }
            let hoursToReady = fatigue > 15 ? halfLife * log2(fatigue / 15) : 0
            return MuscleRecovery(muscle: muscle, recoveryPercent: 100 - fatigue, load: rawLoad, fatigue: fatigue,
                                  lastTrainedAt: sessions.map { $0.0 }.max(),
                                  estimatedRecoveryTime: sessions.isEmpty ? nil : now.addingTimeInterval(hoursToReady * 3600),
                                  confidence: confidence)
        }
        let observed = !usable.isEmpty || sleep != nil
        let muscleScore = FitnessMath.average(muscles.map(\.recoveryPercent)) ?? 100
        let tired = muscles.map(\.recoveryPercent).min() ?? 100
        let recovery = muscleScore * 0.7 + tired * 0.3
        let percent = observed ? FitnessMath.clamp(recovery * 0.7 + support * 100 * 0.3, 0...100) : nil
        let state = percent.map { $0 >= 90 ? ReadinessState.primed : $0 >= 75 ? .ready : $0 >= 50 ? .recovering : .fatigued }
        return ReadinessReport(percent: percent, state: state, muscles: muscles, confidence: confidence)
    }
}
