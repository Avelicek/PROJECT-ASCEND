import Foundation

/// Presentation modes map onto the established activity graph; persisted TrackingMode values stay compatible.
public enum ExerciseMeasurementMode: String, Codable, CaseIterable, Hashable, Sendable {
    case repsWeight, repsBodyweight, duration, distance, distanceDuration, caloriesDuration, hold, custom
    public var title: String {
        switch self {
        case .repsWeight: "Load and repetitions"
        case .repsBodyweight: "Bodyweight repetitions"
        case .duration: "Duration"
        case .distance: "Distance"
        case .distanceDuration: "Distance and duration"
        case .caloriesDuration: "Observed calories and duration"
        case .hold: "Timed hold"
        case .custom: "Custom measurement and duration"
        }
    }
    public static func standard(for exercise: TrainingExercise) -> Self {
        switch exercise.mode {
        case .weightAndReps: .repsWeight
        case .reps: .repsBodyweight
        case .distance: .distanceDuration
        case .duration: exercise.pattern == .locomotion || exercise.pattern == .carry ? .duration : .hold
        }
    }
}

/// Observed supplementary quantity, stored only on newly logged sessions in the existing notes field.
/// Duration/reps/load remain canonical. Calories and arbitrary units never imply measured muscle fatigue.
public struct ActivityMeasurement: Codable, Sendable {
    public var mode: ExerciseMeasurementMode
    public var value: Double
    public var unit: String
    public init(mode: ExerciseMeasurementMode, value: Double, unit: String) { self.mode = mode; self.value = value; self.unit = unit }
    public var isValid: Bool {
        [.caloriesDuration, .custom].contains(mode) && value.isFinite && value > 0 && value <= 1_000_000 &&
        !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && unit.count <= 24 &&
        !unit.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) &&
        (mode != .caloriesDuration || unit == "kcal" && value <= 10_000)
    }
    public var summary: String { "Observed \(value.formatted()) \(unit)" }
    private static let prefix = "ASCEND.MEASUREMENT.v1\n"
    public func encodedNote() throws -> String {
        guard isValid else { throw ActivityMeasurementError.invalid }
        let data = try JSONEncoder().encode(self)
        return Self.prefix + String(decoding: data, as: UTF8.self)
    }
    public static func decodeNote(_ note: String) -> ActivityMeasurement? {
        guard note.hasPrefix(prefix), note.count <= 2_000,
              let decoded = try? JSONDecoder().decode(Self.self, from: Data(note.dropFirst(prefix.count).utf8)), decoded.isValid else { return nil }
        return decoded
    }
}
public enum ActivityMeasurementError: Error { case invalid }
