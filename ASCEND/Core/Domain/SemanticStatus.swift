import Foundation

/// Presentation meaning only. Does not change readiness, progression or scoring rules.
public enum SemanticStatus: String, CaseIterable, Sendable {
    case excellent, good, watch, low, unknown

    public var title: String { rawValue.capitalized }

    public static func recovery(_ percent: Double?) -> Self {
        guard let percent, percent.isFinite else { return .unknown }
        return percent >= 95 ? .excellent : percent >= 85 ? .good : percent >= 50 ? .watch : .low
    }

    public static func fatigue(_ value: Double?) -> Self {
        guard let value, value.isFinite else { return .unknown }
        return value >= 50 ? .low : value >= 15 ? .watch : .good
    }

    public static func momentum(_ value: Double?) -> Self {
        guard let value, value.isFinite else { return .unknown }
        return value >= 20 ? .excellent : value > 0 ? .good : value == 0 ? .watch : .low
    }

    public static func confidence(_ value: Confidence) -> Self {
        switch value { case .high: .good; case .medium: .watch; case .low: .unknown }
    }

    /// A partly logged day asks for attention; it is not a failed nutrition day.
    public static func dailyCompletion(_ fraction: Double?) -> Self {
        guard let fraction, fraction.isFinite else { return .unknown }
        return fraction >= 1 ? .excellent : fraction >= 0.85 ? .good : .watch
    }

    public static func sleep(hours: Double?, target: Double, quality: Int?) -> Self {
        guard let hours, hours.isFinite, target.isFinite, target > 0 else { return .unknown }
        if hours < 4 || (quality.map { $0 <= 1 } ?? false) { return .low }
        if hours < 6 || (quality.map { $0 <= 2 } ?? false) { return .watch }
        return hours >= target && (quality.map { $0 >= 4 } ?? false) ? .excellent : hours >= target * 0.85 ? .good : .watch
    }
}
