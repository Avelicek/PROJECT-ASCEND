import Foundation

public struct DailyResult: Sendable {
    public let grade: String
    public let status: String
    public let momentum: Double?
    public let elo: ELOResult
    public let explanation: [String]
}
public struct DailyGameEngine: Sendable {
    public init() {}
    public func evaluate(_ input: ELOInput, previousELO: Int, momentum: Double?, confidence: Confidence) -> DailyResult {
        presentation(ELOEngine().evaluate(input, previousELO: previousELO), momentum: momentum, confidence: confidence)
    }
    public func presentation(_ result: ELOResult, momentum: Double?, confidence: Confidence) -> DailyResult {
        let positive = result.components.filter { $0.points > 0 }, negative = result.components.filter { $0.points < 0 }
        let categories = Set(positive.map { $0.category.rawValue })
        let grade = result.delta < 0 ? "D" : negative.isEmpty && categories.count >= 3 ? "A" : result.delta > 0 && negative.isEmpty ? "B" : "C"
        return .init(grade: grade, status: result.delta > 0 ? "PROGRESS" : result.delta < 0 ? "DOWNGRADE" : "STEADY",
            momentum: confidence == .low ? nil : momentum, elo: result, explanation: Array((negative + positive).prefix(4).map(\.label)))
    }
}
public struct StreakEngine: Sendable {
    public init() {}
    public func daily(qualifyingDays: [Date], now: Date, policy: DayPolicy) -> Int {
        let days = Set(qualifyingDays.filter { $0 <= now }.map { policy.start(of: $0) })
        var cursor = policy.start(of: now)
        if !days.contains(cursor) { cursor = policy.adding(days: -1, to: cursor) }
        var count = 0
        while days.contains(cursor) { count += 1; cursor = policy.adding(days: -1, to: cursor) }
        return count
    }
    // Consecutive weeks with two distinct training days: rest never breaks the streak.
    public func workoutWeeks(dates: [Date], now: Date, policy: DayPolicy) -> Int {
        let calendar = policy.calendar
        func week(_ date: Date) -> Date { calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? policy.start(of: date) }
        let grouped = Dictionary(grouping: Set(dates.filter { $0 <= now }.map { policy.start(of: $0) })) { week($0) }
        let qualified = Set(grouped.filter { $0.value.count >= 2 }.map(\.key))
        var cursor = week(now)
        if !qualified.contains(cursor) { cursor = policy.adding(days: -7, to: cursor) }
        var count = 0
        while qualified.contains(cursor) { count += 1; cursor = policy.adding(days: -7, to: cursor) }
        return count
    }
}
public struct WeeklyRecap: Sendable {
    public let eloDelta: Int
    public let previousRank: Rank
    public let currentRank: Rank
    public let workouts: Int
    public let trainingDays: Int
    public let fuelDays: Int
    public let fuelAdherence: Double?
    public let trendChange: Double?
    public let momentum: Double?
    public let records: Int
    public let objectivesCompleted: Int
    public let objectivesDue: Int
    public let recoveryProtected: Int
}
