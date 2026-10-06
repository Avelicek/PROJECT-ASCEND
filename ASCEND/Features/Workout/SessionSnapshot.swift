import Foundation

struct SessionMuscleFocus: Identifiable {
    let group: String
    let share: Double
    var id: String { group }
}

@MainActor struct SessionSnapshot {
    let workingSets: Int
    let warmupSets: Int
    let volumeKG: Double
    let exertion: Double?
    let focus: [SessionMuscleFocus]
    init(session: WorkoutSession) {
        let sets = session.exercises.flatMap(\.sets)
        let working = sets.filter { !$0.isWarmup }
        workingSets = working.count
        warmupSets = sets.count - working.count
        volumeKG = session.exercises.filter { $0.trackingMode == .weightAndReps || $0.trackingMode == .reps }.reduce(0) { total, entry in
            total + entry.sets.filter { !$0.isWarmup }.reduce(0) { $0 + max(0, $1.weightKG) * Double(max(0, $1.reps)) }
        }
        let rpe = working.compactMap(\.perceivedExertion).filter { $0.isFinite && (1...10).contains($0) }
        exertion = rpe.isEmpty ? nil : rpe.reduce(0, +) / Double(rpe.count)
        var weighted: [String: Double] = [:]
        for entry in session.exercises {
            let count = Double(entry.sets.filter { !$0.isWarmup }.count)
            for contribution in entry.contributions where contribution.fraction.isFinite && contribution.fraction > 0 {
                weighted[contribution.muscle.group, default: 0] += contribution.fraction * count
            }
        }
        let total = weighted.values.reduce(0, +)
        focus = weighted.filter { $0.value > 0 }.map { SessionMuscleFocus(group: $0.key, share: total > 0 ? $0.value / total : 0) }
            .sorted { $0.share == $1.share ? $0.group < $1.group : $0.share > $1.share }
    }
}
