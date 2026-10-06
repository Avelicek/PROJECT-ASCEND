import Foundation

public enum BrainSource: String, Codable, Sendable { case deterministic, onDevice }
public enum RecommendedAction: String, Codable, CaseIterable, Sendable {
    case logWeight, logSleep, logNutrition, reviewRecovery, maintainConsistency, reviewGoals
    public var title: String {
        switch self {
        case .logWeight: "Log body weight"
        case .logSleep: "Log your sleep"
        case .logNutrition: "Log today's nutrition"
        case .reviewRecovery: "Review recovery before training"
        case .maintainConsistency: "Keep your logging rhythm"
        case .reviewGoals: "Review your goals"
        }
    }
}
public struct BrainContext: Codable, Sendable {
    public let trendWeight: Double?
    public let momentum: Double?
    public let readiness: Double?
    public let calories: Double?
    public let protein: Double?
    public let confidence: Confidence
    public let observedWeightDays: Int
    public let allowedActions: [RecommendedAction]
    public init(trendWeight: Double?, momentum: Double?, readiness: Double?, calories: Double?, protein: Double?,
                confidence: Confidence, observedWeightDays: Int, allowedActions: [RecommendedAction]) {
        self.trendWeight = trendWeight; self.momentum = momentum; self.readiness = readiness
        self.calories = calories; self.protein = protein; self.confidence = confidence
        self.observedWeightDays = observedWeightDays; self.allowedActions = allowedActions
    }
}
public struct BrainRecommendation: Codable, Sendable, Identifiable {
    public let action: RecommendedAction
    public var id: String { action.rawValue }
    public init(action: RecommendedAction) { self.action = action }
}
public struct BrainInsight: Codable, Sendable {
    public let headline: String
    public let summary: String
    public let confidence: Confidence
    public let recommendations: [BrainRecommendation]
    public let warnings: [String]
    public let source: BrainSource
    public init(headline: String, summary: String, confidence: Confidence, recommendations: [BrainRecommendation],
                warnings: [String] = [], source: BrainSource) {
        self.headline = headline; self.summary = summary; self.confidence = confidence
        self.recommendations = recommendations; self.warnings = warnings; self.source = source
    }
}
public protocol BrainProvider: Sendable { func analyze(_ context: BrainContext) async throws -> BrainInsight }
public struct DeterministicBrainProvider: BrainProvider {
    public init() {}
    public func insight(_ context: BrainContext) -> BrainInsight {
        let headline: String
        let summary: String
        let action: RecommendedAction
        if context.observedWeightDays < 4 {
            headline = "Build your baseline."
            summary = "A few more weight entries will reveal your direction. Keep logging at a rhythm you can sustain."
            action = .logWeight
        } else if let readiness = context.readiness, readiness < 60 {
            headline = "Let recovery lead."
            summary = "Recent training and recovery inputs suggest an easier day. Review the muscle breakdown before your next session."
            action = .reviewRecovery
        } else if let momentum = context.momentum, momentum < 0 {
            headline = "Check the bigger picture."
            summary = "Your smoothed weight trend is moving away from your goal. Review intake and consistency before changing your plan."
            action = .reviewGoals
        } else {
            headline = "Consistency compounds."
            summary = "Keep training, nutrition and sleep in the same picture. Your next useful insight comes from repeatable habits."
            action = .maintainConsistency
        }
        return BrainInsight(headline: headline, summary: summary, confidence: context.confidence,
                            recommendations: context.allowedActions.contains(action) ? [.init(action: action)] : [], source: .deterministic)
    }
    public func analyze(_ context: BrainContext) async throws -> BrainInsight { insight(context) }
}
public struct FitnessBrain: Sendable {
    private let provider: (any BrainProvider)?
    private let fallback = DeterministicBrainProvider()
    public init(provider: (any BrainProvider)? = nil) { self.provider = provider }
    public func analyze(_ context: BrainContext) async -> BrainInsight {
        guard let provider else { return fallback.insight(context) }
        do { return try await provider.analyze(context) } catch { return fallback.insight(context) }
    }
}
