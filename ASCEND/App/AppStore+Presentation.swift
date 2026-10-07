import Foundation

enum NextActionKind: Equatable { case resume, recover, fuel, weigh, sleep, objectives, train, evaluate }
struct NextActionPresentation {
    let kind: NextActionKind
    let title: String
    let detail: String
    let action: String
}

extension AppStore {
    var weeklyStrengthHighlight: (String, Double)? {
        let lower = policy.adding(days: -6, to: policy.start(of: now))
        let candidates = exercises.filter { $0.trackingMode == .weightAndReps && !$0.bodyweightCapable }
        return candidates.compactMap { exercise -> (String, Double)? in
            let full = exerciseHistory.filter { $0.exerciseID == exercise.catalogID && !$0.quick && $0.date <= now && $0.date >= lower.addingTimeInterval(-42 * 86400) }
            func estimate(_ values: [ExerciseHistory]) -> Double? {
                WorkoutEngine().recordCandidates(values.flatMap { $0.working.map(\.performance) }).first { $0.kind == .estimatedOneRepMax }?.value
            }
            guard let baseline = estimate(full.filter { $0.date < lower }), let recent = estimate(full.filter { $0.date >= lower }), recent > baseline else { return nil }
            return (exercise.name, (recent / baseline - 1) * 100)
        }.max { $0.1 < $1.1 }
    }
    var nextAction: NextActionPresentation {
        if activeWorkout != nil { return .init(kind: .resume, title: "CONTINUE", detail: "Your workout is saved", action: "Resume workout") }
        if brainArchive.settings.enabled && brainDecision.action == .recover { return .init(kind: .recover, title: "RECOVER", detail: brainDecision.warnings.first ?? "Review recorded limits", action: "Review recovery") }
        if !brainArchive.settings.enabled, readiness.confidence != .low, let limited = readiness.muscles.filter({ $0.lastTrainedAt != nil && $0.recoveryPercent < 40 }).min(by: { $0.recoveryPercent < $1.recoveryPercent }) {
            if let recommendation = recommendedRoutine {
                return .init(kind: .train, title: "ALTERNATIVE FOCUS", detail: "\(limited.muscle.group) rebuilding · \(recommendation.title) is an optional alternative", action: "Start \(recommendation.title)")
            }
            return .init(kind: .recover, title: "RECOVER", detail: "\(limited.muscle.group) · \(Int(limited.recoveryPercent.rounded()))% estimated", action: "Review recovery")
        }
        if todayNutrition == nil { return .init(kind: .fuel, title: "FUEL", detail: "Today's totals are unlogged", action: "Log nutrition") }
        if let food = todayNutrition, food.proteinGrams < profile.proteinGoal * 0.9 {
            return .init(kind: .fuel, title: "FUEL", detail: "\(Int(ceil(max(0, profile.proteinGoal - food.proteinGrams)))) g protein to your target", action: "Update nutrition")
        }
        if !weights.contains(where: { policy.sameDay($0.measuredAt, now) }) { return .init(kind: .weigh, title: "WEIGH IN", detail: "No weight logged today", action: "Log body weight") }
        if todaySleep == nil { return .init(kind: .sleep, title: "REST INPUT", detail: "Add last night's sleep", action: "Log sleep") }
        if todayObjectives.contains(where: { $0.completedAt == nil && !$0.recoveryExempt && $0.kindRaw == ObjectiveKind.custom.rawValue }) {
            return .init(kind: .objectives, title: "YOUR OBJECTIVES", detail: "A daily habit is still open", action: "Review objectives")
        }
        if sessions.contains(where: { $0.hasWorkingSets && policy.sameDay($0.evaluationDate, now) }) {
            return .init(kind: .evaluate, title: "WORK RECORDED", detail: "See today's pending rating", action: "Review your day")
        }
        if brainArchive.settings.enabled, let session = brainDecision.session {
            return .init(kind: .train, title: brainDecision.action.title.uppercased(), detail: brainDecision.intensity.title, action: "Start \(session.name)")
        }
        if let routine = nextTrainingRoutine {
            return .init(kind: .train, title: "TRAIN", detail: recommendedRoutine?.reason ?? "Equipment available · check how you feel", action: "Start \(routine.name)")
        }
        return .init(kind: .train, title: "TRAIN", detail: "Choose available exercises in My Gym", action: "Start workout")
    }
}
