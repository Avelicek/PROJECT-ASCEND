import Foundation

public struct ObjectiveSchedule: Sendable {
    public let cadence: ObjectiveCadence
    public let startsAt: Date
    public let weekdays: [Int] // Gregorian: Sunday = 1.
    public init(cadence: ObjectiveCadence, startsAt: Date, weekdays: [Int] = []) {
        self.cadence = cadence; self.startsAt = startsAt; self.weekdays = weekdays
    }
}
public struct ObjectiveEngine: Sendable {
    public init() {}
    public func isDue(_ schedule: ObjectiveSchedule, on date: Date, policy: DayPolicy) -> Bool {
        guard policy.start(of: date) >= policy.start(of: schedule.startsAt) else { return false }
        switch schedule.cadence {
        case .once: return policy.sameDay(schedule.startsAt, date)
        case .daily: return true
        case .weekly: return policy.calendar.component(.weekday, from: schedule.startsAt) == policy.calendar.component(.weekday, from: date)
        case .weekdays: return schedule.weekdays.contains(policy.calendar.component(.weekday, from: date))
        }
    }
    public func value(kind: ObjectiveKind, manual: Double, calories: Double?, protein: Double?, weighed: Bool, workedOut: Bool) -> Double {
        switch kind {
        case .calories: calories ?? 0
        case .protein: protein ?? 0
        case .bodyWeight: weighed ? 1 : 0
        case .workout: workedOut ? 1 : 0
        case .exercise, .custom, .count, .duration, .sleep: max(0, manual)
        }
    }
    public func shouldExempt(contributions: [MuscleContribution], recovery: ReadinessReport, cutoff: Double = 40) -> Bool {
        guard recovery.confidence != .low else { return false }
        return contributions.filter { $0.fraction >= 0.1 }.contains { contribution in
            recovery.muscles.contains { $0.muscle == contribution.muscle && $0.recoveryPercent < cutoff }
        }
    }
}
