import SwiftUI

enum BodyViewMode: String, CaseIterable, Identifiable, Sendable {
    case front = "Front", back = "Back"
    var id: String { rawValue.lowercased() }
}

enum AnatomyMetricMode: String, CaseIterable, Identifiable, Sendable {
    case recovery = "Recovery", load = "Load", fatigue = "Fatigue"
    var id: String { rawValue.lowercased() }
    func value(_ state: RegionVisualization) -> Double? {
        switch self { case .recovery: state.percent; case .load: state.load; case .fatigue: state.fatigue }
    }
    func tint(_ state: RegionVisualization, maximumLoad: Double) -> Color {
        guard let value = value(state) else { return AppColor.muted }
        switch self {
        case .recovery: return SemanticStatus.recovery(value).tint
        case .load: return (value / max(1, maximumLoad) >= 0.7 ? SemanticStatus.watch : .good).tint
        case .fatigue: return SemanticStatus.fatigue(value).tint
        }
    }
}

enum BodyRegion: String, CaseIterable, Identifiable, Sendable {
    case chest = "Chest", shoulders = "Shoulders", arms = "Arms", back = "Back"
    case core = "Core", glutes = "Glutes", legs = "Legs", calves = "Calves"
    var id: String { rawValue.lowercased() }
    func isVisible(in mode: BodyViewMode) -> Bool {
        switch self {
        case .chest, .core: mode == .front
        case .back, .glutes: mode == .back
        default: true
        }
    }
    func recovery(in report: ReadinessReport) -> Double? { visualization(in: report).percent }
    func tint(in report: ReadinessReport) -> Color { SemanticStatus.recovery(visualization(in: report).percent).tint }
    func visualization(in report: ReadinessReport) -> RegionVisualization {
        let muscles = report.muscles.filter { $0.muscle.group == rawValue }
        let logged = muscles.filter { $0.lastTrainedAt != nil && $0.recoveryPercent.isFinite }
        let weakest = logged.min { $0.recoveryPercent < $1.recoveryPercent }
        let percent = weakest.map { min(100, max(0, $0.recoveryPercent)) }
        let confidence = logged.map(\.confidence).min { $0.level < $1.level }
        return RegionVisualization(region: self, percent: percent, confidence: confidence,
            load: logged.isEmpty ? nil : logged.reduce(0) { $0 + max(0, $1.load.isFinite ? $1.load : 0) },
            fatigue: logged.isEmpty ? nil : logged.map { max(0, $0.fatigue.isFinite ? $0.fatigue : 0) }.max(),
            loggedMuscles: logged.count, totalMuscles: muscles.count, limitingMuscle: weakest?.muscle.title,
            lastTrainedAt: logged.compactMap(\.lastTrainedAt).max(), estimatedReadyAt: logged.compactMap(\.estimatedRecoveryTime).max())
    }
}

private extension Confidence {
    var level: Int { switch self { case .low: 0; case .medium: 1; case .high: 2 } }
}

enum RegionPhase: String, Sendable {
    case unknown = "Unknown", recovering = "Recovering", rebuilding = "Rebuilding", ready = "Ready"
    var tint: Color {
        switch self {
        case .unknown: AppColor.muted
        case .recovering: AppColor.negative
        case .rebuilding: AppColor.warning
        case .ready: AppColor.positive
        }
    }
}

struct RegionVisualization: Identifiable, Sendable {
    let region: BodyRegion
    let percent: Double?
    let confidence: Confidence?
    let load: Double?
    let fatigue: Double?
    let loggedMuscles: Int
    let totalMuscles: Int
    let limitingMuscle: String?
    let lastTrainedAt: Date?
    let estimatedReadyAt: Date?
    var id: String { region.id }
    var phase: RegionPhase {
        guard let percent else { return .unknown }
        return percent < 50 ? .recovering : percent < 85 ? .rebuilding : .ready
    }
    var accessibilitySummary: String {
        guard let percent else { return "Unknown, no training load logged" }
        return "\(Int(percent.rounded())) percent estimated recovery, \(phase.rawValue), \(confidence?.rawValue ?? "low") confidence"
    }
}

// The presenter owns selection rules independently of any 2D or future 3D renderer.
struct AnatomyPresentation: Equatable {
    private(set) var selected: BodyRegion = .chest
    private(set) var mode: BodyViewMode = .front
    mutating func select(_ region: BodyRegion) {
        selected = region
        if !region.isVisible(in: mode) { mode = mode == .front ? .back : .front }
    }
    mutating func show(_ newMode: BodyViewMode) {
        mode = newMode
        if !selected.isVisible(in: mode) { selected = mode == .front ? .chest : .back }
    }
}
