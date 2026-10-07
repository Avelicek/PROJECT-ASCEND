import Foundation

public enum Confidence: String, Codable, Hashable, Sendable { case low, medium, high }
public enum EvaluationWindow: Int, CaseIterable, Hashable, Sendable { case day = 1, week = 7, month = 28 }
public enum ObjectiveImportance: String, Codable, CaseIterable, Hashable, Sendable {
    case minor, standard, major
    public var weight: Double { switch self { case .minor: 0.5; case .standard: 1; case .major: 1.5 } }
}
public enum ObjectiveCadence: String, Codable, CaseIterable, Hashable, Sendable { case once, daily, weekly, weekdays }
public enum ObjectiveKind: String, Codable, CaseIterable, Hashable, Sendable {
    case custom, calories, protein, bodyWeight, workout, exercise
}
public enum TrackingMode: String, Codable, CaseIterable, Hashable, Sendable { case reps, weightAndReps, duration, distance }
public enum ExerciseCategory: String, Codable, Sendable { case strength, bodyweight, cardio, mobility }
public enum Equipment: String, Codable, Sendable { case none, barbell, dumbbell, cable, machine, kettlebell, band }
public enum RecordKind: String, Codable, CaseIterable, Hashable, Sendable { case weight, reps, volume, estimatedOneRepMax, totalReps, addedWeightPerformance }

public struct DayPolicy: Sendable {
    public let timeZoneIdentifier: String
    public init(timeZoneIdentifier: String = TimeZone.current.identifier) { self.timeZoneIdentifier = timeZoneIdentifier }
    public var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
        calendar.firstWeekday = 2
        return calendar
    }
    public func start(of date: Date) -> Date { calendar.startOfDay(for: date) }
    public func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }
    public func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
    public func sameDay(_ lhs: Date, _ rhs: Date) -> Bool { key(for: lhs) == key(for: rhs) }
}

public struct WeightSample: Codable, Sendable, Equatable {
    public let date: Date
    public let kilograms: Double
    public init(date: Date, kilograms: Double) { self.date = date; self.kilograms = kilograms }
}
public struct NutritionSample: Codable, Sendable {
    public let date: Date
    public let calories: Double
    public let protein: Double
    public init(date: Date, calories: Double, protein: Double) {
        self.date = date; self.calories = calories; self.protein = protein
    }
}
public struct SleepSample: Codable, Sendable {
    public let date: Date
    public let hours: Double
    public let quality: Int
    public init(date: Date, hours: Double, quality: Int) { self.date = date; self.hours = hours; self.quality = quality }
}
public struct MuscleContribution: Codable, Sendable, Equatable {
    public let muscle: Muscle
    public let fraction: Double
    public init(_ muscle: Muscle, _ fraction: Double) { self.muscle = muscle; self.fraction = fraction }
}

public enum FitnessMath {
    public static func clamp(_ value: Double, _ range: ClosedRange<Double>) -> Double {
        guard value.isFinite else { return range.lowerBound }
        return min(range.upperBound, max(range.lowerBound, value))
    }
    public static func average(_ values: [Double]) -> Double? {
        let usable = values.filter(\.isFinite)
        return usable.isEmpty ? nil : usable.reduce(0, +) / Double(usable.count)
    }
}
