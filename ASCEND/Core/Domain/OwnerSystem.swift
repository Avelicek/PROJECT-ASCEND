import Foundation

public struct BodyMeasurement: Codable, Sendable, Identifiable {
    public var id = UUID()
    public var date: Date
    public var chest: Double?
    public var waist: Double?
    public var hips: Double?
    public var biceps: Double?
    public var thigh: Double?
    public init(date: Date, chest: Double? = nil, waist: Double? = nil, hips: Double? = nil, biceps: Double? = nil, thigh: Double? = nil) {
        self.date = date; self.chest = chest; self.waist = waist; self.hips = hips; self.biceps = biceps; self.thigh = thigh
    }
    public var isValid: Bool { OwnerDates.valid(date) && [chest, waist, hips, biceps, thigh].compactMap { $0 }.allSatisfy { $0.isFinite && (5...300).contains($0) } }
}
public struct SickInterval: Codable, Sendable, Identifiable {
    public var id = UUID()
    public var start: Date
    public var end: Date?
    public var note: String
    public init(start: Date, note: String = "") { self.start = start; self.note = note }
    public func intersects(day: Date, policy: DayPolicy) -> Bool {
        start < policy.adding(days: 1, to: policy.start(of: day)) && (end ?? .distantFuture) >= policy.start(of: day)
    }
}
public struct OwnerSystem: Codable, Sendable {
    public var version = 1
    public var onboardingComplete = false
    public var heightCM: Double?
    public var birthDate: Date?
    public var measurements: [BodyMeasurement] = []
    public var sleepStartedAt: Date?
    public var sleepEndedAt: Date?
    public var goalPlanReviewAt: Date?
    public var weeklyWorkoutTarget: Int?
    public var sickIntervals: [SickInterval] = []
    public var exerciseRest: [String: Int] = [:]
    public var lastSeenDay: String?
    public var checkIns: [MorningCheckIn]?
    public var coachPreferences: CoachPreferences?
    public init() {}
    public var sickActive: Bool { sickIntervals.last?.end == nil && !sickIntervals.isEmpty }
    public func protectsTraining(on date: Date, policy: DayPolicy) -> Bool { sickIntervals.contains { $0.intersects(day: date, policy: policy) } }
    public func validate() throws {
        guard goalPlanReviewAt.map(OwnerDates.valid) ?? true else { throw OwnerSystemError.invalid }
        guard weeklyWorkoutTarget.map({ (1...7).contains($0) }) ?? true else { throw OwnerSystemError.invalid }
        if let end = sleepEndedAt {
            guard let start = sleepStartedAt, OwnerDates.valid(end), end >= start else { throw OwnerSystemError.invalid }
        }
        guard version == 1, birthDate.map(OwnerDates.valid) ?? true, sleepStartedAt.map(OwnerDates.valid) ?? true, heightCM.map({ $0.isFinite && (80...250).contains($0) }) ?? true,
              measurements.count <= 50_000, measurements.allSatisfy(\.isValid),
              Set(measurements.map(\.id)).count == measurements.count,
              sickIntervals.count <= 10_000, Set(sickIntervals.map(\.id)).count == sickIntervals.count,
              sickIntervals.filter({ $0.end == nil }).count <= 1,
              sickIntervals.allSatisfy({ $0.note.count <= 400 && OwnerDates.valid($0.start) && ($0.end.map(OwnerDates.valid) ?? true) }),
              exerciseRest.values.allSatisfy({ (15...900).contains($0) }),
              coachPreferences?.isValid ?? true,
              checkIns.map({ $0.count <= 50_000 && $0.allSatisfy(\.isValid) && Set($0.map(\.id)).count == $0.count }) ?? true else { throw OwnerSystemError.invalid }
        if let open = sickIntervals.first(where: { $0.end == nil }), open.id != sickIntervals.last?.id { throw OwnerSystemError.invalid }
        for interval in sickIntervals { if let end = interval.end, end < interval.start { throw OwnerSystemError.invalid } }
    }
}
public enum OwnerSystemError: LocalizedError { case invalid, interval
    public var errorDescription: String? { switch self {
    case .invalid: "The local system data is invalid or uses an unsupported version."
    case .interval: "Choose a recorded interval between 6 minutes and 24 hours, ending no later than now."
    } }
}
public enum RecordedSleep {
    public static func hours(start: Date, end: Date, now: Date) throws -> Double {
        let hours = end.timeIntervalSince(start) / 3600
        guard hours.isFinite, (0.1...24).contains(hours), end <= now else { throw OwnerSystemError.interval }
        return hours
    }
}

public enum ResetConsent {
    public static func allowed(checked: Bool, phrase: String) -> Bool { checked && phrase == "RESET ASCEND" }
}

public enum OwnerDates {
    public static func valid(_ date: Date) -> Bool {
        date.timeIntervalSinceReferenceDate.isFinite && date >= .distantPast && date <= .distantFuture
    }
}
