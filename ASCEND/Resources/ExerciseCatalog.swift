import Foundation
import SwiftData

enum ExerciseCatalog {
    struct Definition: Sendable {
        let id: String
        let name: String
        let category: ExerciseCategory
        let equipment: Equipment
        let mode: TrackingMode
        let bodyweight: Bool
        let additional: Bool
        let muscles: [MuscleContribution]
    }
    // Baseline contribution weights are versioned catalog data, not physiological measurements.
    static let definitions: [Definition] = [
        .init(id: "push_up", name: "Push-up", category: .bodyweight, equipment: .none, mode: .reps, bodyweight: true, additional: true,
              muscles: [.init(.midPectoral, 0.45), .init(.tricepsLongHead, 0.25), .init(.anteriorDeltoid, 0.2), .init(.rectusAbdominis, 0.1)]),
        .init(id: "bench_press", name: "Bench press", category: .strength, equipment: .barbell, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.midPectoral, 0.6), .init(.tricepsLateralHead, 0.25), .init(.anteriorDeltoid, 0.15)]),
        .init(id: "incline_db_press", name: "Incline dumbbell press", category: .strength, equipment: .dumbbell, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.upperPectoral, 0.55), .init(.anteriorDeltoid, 0.25), .init(.tricepsLongHead, 0.2)]),
        .init(id: "pull_up", name: "Pull-up", category: .bodyweight, equipment: .none, mode: .reps, bodyweight: true, additional: true,
              muscles: [.init(.latissimus, 0.5), .init(.bicepsLongHead, 0.25), .init(.lowerTrapezius, 0.15), .init(.forearmFlexors, 0.1)]),
        .init(id: "lat_pulldown", name: "Lat pulldown", category: .strength, equipment: .cable, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.latissimus, 0.6), .init(.bicepsShortHead, 0.25), .init(.lowerTrapezius, 0.15)]),
        .init(id: "seated_row", name: "Seated cable row", category: .strength, equipment: .cable, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.rhomboids, 0.35), .init(.latissimus, 0.35), .init(.posteriorDeltoid, 0.15), .init(.bicepsLongHead, 0.15)]),
        .init(id: "overhead_press", name: "Overhead press", category: .strength, equipment: .barbell, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.anteriorDeltoid, 0.45), .init(.lateralDeltoid, 0.3), .init(.tricepsLongHead, 0.25)]),
        .init(id: "lateral_raise", name: "Lateral raise", category: .strength, equipment: .dumbbell, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.lateralDeltoid, 0.8), .init(.upperTrapezius, 0.2)]),
        .init(id: "face_pull", name: "Face pull", category: .strength, equipment: .cable, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.posteriorDeltoid, 0.5), .init(.middleTrapezius, 0.3), .init(.rhomboids, 0.2)]),
        .init(id: "db_curl", name: "Dumbbell curl", category: .strength, equipment: .dumbbell, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.bicepsLongHead, 0.4), .init(.bicepsShortHead, 0.4), .init(.brachialis, 0.2)]),
        .init(id: "triceps_pushdown", name: "Triceps pushdown", category: .strength, equipment: .cable, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.tricepsLateralHead, 0.6), .init(.tricepsMedialHead, 0.4)]),
        .init(id: "back_squat", name: "Back squat", category: .strength, equipment: .barbell, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.vastusLateralis, 0.25), .init(.vastusMedialis, 0.25), .init(.gluteusMaximus, 0.3), .init(.spinalErectors, 0.2)]),
        .init(id: "goblet_squat", name: "Goblet squat", category: .strength, equipment: .kettlebell, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.rectusFemoris, 0.25), .init(.vastusMedialis, 0.25), .init(.gluteusMaximus, 0.3), .init(.rectusAbdominis, 0.2)]),
        .init(id: "romanian_deadlift", name: "Romanian deadlift", category: .strength, equipment: .barbell, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.bicepsFemoris, 0.3), .init(.semitendinosus, 0.2), .init(.gluteusMaximus, 0.3), .init(.spinalErectors, 0.2)]),
        .init(id: "leg_press", name: "Leg press", category: .strength, equipment: .machine, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.vastusLateralis, 0.3), .init(.vastusMedialis, 0.3), .init(.rectusFemoris, 0.15), .init(.gluteusMaximus, 0.25)]),
        .init(id: "leg_curl", name: "Seated leg curl", category: .strength, equipment: .machine, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.bicepsFemoris, 0.4), .init(.semitendinosus, 0.3), .init(.semimembranosus, 0.3)]),
        .init(id: "hip_thrust", name: "Hip thrust", category: .strength, equipment: .barbell, mode: .weightAndReps, bodyweight: false, additional: false,
              muscles: [.init(.gluteusMaximus, 0.8), .init(.bicepsFemoris, 0.2)]),
        .init(id: "calf_raise", name: "Standing calf raise", category: .strength, equipment: .machine, mode: .weightAndReps, bodyweight: true, additional: true,
              muscles: [.init(.gastrocnemius, 0.7), .init(.soleus, 0.3)]),
        .init(id: "plank", name: "Plank", category: .bodyweight, equipment: .none, mode: .duration, bodyweight: true, additional: false,
              muscles: [.init(.transverseAbdominis, 0.5), .init(.rectusAbdominis, 0.3), .init(.obliques, 0.2)]),
        .init(id: "walking", name: "Walking", category: .cardio, equipment: .none, mode: .duration, bodyweight: true, additional: false,
              muscles: [.init(.gluteusMedius, 0.25), .init(.soleus, 0.25), .init(.rectusFemoris, 0.25), .init(.hipFlexors, 0.25)]),
        .init(id: "running", name: "Running", category: .cardio, equipment: .none, mode: .distance, bodyweight: true, additional: false,
              muscles: [.init(.gastrocnemius, 0.3), .init(.gluteusMaximus, 0.3), .init(.rectusFemoris, 0.2), .init(.bicepsFemoris, 0.2)]),
        .init(id: "band_pull_apart", name: "Band pull-apart", category: .mobility, equipment: .band, mode: .reps, bodyweight: false, additional: false,
              muscles: [.init(.posteriorDeltoid, 0.5), .init(.rhomboids, 0.5)])
    ]
    @MainActor static func seed(in context: ModelContext) throws {
        let existing = Set(try context.fetch(FetchDescriptor<Exercise>()).map(\.catalogID))
        for entry in definitions where !existing.contains(entry.id) {
            context.insert(Exercise(catalogID: entry.id, name: entry.name, category: entry.category, equipment: entry.equipment,
                                    trackingMode: entry.mode, bodyweightCapable: entry.bodyweight,
                                    additionalWeightAllowed: entry.additional, contributions: entry.muscles))
        }
    }
}
