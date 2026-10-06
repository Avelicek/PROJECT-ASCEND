import Foundation

public struct SetPerformance: Codable, Sendable {
    public let reps: Int
    public let kilograms: Double
    public let seconds: Double
    public let distanceMeters: Double
    public init(reps: Int, kilograms: Double = 0, seconds: Double = 0, distanceMeters: Double = 0) {
        self.reps = max(0, reps); self.kilograms = max(0, kilograms); self.seconds = max(0, seconds)
        self.distanceMeters = max(0, distanceMeters)
    }
}
public struct RecordCandidate: Sendable {
    public let kind: RecordKind
    public let value: Double
}
public struct WorkoutEngine: Sendable {
    public init() {}
    public func volume(_ sets: [SetPerformance]) -> Double { sets.reduce(0) { $0 + $1.kilograms * Double($1.reps) } }
    public func recordCandidates(_ sets: [SetPerformance]) -> [RecordCandidate] {
        let working = sets.filter { $0.reps > 0 }
        return [
            .init(kind: .weight, value: working.map(\.kilograms).max() ?? 0),
            .init(kind: .reps, value: Double(working.map(\.reps).max() ?? 0)),
            .init(kind: .volume, value: volume(working)),
            .init(kind: .estimatedOneRepMax, value: working.filter { $0.reps <= 12 && $0.kilograms > 0 }
                .map { $0.kilograms * (1 + Double($0.reps) / 30) }.max() ?? 0)
        ].filter { $0.value > 0 && $0.value.isFinite }
    }
    public func newRecords(sets: [SetPerformance], previous: [RecordKind: Double]) -> [RecordCandidate] {
        recordCandidates(sets).filter { $0.value > previous[$0.kind, default: 0] }
    }
    public func load(sets: [SetPerformance], mode: TrackingMode, quick: Bool) -> Double {
        switch mode {
        case .reps: return min(10, Double(sets.map(\.reps).reduce(0, +)) / 15)
        case .weightAndReps: return Double(sets.filter { $0.reps > 0 }.count)
        case .duration, .distance: return min(10, sets.map(\.seconds).reduce(0, +) / 600)
        }
    }
}
