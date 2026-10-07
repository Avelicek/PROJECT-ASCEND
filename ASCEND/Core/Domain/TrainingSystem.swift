import Foundation

public enum GymEquipment: String, Codable, CaseIterable, Hashable, Sendable, Identifiable {
    case bodyweight, pullUpBar, dipStation, dumbbells, adjustableDumbbells, bench, chestPress, latPulldown
    case cable, bands, barbell, squatRack, kettlebell, legPress, legCurl, legExtension, calfMachine, rings, suspensionTrainer
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .bodyweight: "Bodyweight"; case .pullUpBar: "Pull-up bar"; case .dipStation: "Dip station"
        case .dumbbells: "Dumbbells"; case .adjustableDumbbells: "Adjustable dumbbells"; case .bench: "Bench"
        case .chestPress: "Chest press machine"; case .latPulldown: "Lat pulldown"; case .cable: "Cable / pulley"
        case .bands: "Resistance bands"; case .barbell: "Barbell"; case .squatRack: "Squat rack"
        case .kettlebell: "Kettlebell"; case .legPress: "Leg press"; case .legCurl: "Leg curl"
        case .legExtension: "Leg extension"; case .calfMachine: "Calf machine"; case .rings: "Gym rings"
        case .suspensionTrainer: "Suspension trainer"
        }
    }
}
public enum MovementPattern: String, Codable, CaseIterable, Hashable, Sendable {
    case horizontalPush, verticalPush, horizontalPull, verticalPull, squat, hinge, lunge
    case elbowFlexion, elbowExtension, shoulderIsolation, coreFlexion, coreStability, calf, carry, locomotion
    case kneeFlexion, kneeExtension, hipAbduction
    public var title: String { rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized }
}
public enum TrainingFocus: String, Codable, CaseIterable, Hashable, Sendable {
    case chest, back, shoulders, biceps, triceps, quads, hamstrings, glutes, calves, core, fullBody
    public var title: String { self == .fullBody ? "Full body" : rawValue.capitalized }
}
public enum TrainingEnvironment: String, Codable, CaseIterable, Hashable, Sendable { case homeGym, gym, outdoors }
public enum TrainingGoal: String, Codable, CaseIterable, Hashable, Sendable { case strengthAndMuscle, strength, generalFitness }

public struct TrainingProfile: Codable, Sendable {
    public var environment: TrainingEnvironment = .homeGym
    // Availability starts conservatively. Suggested equipment is never assumed to be owned.
    public var equipment: Set<GymEquipment> = [.bodyweight]
    public var goal: TrainingGoal = .strengthAndMuscle
    public var sessionMinutes = 50
    public init() {}
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        environment = try values.decodeIfPresent(TrainingEnvironment.self, forKey: .environment) ?? .homeGym
        equipment = try values.decodeIfPresent(Set<GymEquipment>.self, forKey: .equipment) ?? [.bodyweight]
        goal = try values.decodeIfPresent(TrainingGoal.self, forKey: .goal) ?? .strengthAndMuscle
        sessionMinutes = try values.decodeIfPresent(Int.self, forKey: .sessionMinutes) ?? 50
    }
    public var resolvedEquipment: Set<GymEquipment> {
        var value = equipment.union([.bodyweight])
        if value.contains(.adjustableDumbbells) { value.insert(.dumbbells) }
        return value
    }
}
public struct RoutineExercise: Codable, Sendable, Identifiable {
    public var id = UUID()
    public var exerciseID: String
    public var sets: Int
    public var repTarget: Int?
    public var restSeconds: Int
    public init(_ exerciseID: String, sets: Int = 3, repTarget: Int? = nil, restSeconds: Int = 90) {
        self.exerciseID = exerciseID; self.sets = sets; self.repTarget = repTarget; self.restSeconds = restSeconds
    }
    public var isValid: Bool { (1...40).contains(sets) && (repTarget == nil || (1...2000).contains(repTarget!)) && (15...900).contains(restSeconds) }
}
public struct WorkoutRoutine: Codable, Sendable, Identifiable {
    public var id = UUID()
    public var name: String
    public var exercises: [RoutineExercise]
    public init(name: String, exercises: [RoutineExercise]) { self.name = name; self.exercises = exercises }
    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 80 &&
        (1...40).contains(exercises.count) && exercises.allSatisfy(\.isValid) && Set(exercises.map(\.exerciseID)).count == exercises.count
    }
}
public struct PersonalTrainingState: Codable, Sendable {
    public let version: Int
    public var profile: TrainingProfile
    public var favorites: Set<String>
    public var hidden: Set<String>
    public var routines: [WorkoutRoutine]
    public init() { version = 1; profile = .init(); favorites = []; hidden = []; routines = RoutineLibrary.starters }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 1
        profile = try values.decodeIfPresent(TrainingProfile.self, forKey: .profile) ?? .init()
        favorites = try values.decodeIfPresent(Set<String>.self, forKey: .favorites) ?? []
        hidden = try values.decodeIfPresent(Set<String>.self, forKey: .hidden) ?? []
        routines = try values.decodeIfPresent([WorkoutRoutine].self, forKey: .routines) ?? RoutineLibrary.starters
    }
}
public enum RoutineLibrary {
    public static let starters: [WorkoutRoutine] = [
        .init(name: "Bodyweight push", exercises: [.init("push_up", repTarget: 12), .init("pike_push_up", repTarget: 8), .init("close_grip_push_up", repTarget: 10), .init("plank", restSeconds: 60)]),
        .init(name: "Upper body", exercises: [.init("chest_press", repTarget: 10), .init("lat_pulldown", repTarget: 10), .init("db_shoulder_press", repTarget: 10), .init("db_row", repTarget: 10), .init("lateral_raise", repTarget: 12), .init("hammer_curl", repTarget: 10)]),
        .init(name: "Pull", exercises: [.init("pull_up", repTarget: 8), .init("db_row", repTarget: 10), .init("rear_delt_raise", repTarget: 12), .init("hammer_curl", repTarget: 10)]),
        .init(name: "Legs", exercises: [.init("bodyweight_squat", repTarget: 15), .init("reverse_lunge", repTarget: 10), .init("glute_bridge", repTarget: 15), .init("bodyweight_calf_raise", repTarget: 15)])
    ]
}
public enum ExerciseSort: String, CaseIterable, Hashable, Sendable { case recommended, recent, favorites, alphabetical }
public struct ExerciseQuery: Sendable {
    public var search = ""
    public var focus: TrainingFocus?
    public var preferredFocus: TrainingFocus?
    public var equipment: GymEquipment?
    public var availableOnly = false
    public var bodyweightOnly = false
    public var favoritesOnly = false
    public var showHidden = false
    public var sort: ExerciseSort = .recommended
    public init() {}
}
public struct SubstitutionSuggestion: Sendable {
    public let exercise: TrainingExercise
    public let score: Int
    public let reason: String
}
public struct TrainingRecommendation: Sendable {
    public let routineID: UUID
    public let title: String
    public let reason: String
}
public struct TrainingSystem: Sendable {
    public init() {}
    public func missing(_ exercise: TrainingExercise, profile: TrainingProfile) -> Set<GymEquipment> { exercise.required.subtracting(profile.resolvedEquipment) }
    public func filter(_ catalog: [TrainingExercise], state: PersonalTrainingState, query: ExerciseQuery, recent: [String] = []) -> [TrainingExercise] {
        let values = catalog.filter {
            (query.showHidden || !state.hidden.contains($0.id)) &&
            (query.search.isEmpty || $0.name.localizedCaseInsensitiveContains(query.search)) &&
            (query.focus == nil || $0.focus == query.focus) &&
            (query.equipment == nil || $0.required.contains(query.equipment!)) &&
            (!query.availableOnly || missing($0, profile: state.profile).isEmpty) &&
            (!query.bodyweightOnly || $0.bodyweight) && (!query.favoritesOnly || state.favorites.contains($0.id))
        }
        func priority(_ exercise: TrainingExercise) -> Int {
            switch query.sort {
            case .alphabetical: return 0
            case .favorites: return state.favorites.contains(exercise.id) ? 0 : 1
            case .recent: return recent.firstIndex(of: exercise.id) ?? Int.max
            case .recommended:
                if state.favorites.contains(exercise.id) { return 0 }
                if let index = recent.firstIndex(of: exercise.id) { return 1 + index }
                return missing(exercise, profile: state.profile).isEmpty ? (query.preferredFocus == exercise.focus ? 1000 : 1500) : 2000
            }
        }
        return values.sorted {
            let a = priority($0), b = priority($1)
            return a == b ? ($0.name == $1.name ? $0.id < $1.id : $0.name < $1.name) : a < b
        }
    }
    public func substitutes(for source: TrainingExercise, catalog: [TrainingExercise], state: PersonalTrainingState) -> [SubstitutionSuggestion] {
        catalog.filter { $0.id != source.id && !state.hidden.contains($0.id) && missing($0, profile: state.profile).isEmpty &&
            ($0.pattern == source.pattern || ($0.focus == source.focus && $0.focus != .fullBody)) &&
            (($0.mode == .reps || $0.mode == .weightAndReps) == (source.mode == .reps || source.mode == .weightAndReps))
        }.map { entry in
            let shared = Set(source.muscles.map(\.muscle)).intersection(entry.muscles.map(\.muscle)).count
            let score = (entry.pattern == source.pattern ? 100 : 0) + (entry.focus == source.focus ? 40 : 0) +
                (entry.family != nil && entry.family == source.family ? 20 : 0) + shared * 3 + (entry.mode == source.mode ? 5 : 0)
            return .init(exercise: entry, score: score, reason: entry.pattern == source.pattern ? "Same movement · \(entry.pattern.title)" : "Related \(source.focus.title.lowercased()) focus · different movement")
        }.sorted { $0.score == $1.score ? $0.exercise.id < $1.exercise.id : $0.score > $1.score }
    }
    public func harderVariation(for exercise: TrainingExercise, history: [ExerciseHistory], state: PersonalTrainingState, now: Date) -> TrainingExercise? {
        guard let family = exercise.family, let level = exercise.familyLevel, exercise.bodyweight else { return nil }
        let recent = history.filter { $0.exerciseID == exercise.id && $0.mode == exercise.mode && !$0.quick && $0.date <= now && $0.date >= now.addingTimeInterval(-42 * 86400) }.sorted { $0.date > $1.date }.prefix(3)
        guard recent.count == 3, recent.allSatisfy({ $0.working.count >= 2 && $0.working.allSatisfy { $0.performance.reps >= 20 && ($0.rpe == nil || $0.rpe! < 9) } }) else { return nil }
        return TrainingCatalog.definitions.filter { $0.family == family && ($0.familyLevel ?? 0) > level && !state.hidden.contains($0.id) && missing($0, profile: state.profile).isEmpty }.sorted { ($0.familyLevel ?? 0) < ($1.familyLevel ?? 0) }.first
    }
    public func recommend(routines: [WorkoutRoutine], catalog: [TrainingExercise], state: PersonalTrainingState, recovery: ReadinessReport) -> TrainingRecommendation? {
        guard recovery.confidence != .low else { return nil }
        return routines.compactMap { routine -> (TrainingRecommendation, Double)? in
            let entries = routine.exercises.compactMap { item in catalog.first { $0.id == item.exerciseID } }
            guard !entries.isEmpty, entries.count == routine.exercises.count,
                entries.allSatisfy({ !state.hidden.contains($0.id) && missing($0, profile: state.profile).isEmpty }) else { return nil }
            let muscles = Set(entries.flatMap { $0.muscles.filter { $0.fraction >= 0.2 }.map(\.muscle) })
            let states = recovery.muscles.filter { muscles.contains($0.muscle) }
            guard states.count == muscles.count, states.allSatisfy({ $0.lastTrainedAt != nil && $0.recoveryPercent >= 70 }) else { return nil }
            let minimum = states.map(\.recoveryPercent).min() ?? 0
            return (.init(routineID: routine.id, title: routine.name, reason: "Estimated muscle recovery ≥ \(Int(minimum))% · equipment available"), minimum)
        }.sorted { $0.1 == $1.1 ? $0.0.title < $1.0.title : $0.1 > $1.1 }.first?.0
    }
}
