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

        let maximumWeight = working.reduce(0.0) { current, set in
            max(current, set.kilograms)
        }
        let maximumReps = working.reduce(0) { current, set in
            max(current, set.reps)
        }
        let totalVolume = volume(working)

        var maximumEstimatedOneRepMax = 0.0
        for set in working where set.reps <= 12 && set.kilograms > 0 {
            let repFactor = 1.0 + Double(set.reps) / 30.0
            let estimate = set.kilograms * repFactor
            maximumEstimatedOneRepMax = max(maximumEstimatedOneRepMax, estimate)
        }

        let candidates: [RecordCandidate] = [
            RecordCandidate(kind: .weight, value: maximumWeight),
            RecordCandidate(kind: .reps, value: Double(maximumReps)),
            RecordCandidate(kind: .volume, value: totalVolume),
            RecordCandidate(kind: .estimatedOneRepMax, value: maximumEstimatedOneRepMax)
        ]
        return candidates.filter { candidate in
            candidate.value > 0 && candidate.value.isFinite
        }
    }
    public func newRecords(sets: [SetPerformance], previous: [RecordKind: Double]) -> [RecordCandidate] {
        recordCandidates(sets).filter { $0.value > previous[$0.kind, default: 0] }
    }
    public func load(sets: [SetPerformance], mode: TrackingMode, quick: Bool) -> Double {
        switch mode {
        case .reps: return quick ? min(10, Double(sets.map(\.reps).reduce(0, +)) / 15) : Double(sets.filter { $0.reps > 0 }.count)
        case .weightAndReps: return Double(sets.filter { $0.reps > 0 }.count)
        case .duration, .distance: return min(10, sets.map(\.seconds).reduce(0, +) / 600)
        }
    }
}
