import Foundation

public struct LiveSet: Codable, Sendable, Identifiable {
    public var id = UUID()
    public var reps: Int = 8
    public var kilograms: Double = 0
    public var seconds: Double = 60
    public var distanceMeters: Double = 1000
    public var rpe: Double?
    public var isWarmup = false
    public var completedAt: Date?
    public init() {}
    public var performance: SetPerformance { .init(reps: reps, kilograms: kilograms, seconds: seconds, distanceMeters: distanceMeters) }
    public func performance(for mode: TrackingMode) -> SetPerformance {
        switch mode {
        case .reps, .weightAndReps: .init(reps: reps, kilograms: kilograms)
        case .duration: .init(reps: 0, seconds: seconds)
        case .distance: .init(reps: 0, seconds: seconds, distanceMeters: distanceMeters)
        }
    }
    public func isValid(for mode: TrackingMode, allowsWeight: Bool, bodyweight: Bool = false) -> Bool {
        guard (0...2000).contains(reps), kilograms.isFinite, (0...1000).contains(kilograms),
              seconds.isFinite, (0...86400).contains(seconds), distanceMeters.isFinite,
              (0...500000).contains(distanceMeters), allowsWeight || kilograms == 0,
              rpe == nil || (rpe!.isFinite && (1...10).contains(rpe!)) else { return false }
        switch mode {
        case .reps: return reps > 0
        case .weightAndReps: return reps > 0 && (kilograms > 0 || bodyweight)
        case .duration: return seconds > 0
        case .distance: return seconds > 0 && distanceMeters > 0
        }
    }
}

public struct LiveExercise: Codable, Sendable, Identifiable {
    public var id = UUID()
    public let catalogID: String
    public let name: String
    public let mode: TrackingMode
    public let bodyweight: Bool
    public let addedWeight: Bool
    public let weightStep: Double
    public let contributions: [MuscleContribution]
    public var sets: [LiveSet]
    public init(catalogID: String, name: String, mode: TrackingMode, bodyweight: Bool, addedWeight: Bool,
                weightStep: Double = 2.5, contributions: [MuscleContribution], sets: [LiveSet] = [LiveSet()]) {
        self.catalogID = catalogID; self.name = name; self.mode = mode; self.bodyweight = bodyweight
        self.addedWeight = addedWeight; self.weightStep = weightStep; self.contributions = contributions; self.sets = sets
    }
    public var allowsWeight: Bool { mode == .weightAndReps || addedWeight }
    public var completedWorkingSets: [LiveSet] { sets.filter { $0.completedAt != nil && !$0.isWarmup } }
}

public struct RestClock: Codable, Sendable {
    public var spanSeconds: Double?
    public var deadline: Date?
    public var pausedSeconds: Double?
    public var exerciseID: String?
    public var finishAcknowledged = true
    public init() {}
    public func remaining(at date: Date) -> Int {
        Int(ceil(max(0, pausedSeconds ?? deadline?.timeIntervalSince(date) ?? 0)))
    }
    public var isPaused: Bool { pausedSeconds != nil }
    public var isActive: Bool { deadline != nil || pausedSeconds != nil }
    public mutating func start(seconds: Int, exerciseID: String, at date: Date) {
        let duration = Double(min(900, max(15, seconds)))
        spanSeconds = duration; deadline = date.addingTimeInterval(duration)
        pausedSeconds = nil; self.exerciseID = exerciseID; finishAcknowledged = false
    }
    public mutating func pause(at date: Date) {
        guard deadline != nil else { return }
        pausedSeconds = Double(remaining(at: date)); deadline = nil
    }
    public mutating func resume(at date: Date) {
        guard let pausedSeconds else { return }
        deadline = date.addingTimeInterval(pausedSeconds); self.pausedSeconds = nil
    }
    public mutating func add(seconds: Int, at date: Date) {
        let value = Double(min(900, max(0, remaining(at: date) + seconds)))
        spanSeconds = max(value, min(900, (spanSeconds ?? Double(remaining(at: date))) + Double(seconds)))
        if isPaused { pausedSeconds = value } else { deadline = date.addingTimeInterval(value) }
        if value > 0 { finishAcknowledged = false }
    }
    public mutating func skip() { deadline = nil; pausedSeconds = nil; finishAcknowledged = true }
    public mutating func consumeCompletion(at date: Date) -> Bool {
        guard deadline != nil, remaining(at: date) == 0, !finishAcknowledged else { return false }
        skip(); return true
    }
}

public struct LiveWorkout: Codable, Sendable, Identifiable {
    public let version: Int
    public let id: UUID
    public let startedAt: Date
    public var title: String
    public var exercises: [LiveExercise]
    public var rest: RestClock
    public var selectedExerciseID: UUID?
    public init(startedAt: Date, title: String = "Live training") {
        version = 1; id = UUID(); self.startedAt = startedAt; self.title = title; exercises = []; rest = RestClock()
    }
    public var completedSets: Int { exercises.reduce(0) { $0 + $1.sets.filter { $0.completedAt != nil }.count } }
}

public struct PerformedSet: Sendable {
    public let performance: SetPerformance
    public let rpe: Double?
    public let warmup: Bool
    public init(_ performance: SetPerformance, rpe: Double? = nil, warmup: Bool = false) {
        self.performance = performance; self.rpe = rpe; self.warmup = warmup
    }
}

public struct ExerciseHistory: Sendable {
    public let sessionID: UUID
    public let exerciseID: String
    public let date: Date
    public let mode: TrackingMode
    public let quick: Bool
    public let sets: [PerformedSet]
    public init(sessionID: UUID = UUID(), exerciseID: String, date: Date, mode: TrackingMode, quick: Bool = false, sets: [PerformedSet]) {
        self.sessionID = sessionID; self.exerciseID = exerciseID; self.date = date; self.mode = mode; self.quick = quick; self.sets = sets
    }
    public var working: [PerformedSet] { sets.filter { !$0.warmup } }
}
