import Foundation

public enum CoachAction: String, Codable, Sendable { case checkIn, nutrition, workout, resume, recovery, objectives, sleep, weight }
public struct NextBestAction: Sendable {
    public let action: CoachAction
    public let title: String
    public let reason: String
    public let button: String
    public let opportunity: Int?
}
public struct CoachExerciseFact: Codable, Sendable {
    public var id: String
    public var name: String
    public var date: Date
    public var kilograms: Double
    public var reps: [Int]
    public var rpe: [Double]
    public var recommendation: String
}
public struct CoachContext: Codable, Sendable {
    public var date: Date
    public var dailyELO: Int
    public var components: [ScoreComponent]
    public var checkInCompleted: Bool
    public var activeWorkout: Bool
    public var sickMode: Bool
    public var sleepMode: Bool
    public var readiness: Double?
    public var recoveryConfidence: Confidence
    public var sleepHours: Double?
    public var calories: Double?
    public var calorieGoal: Double
    public var protein: Double?
    public var proteinGoal: Double
    public var weight: Double?
    public var targetWeight: Double?
    public var projectionWeeks: [Int]?
    public var projectionConfidence: Confidence
    public var projectionReason: String
    public var workoutTitle: String?
    public var workoutReasons: [String]
    public var muscleLoad: [String: Double]
    public var muscleRecovery: [String: Double]
    public var exercises: [CoachExerciseFact]
    public var completedObjectives: Int
    public var dueObjectives: Int
}
public struct CoachAnswer: Sendable {
    public var observed: [String]
    public var estimates: [String]
    public var recommendation: String
    public var confidence: Confidence
}
public struct CoachReasoningEngine: Sendable {
    public init() {}
    public func answer(_ question: String, context c: CoachContext) -> CoachAnswer {
        let q = question.lowercased()
        var answer = CoachAnswer(observed: [], estimates: [], recommendation: "", confidence: .low)
        if q.contains("elo") || q.contains("score") {
            answer.observed = ["Today's ELO: \(c.dailyELO > 0 ? "+" : "")\(c.dailyELO)."] + c.components.map { "\($0.label): \($0.points > 0 ? "+" : "")\($0.points)." }
            answer.recommendation = "Improve the recorded components you can act on. The score is calculated locally; a coach explanation cannot change it."
            answer.confidence = .high
        } else if q.contains("eat") || q.contains("food") || q.contains("nutrition") || q.contains("calorie") {
            if let calories = c.calories { answer.observed.append("\(Int(calories)) / \(Int(c.calorieGoal)) kcal logged today.") }
            if let protein = c.protein { answer.observed.append("\(Int(protein)) / \(Int(c.proteinGoal)) g protein logged today.") }
            answer.recommendation = c.calories.map { "Your configured target has \(Int(max(0, c.calorieGoal - $0))) kcal remaining. Log what you actually eat; include a protein source if protein coverage is low." } ?? "Log today's intake first so ASCEND can compare it with your configured calorie and protein goals."
            answer.confidence = c.calories == nil ? .low : .medium
        } else if q.contains("reach") || q.contains("goal") || q.contains("december") || q.contains("weight") {
            answer.observed = [c.weight.map { "Latest weigh-in: \($0.formatted()) kg." } ?? "No recent weigh-in."]
            if let target = c.targetWeight { answer.observed.append("Configured target: \(target.formatted()) kg.") }
            if let weeks = c.projectionWeeks, weeks.count == 2 { answer.estimates.append("Estimated \(weeks[0])–\(weeks[1]) weeks to your configured target.") }
            answer.estimates.append(c.projectionReason)
            answer.recommendation = "Keep comparable morning weigh-ins and consistent intake. Use the projected date range to judge a deadline; ASCEND cannot guarantee a future result."
            answer.confidence = c.projectionConfidence
        } else if q.contains("increase") || q.contains("bench") || q.contains("press") || q.contains("progression") {
            let mentioned = c.exercises.first { q.contains($0.name.lowercased()) || q.contains($0.id.replacingOccurrences(of: "_", with: " ")) }
            let entry = mentioned ?? c.exercises.first { q.contains("bench") && ($0.name.lowercased().contains("bench") || $0.name.lowercased().contains("chest press")) }
            if let entry {
                answer.observed = ["\(entry.name): \(entry.kilograms.formatted()) kg · \(entry.reps.map(String.init).joined(separator: " / ")) reps."]
                if !entry.rpe.isEmpty { answer.observed.append("Recorded RPE: \(entry.rpe.map { $0.formatted() }.joined(separator: " / ")).") }
                answer.recommendation = entry.recommendation; answer.confidence = entry.rpe.isEmpty ? .low : .medium
            } else { answer.recommendation = "Log a comparable session for that exercise. Without observed loads and reps I cannot recommend a weight increase." }
        } else if q.contains("recovery") || q.contains("chest") || q.contains("enough") || q.contains("remove") {
            let muscle = c.muscleLoad.keys.sorted().first { q.contains($0.lowercased()) } ?? (q.contains("chest") ? "Chest" : nil)
            if let muscle {
                if let load = c.muscleLoad[muscle] { answer.estimates.append("\(muscle): \(load.formatted(.number.precision(.fractionLength(1)))) weighted stimulus units today, including quick activities.") }
                if let recovery = c.muscleRecovery[muscle] { answer.estimates.append("\(muscle): \(Int(recovery.rounded()))% modeled recovery.") }
            } else if let readiness = c.readiness { answer.estimates.append("Readiness: \(Int(readiness.rounded()))%, based on recorded training and recovery support.") }
            answer.recommendation = c.workoutReasons.joined(separator: " "); answer.confidence = c.recoveryConfidence
        } else if q.contains("train") || q.contains("legs") || q.contains("stop") || q.contains("workout") {
            if let hours = c.sleepHours { answer.observed.append("Last recorded sleep: \(hours.formatted()) hours.") }
            if c.sickMode || c.sleepMode { answer.recommendation = "Recovery takes priority while your recorded mode is active." }
            else if c.activeWorkout { answer.recommendation = "Review your current session and effort ratings. Stop or reduce work when technique breaks down; the live coach offers bounded rest/load adjustments when comparable reps drop." }
            else { answer.recommendation = (c.workoutTitle.map { "Today's plan: \($0). " } ?? "Recover today. ") + c.workoutReasons.joined(separator: " ") }
            answer.confidence = c.recoveryConfidence
        } else {
            answer.observed = ["\(c.completedObjectives) / \(c.dueObjectives) objectives completed today."]
            answer.recommendation = "Ask about today's training, a recorded exercise, recovery, nutrition, goal ETA or ELO. I use your local records; injuries, medical symptoms and unlogged activities are outside this context."
        }
        return answer
    }
}
