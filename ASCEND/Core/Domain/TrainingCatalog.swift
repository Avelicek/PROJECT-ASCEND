import Foundation

public struct TrainingExercise: Sendable, Identifiable {
    public let id: String
    public let name: String
    public let category: ExerciseCategory
    public let equipment: Equipment
    public let mode: TrackingMode
    public let bodyweight: Bool
    public let additional: Bool
    public let focus: TrainingFocus
    public let pattern: MovementPattern
    public let required: Set<GymEquipment>
    public let family: String?
    public let familyLevel: Int?
    public let muscles: [MuscleContribution]
    public init(id: String, name: String, category: ExerciseCategory, equipment: Equipment, mode: TrackingMode,
                bodyweight: Bool, additional: Bool, focus: TrainingFocus, pattern: MovementPattern,
                required: Set<GymEquipment>, family: String? = nil, familyLevel: Int? = nil, muscles: [MuscleContribution]) {
        self.id = id; self.name = name; self.category = category; self.equipment = equipment; self.mode = mode
        self.bodyweight = bodyweight; self.additional = additional; self.focus = focus; self.pattern = pattern
        self.required = required; self.family = family; self.familyLevel = familyLevel; self.muscles = muscles
    }
}

public enum TrainingCatalog {
    // Contribution weights are deterministic load-allocation heuristics, not measured activation percentages.
    // Similar movement variants share reviewed anatomical roles. Logged sessions keep their original snapshots.
    public static let definitions: [TrainingExercise] = baseline + expanded
    private static let baseline: [TrainingExercise] = [
        .init(id: "push_up", name: "Push-up", category: .bodyweight, equipment: .none, mode: .reps, bodyweight: true, additional: true,
              focus: .chest, pattern: .horizontalPush, required: [.bodyweight], family: "push", familyLevel: 1,
              muscles: [.init(.midPectoral, 0.45), .init(.tricepsLongHead, 0.25), .init(.anteriorDeltoid, 0.2), .init(.rectusAbdominis, 0.1)]),
        .init(id: "bench_press", name: "Bench press", category: .strength, equipment: .barbell, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .chest, pattern: .horizontalPush, required: [.barbell, .bench],
              muscles: [.init(.midPectoral, 0.6), .init(.tricepsLateralHead, 0.25), .init(.anteriorDeltoid, 0.15)]),
        .init(id: "incline_db_press", name: "Incline dumbbell press", category: .strength, equipment: .dumbbell, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .chest, pattern: .horizontalPush, required: [.dumbbells, .bench],
              muscles: [.init(.upperPectoral, 0.55), .init(.anteriorDeltoid, 0.25), .init(.tricepsLongHead, 0.2)]),
        .init(id: "pull_up", name: "Pull-up", category: .bodyweight, equipment: .none, mode: .reps, bodyweight: true, additional: true,
              focus: .back, pattern: .verticalPull, required: [.pullUpBar], family: "pull", familyLevel: 1,
              muscles: [.init(.latissimus, 0.5), .init(.bicepsLongHead, 0.25), .init(.lowerTrapezius, 0.15), .init(.forearmFlexors, 0.1)]),
        .init(id: "lat_pulldown", name: "Lat pulldown", category: .strength, equipment: .cable, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .back, pattern: .verticalPull, required: [.latPulldown],
              muscles: [.init(.latissimus, 0.6), .init(.bicepsShortHead, 0.25), .init(.lowerTrapezius, 0.15)]),
        .init(id: "seated_row", name: "Seated cable row", category: .strength, equipment: .cable, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .back, pattern: .horizontalPull, required: [.cable],
              muscles: [.init(.rhomboids, 0.35), .init(.latissimus, 0.35), .init(.posteriorDeltoid, 0.15), .init(.bicepsLongHead, 0.15)]),
        .init(id: "overhead_press", name: "Overhead press", category: .strength, equipment: .barbell, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .shoulders, pattern: .verticalPush, required: [.barbell],
              muscles: [.init(.anteriorDeltoid, 0.45), .init(.lateralDeltoid, 0.3), .init(.tricepsLongHead, 0.25)]),
        .init(id: "lateral_raise", name: "Lateral raise", category: .strength, equipment: .dumbbell, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .shoulders, pattern: .shoulderIsolation, required: [.dumbbells],
              muscles: [.init(.lateralDeltoid, 0.8), .init(.upperTrapezius, 0.2)]),
        .init(id: "face_pull", name: "Face pull", category: .strength, equipment: .cable, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .shoulders, pattern: .shoulderIsolation, required: [.cable],
              muscles: [.init(.posteriorDeltoid, 0.5), .init(.middleTrapezius, 0.3), .init(.rhomboids, 0.2)]),
        .init(id: "db_curl", name: "Dumbbell curl", category: .strength, equipment: .dumbbell, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .biceps, pattern: .elbowFlexion, required: [.dumbbells],
              muscles: [.init(.bicepsLongHead, 0.4), .init(.bicepsShortHead, 0.4), .init(.brachialis, 0.2)]),
        .init(id: "triceps_pushdown", name: "Triceps pushdown", category: .strength, equipment: .cable, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .triceps, pattern: .elbowExtension, required: [.cable],
              muscles: [.init(.tricepsLateralHead, 0.6), .init(.tricepsMedialHead, 0.4)]),
        .init(id: "back_squat", name: "Back squat", category: .strength, equipment: .barbell, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .quads, pattern: .squat, required: [.barbell, .squatRack],
              muscles: [.init(.vastusLateralis, 0.25), .init(.vastusMedialis, 0.25), .init(.gluteusMaximus, 0.3), .init(.spinalErectors, 0.2)]),
        .init(id: "goblet_squat", name: "Goblet squat", category: .strength, equipment: .kettlebell, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .quads, pattern: .squat, required: [.dumbbells], family: "squat", familyLevel: 1,
              muscles: [.init(.rectusFemoris, 0.25), .init(.vastusMedialis, 0.25), .init(.gluteusMaximus, 0.3), .init(.rectusAbdominis, 0.2)]),
        .init(id: "romanian_deadlift", name: "Romanian deadlift", category: .strength, equipment: .barbell, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .hamstrings, pattern: .hinge, required: [.barbell],
              muscles: [.init(.bicepsFemoris, 0.3), .init(.semitendinosus, 0.2), .init(.gluteusMaximus, 0.3), .init(.spinalErectors, 0.2)]),
        .init(id: "leg_press", name: "Leg press", category: .strength, equipment: .machine, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .quads, pattern: .squat, required: [.legPress],
              muscles: [.init(.vastusLateralis, 0.3), .init(.vastusMedialis, 0.3), .init(.rectusFemoris, 0.15), .init(.gluteusMaximus, 0.25)]),
        .init(id: "leg_curl", name: "Seated leg curl", category: .strength, equipment: .machine, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .hamstrings, pattern: .kneeFlexion, required: [.legCurl],
              muscles: [.init(.bicepsFemoris, 0.4), .init(.semitendinosus, 0.3), .init(.semimembranosus, 0.3)]),
        .init(id: "hip_thrust", name: "Hip thrust", category: .strength, equipment: .barbell, mode: .weightAndReps, bodyweight: false, additional: false,
              focus: .glutes, pattern: .hinge, required: [.barbell, .bench],
              muscles: [.init(.gluteusMaximus, 0.8), .init(.bicepsFemoris, 0.2)]),
        .init(id: "calf_raise", name: "Standing calf raise", category: .strength, equipment: .machine, mode: .weightAndReps, bodyweight: true, additional: true,
              focus: .calves, pattern: .calf, required: [.calfMachine],
              muscles: [.init(.gastrocnemius, 0.7), .init(.soleus, 0.3)]),
        .init(id: "plank", name: "Plank", category: .bodyweight, equipment: .none, mode: .duration, bodyweight: true, additional: false,
              focus: .core, pattern: .coreStability, required: [.bodyweight],
              muscles: [.init(.transverseAbdominis, 0.5), .init(.rectusAbdominis, 0.3), .init(.obliques, 0.2)]),
        .init(id: "walking", name: "Walking", category: .cardio, equipment: .none, mode: .duration, bodyweight: true, additional: false,
              focus: .fullBody, pattern: .locomotion, required: [.bodyweight],
              muscles: [.init(.gluteusMedius, 0.25), .init(.soleus, 0.25), .init(.rectusFemoris, 0.25), .init(.hipFlexors, 0.25)]),
        .init(id: "running", name: "Running", category: .cardio, equipment: .none, mode: .distance, bodyweight: true, additional: false,
              focus: .fullBody, pattern: .locomotion, required: [.bodyweight],
              muscles: [.init(.gastrocnemius, 0.3), .init(.gluteusMaximus, 0.3), .init(.rectusFemoris, 0.2), .init(.bicepsFemoris, 0.2)]),
        .init(id: "band_pull_apart", name: "Band pull-apart", category: .mobility, equipment: .band, mode: .reps, bodyweight: false, additional: false,
              focus: .shoulders, pattern: .shoulderIsolation, required: [.bands],
              muscles: [.init(.posteriorDeltoid, 0.5), .init(.rhomboids, 0.5)])
    ]

    private static func movement(_ id: String, _ name: String, _ focus: TrainingFocus, _ pattern: MovementPattern,
                                 _ required: Set<GymEquipment>, _ muscles: [MuscleContribution],
                                 bodyweight: Bool = false, mode: TrackingMode = .weightAndReps,
                                 added: Bool = false, family: String? = nil, level: Int? = nil) -> TrainingExercise {
        let legacy: Equipment = required.contains(.dumbbells) ? .dumbbell : required.contains(.barbell) ? .barbell :
            required.contains(.bands) ? .band : required.contains(.cable) ? .cable : required.contains(.kettlebell) ? .kettlebell :
            required.isSubset(of: [.bodyweight, .pullUpBar, .dipStation, .bench, .rings, .suspensionTrainer]) ? .none : .machine
        return .init(id: id, name: name, category: bodyweight ? .bodyweight : .strength, equipment: legacy,
                     mode: mode, bodyweight: bodyweight, additional: added, focus: focus, pattern: pattern,
                     required: required, family: family, familyLevel: level, muscles: muscles)
    }
    private static let chest: [MuscleContribution] = [.init(.midPectoral, 0.6), .init(.tricepsLateralHead, 0.25), .init(.anteriorDeltoid, 0.15)]
    private static let incline: [MuscleContribution] = [.init(.upperPectoral, 0.55), .init(.anteriorDeltoid, 0.25), .init(.tricepsLongHead, 0.2)]
    private static let fly: [MuscleContribution] = [.init(.midPectoral, 0.8), .init(.anteriorDeltoid, 0.2)]
    private static let inclineFly: [MuscleContribution] = [.init(.upperPectoral, 0.8), .init(.anteriorDeltoid, 0.2)]
    private static let row: [MuscleContribution] = [.init(.latissimus, 0.35), .init(.rhomboids, 0.35), .init(.posteriorDeltoid, 0.15), .init(.bicepsLongHead, 0.15)]
    private static let pull: [MuscleContribution] = [.init(.latissimus, 0.6), .init(.bicepsLongHead, 0.25), .init(.lowerTrapezius, 0.15)]
    private static let pullover: [MuscleContribution] = [.init(.latissimus, 0.7), .init(.serratusAnterior, 0.2), .init(.tricepsLongHead, 0.1)]
    private static let shoulder: [MuscleContribution] = [.init(.anteriorDeltoid, 0.45), .init(.lateralDeltoid, 0.3), .init(.tricepsLongHead, 0.25)]
    private static let side: [MuscleContribution] = [.init(.lateralDeltoid, 0.8), .init(.upperTrapezius, 0.2)]
    private static let front: [MuscleContribution] = [.init(.anteriorDeltoid, 0.8), .init(.upperPectoral, 0.2)]
    private static let rear: [MuscleContribution] = [.init(.posteriorDeltoid, 0.6), .init(.rhomboids, 0.25), .init(.middleTrapezius, 0.15)]
    private static let curl: [MuscleContribution] = [.init(.bicepsLongHead, 0.4), .init(.bicepsShortHead, 0.4), .init(.brachialis, 0.2)]
    private static let hammer: [MuscleContribution] = [.init(.brachialis, 0.45), .init(.bicepsLongHead, 0.3), .init(.forearmFlexors, 0.25)]
    private static let triceps: [MuscleContribution] = [.init(.tricepsLongHead, 0.5), .init(.tricepsLateralHead, 0.3), .init(.tricepsMedialHead, 0.2)]
    private static let closePush: [MuscleContribution] = [.init(.tricepsLateralHead, 0.45), .init(.midPectoral, 0.35), .init(.anteriorDeltoid, 0.2)]
    private static let squat: [MuscleContribution] = [.init(.vastusLateralis, 0.25), .init(.vastusMedialis, 0.25), .init(.rectusFemoris, 0.2), .init(.gluteusMaximus, 0.3)]
    private static let hinge: [MuscleContribution] = [.init(.bicepsFemoris, 0.3), .init(.semitendinosus, 0.2), .init(.gluteusMaximus, 0.3), .init(.spinalErectors, 0.2)]
    private static let lunge: [MuscleContribution] = [.init(.gluteusMaximus, 0.4), .init(.vastusMedialis, 0.3), .init(.rectusFemoris, 0.2), .init(.gluteusMedius, 0.1)]
    private static let glute: [MuscleContribution] = [.init(.gluteusMaximus, 0.8), .init(.bicepsFemoris, 0.2)]
    private static let abduction: [MuscleContribution] = [.init(.gluteusMedius, 0.6), .init(.gluteusMinimus, 0.4)]
    private static let calves: [MuscleContribution] = [.init(.gastrocnemius, 0.7), .init(.soleus, 0.3)]
    private static let soleus: [MuscleContribution] = [.init(.soleus, 0.8), .init(.gastrocnemius, 0.2)]
    private static let abs: [MuscleContribution] = [.init(.rectusAbdominis, 0.7), .init(.obliques, 0.2), .init(.hipFlexors, 0.1)]
    private static let stability: [MuscleContribution] = [.init(.transverseAbdominis, 0.5), .init(.rectusAbdominis, 0.3), .init(.obliques, 0.2)]
    private static let oblique: [MuscleContribution] = [.init(.obliques, 0.7), .init(.transverseAbdominis, 0.3)]
    private static let full: [MuscleContribution] = [.init(.rectusFemoris, 0.25), .init(.gluteusMaximus, 0.25), .init(.anteriorDeltoid, 0.2), .init(.rectusAbdominis, 0.3)]
    private static let quadIsolation: [MuscleContribution] = [.init(.rectusFemoris, 0.4), .init(.vastusLateralis, 0.3), .init(.vastusMedialis, 0.3)]
    private static let hamIsolation: [MuscleContribution] = [.init(.bicepsFemoris, 0.4), .init(.semitendinosus, 0.3), .init(.semimembranosus, 0.3)]
    private static let shrug: [MuscleContribution] = [.init(.upperTrapezius, 0.8), .init(.forearmFlexors, 0.2)]
    private static let dipProfile: [MuscleContribution] = [.init(.lowerPectoral, 0.45), .init(.tricepsLateralHead, 0.4), .init(.anteriorDeltoid, 0.15)]
    private static let carry: [MuscleContribution] = [.init(.forearmFlexors, 0.4), .init(.upperTrapezius, 0.3), .init(.obliques, 0.3)]
    private static let expanded: [TrainingExercise] = [
        movement("incline_push_up", "Incline push-up", .chest, .horizontalPush, [.bodyweight], chest, bodyweight: true, mode: .reps, added: true, family: "push", level: 0),
        movement("decline_push_up", "Decline push-up", .chest, .horizontalPush, [.bodyweight, .bench], incline, bodyweight: true, mode: .reps, added: true, family: "push", level: 2),
        movement("diamond_push_up", "Diamond push-up", .triceps, .horizontalPush, [.bodyweight], closePush, bodyweight: true, mode: .reps, added: true),
        movement("wide_push_up", "Wide push-up", .chest, .horizontalPush, [.bodyweight], chest, bodyweight: true, mode: .reps, added: true),
        movement("weighted_push_up", "Weighted push-up", .chest, .horizontalPush, [.bodyweight, .dumbbells], chest, bodyweight: true, added: true, family: "push", level: 3),
        movement("close_grip_push_up", "Close-grip push-up", .triceps, .horizontalPush, [.bodyweight], closePush, bodyweight: true, mode: .reps, added: true),
        movement("knee_push_up", "Knee push-up", .chest, .horizontalPush, [.bodyweight], chest, bodyweight: true, mode: .reps, added: true),
        movement("paused_push_up", "Paused push-up", .chest, .horizontalPush, [.bodyweight], chest, bodyweight: true, mode: .reps, added: true),
        movement("archer_push_up", "Archer push-up", .chest, .horizontalPush, [.bodyweight], chest, bodyweight: true, mode: .reps, added: true),
        movement("ring_push_up", "Ring push-up", .chest, .horizontalPush, [.rings], chest, bodyweight: true, mode: .reps, added: true),
        movement("db_floor_press", "Dumbbell floor press", .chest, .horizontalPush, [.dumbbells], chest),
        movement("db_bench_press", "Dumbbell bench press", .chest, .horizontalPush, [.dumbbells, .bench], chest),
        movement("single_arm_floor_press", "Single-arm dumbbell floor press", .chest, .horizontalPush, [.dumbbells], chest),
        movement("db_fly", "Dumbbell fly", .chest, .horizontalPush, [.dumbbells, .bench], fly),
        movement("incline_db_fly", "Incline dumbbell fly", .chest, .horizontalPush, [.dumbbells, .bench], inclineFly),
        movement("chest_press", "Chest press", .chest, .horizontalPush, [.chestPress], chest),
        movement("cable_fly", "Cable fly", .chest, .horizontalPush, [.cable], fly),
        movement("low_cable_fly", "Low cable fly", .chest, .horizontalPush, [.cable], incline),
        movement("band_chest_press", "Band chest press", .chest, .horizontalPush, [.bands], chest),
        movement("band_fly", "Band fly", .chest, .horizontalPush, [.bands], fly),
        movement("chin_up", "Chin-up", .back, .verticalPull, [.pullUpBar], pull, bodyweight: true, mode: .reps, added: true),
        movement("neutral_pull_up", "Neutral-grip pull-up", .back, .verticalPull, [.pullUpBar], pull, bodyweight: true, mode: .reps, added: true),
        movement("assisted_pull_up", "Band-assisted pull-up", .back, .verticalPull, [.pullUpBar, .bands], pull, bodyweight: true, mode: .reps, added: true, family: "pull", level: 0),
        movement("weighted_pull_up", "Weighted pull-up", .back, .verticalPull, [.pullUpBar, .dumbbells], pull, bodyweight: true, added: true, family: "pull", level: 2),
        movement("weighted_chin_up", "Weighted chin-up", .back, .verticalPull, [.pullUpBar, .dumbbells], pull, bodyweight: true, added: true),
        movement("inverted_row", "Inverted row", .back, .horizontalPull, [.rings], row, bodyweight: true, mode: .reps, added: true),
        movement("suspension_row", "Suspension row", .back, .horizontalPull, [.suspensionTrainer], row, bodyweight: true, mode: .reps, added: true),
        movement("db_row", "One-arm dumbbell row", .back, .horizontalPull, [.dumbbells], row),
        movement("bent_db_row", "Bent-over dumbbell row", .back, .horizontalPull, [.dumbbells], row),
        movement("chest_supported_row", "Chest-supported dumbbell row", .back, .horizontalPull, [.dumbbells, .bench], row),
        movement("db_pullover", "Dumbbell pullover", .back, .verticalPull, [.dumbbells, .bench], pullover),
        movement("close_lat_pulldown", "Close-grip lat pulldown", .back, .verticalPull, [.latPulldown], pull),
        movement("wide_lat_pulldown", "Wide-grip lat pulldown", .back, .verticalPull, [.latPulldown], pull),
        movement("single_lat_pulldown", "Single-arm lat pulldown", .back, .verticalPull, [.latPulldown], pull),
        movement("straight_arm_pulldown", "Straight-arm pulldown", .back, .verticalPull, [.cable], pullover),
        movement("single_cable_row", "Single-arm cable row", .back, .horizontalPull, [.cable], row),
        movement("barbell_row", "Barbell row", .back, .horizontalPull, [.barbell], row),
        movement("pendlay_row", "Pendlay row", .back, .horizontalPull, [.barbell], row),
        movement("band_row", "Band row", .back, .horizontalPull, [.bands], row),
        movement("band_pulldown", "Band pulldown", .back, .verticalPull, [.bands, .pullUpBar], pull),
        movement("scapular_pull_up", "Scapular pull-up", .back, .verticalPull, [.pullUpBar], pullover, bodyweight: true, mode: .reps, added: true),
        movement("db_shoulder_press", "Dumbbell shoulder press", .shoulders, .verticalPush, [.dumbbells], shoulder),
        movement("seated_db_press", "Seated dumbbell shoulder press", .shoulders, .verticalPush, [.dumbbells, .bench], shoulder),
        movement("arnold_press", "Arnold press", .shoulders, .verticalPush, [.dumbbells], shoulder),
        movement("single_db_press", "Single-arm dumbbell shoulder press", .shoulders, .verticalPush, [.dumbbells], shoulder),
        movement("front_raise", "Dumbbell front raise", .shoulders, .shoulderIsolation, [.dumbbells], front),
        movement("rear_delt_raise", "Dumbbell rear-delt raise", .shoulders, .shoulderIsolation, [.dumbbells], rear),
        movement("incline_rear_raise", "Chest-supported rear-delt raise", .shoulders, .shoulderIsolation, [.dumbbells, .bench], rear),
        movement("cable_lateral_raise", "Cable lateral raise", .shoulders, .shoulderIsolation, [.cable], side),
        movement("cable_rear_fly", "Cable rear-delt fly", .shoulders, .shoulderIsolation, [.cable], rear),
        movement("band_lateral_raise", "Band lateral raise", .shoulders, .shoulderIsolation, [.bands], side),
        movement("band_face_pull", "Band face pull", .shoulders, .shoulderIsolation, [.bands], rear),
        movement("pike_push_up", "Pike push-up", .shoulders, .verticalPush, [.bodyweight], shoulder, bodyweight: true, mode: .reps, added: true),
        movement("wall_handstand_push_up", "Wall handstand push-up", .shoulders, .verticalPush, [.bodyweight], shoulder, bodyweight: true, mode: .reps, added: true),
        movement("db_shrug", "Dumbbell shrug", .shoulders, .shoulderIsolation, [.dumbbells], shrug),
        movement("hammer_curl", "Hammer curl", .biceps, .elbowFlexion, [.dumbbells], hammer),
        movement("incline_curl", "Incline dumbbell curl", .biceps, .elbowFlexion, [.dumbbells, .bench], curl),
        movement("concentration_curl", "Concentration curl", .biceps, .elbowFlexion, [.dumbbells], curl),
        movement("alternating_curl", "Alternating dumbbell curl", .biceps, .elbowFlexion, [.dumbbells], curl),
        movement("cross_body_curl", "Cross-body hammer curl", .biceps, .elbowFlexion, [.dumbbells], hammer),
        movement("reverse_db_curl", "Reverse dumbbell curl", .biceps, .elbowFlexion, [.dumbbells], hammer),
        movement("barbell_curl", "Barbell curl", .biceps, .elbowFlexion, [.barbell], curl),
        movement("cable_curl", "Cable curl", .biceps, .elbowFlexion, [.cable], curl),
        movement("band_curl", "Band curl", .biceps, .elbowFlexion, [.bands], curl),
        movement("zottman_curl", "Zottman curl", .biceps, .elbowFlexion, [.dumbbells], hammer),
        movement("overhead_db_extension", "Overhead dumbbell extension", .triceps, .elbowExtension, [.dumbbells], triceps),
        movement("single_triceps_extension", "Single-arm dumbbell triceps extension", .triceps, .elbowExtension, [.dumbbells], triceps),
        movement("db_skullcrusher", "Dumbbell skullcrusher", .triceps, .elbowExtension, [.dumbbells, .bench], triceps),
        movement("db_kickback", "Dumbbell kickback", .triceps, .elbowExtension, [.dumbbells], triceps),
        movement("band_triceps_extension", "Band triceps extension", .triceps, .elbowExtension, [.bands], triceps),
        movement("cable_overhead_extension", "Cable overhead triceps extension", .triceps, .elbowExtension, [.cable], triceps),
        movement("bench_dip", "Bench dip", .triceps, .elbowExtension, [.bench], triceps, bodyweight: true, mode: .reps, added: true),
        movement("dip", "Dip", .chest, .verticalPush, [.dipStation], dipProfile, bodyweight: true, mode: .reps, added: true),
        movement("weighted_dip", "Weighted dip", .chest, .verticalPush, [.dipStation, .dumbbells], dipProfile, bodyweight: true, added: true),
        movement("close_bench_press", "Close-grip bench press", .triceps, .horizontalPush, [.barbell, .bench], closePush),
        movement("bodyweight_squat", "Bodyweight squat", .quads, .squat, [.bodyweight], squat, bodyweight: true, mode: .reps, added: true, family: "squat", level: 0),
        movement("db_squat", "Dumbbell squat", .quads, .squat, [.dumbbells], squat, family: "squat", level: 2),
        movement("bulgarian_split_squat", "Dumbbell Bulgarian split squat", .quads, .lunge, [.dumbbells, .bench], lunge),
        movement("split_squat", "Split squat", .quads, .lunge, [.bodyweight], lunge, bodyweight: true, mode: .reps, added: true),
        movement("reverse_lunge", "Reverse lunge", .quads, .lunge, [.bodyweight], lunge, bodyweight: true, mode: .reps, added: true),
        movement("walking_lunge", "Walking lunge", .quads, .lunge, [.bodyweight], lunge, bodyweight: true, mode: .reps, added: true),
        movement("db_reverse_lunge", "Dumbbell reverse lunge", .quads, .lunge, [.dumbbells], lunge),
        movement("db_walking_lunge", "Dumbbell walking lunge", .quads, .lunge, [.dumbbells], lunge),
        movement("step_up", "Dumbbell step-up", .quads, .lunge, [.dumbbells, .bench], lunge),
        movement("lateral_lunge", "Lateral lunge", .quads, .lunge, [.bodyweight], lunge, bodyweight: true, mode: .reps, added: true),
        movement("front_squat", "Front squat", .quads, .squat, [.barbell, .squatRack], squat),
        movement("leg_extension", "Leg extension", .quads, .kneeExtension, [.legExtension], quadIsolation),
        movement("wall_sit", "Wall sit", .quads, .squat, [.bodyweight], squat, bodyweight: true, mode: .duration),
        movement("db_rdl", "Dumbbell Romanian deadlift", .hamstrings, .hinge, [.dumbbells], hinge),
        movement("single_leg_rdl", "Single-leg dumbbell RDL", .hamstrings, .hinge, [.dumbbells], hinge),
        movement("bodyweight_rdl", "Bodyweight single-leg hinge", .hamstrings, .hinge, [.bodyweight], hinge, bodyweight: true, mode: .reps, added: true),
        movement("band_rdl", "Band Romanian deadlift", .hamstrings, .hinge, [.bands], hinge),
        movement("db_good_morning", "Dumbbell good morning", .hamstrings, .hinge, [.dumbbells], hinge),
        movement("lying_leg_curl", "Band lying leg curl", .hamstrings, .kneeFlexion, [.bands], hamIsolation),
        movement("sliding_leg_curl", "Sliding leg curl", .hamstrings, .kneeFlexion, [.bodyweight], hamIsolation, bodyweight: true, mode: .reps, added: true),
        movement("glute_bridge", "Glute bridge", .glutes, .hinge, [.bodyweight], glute, bodyweight: true, mode: .reps, added: true),
        movement("single_glute_bridge", "Single-leg glute bridge", .glutes, .hinge, [.bodyweight], glute, bodyweight: true, mode: .reps, added: true),
        movement("db_glute_bridge", "Dumbbell glute bridge", .glutes, .hinge, [.dumbbells], glute),
        movement("db_hip_thrust", "Dumbbell hip thrust", .glutes, .hinge, [.dumbbells, .bench], glute),
        movement("band_glute_bridge", "Band glute bridge", .glutes, .hinge, [.bands], glute),
        movement("band_abduction", "Band hip abduction", .glutes, .hipAbduction, [.bands], abduction),
        movement("side_leg_raise", "Side-lying leg raise", .glutes, .hipAbduction, [.bodyweight], abduction, bodyweight: true, mode: .reps, added: true),
        movement("bodyweight_calf_raise", "Bodyweight calf raise", .calves, .calf, [.bodyweight], calves, bodyweight: true, mode: .reps, added: true),
        movement("single_calf_raise", "Single-leg calf raise", .calves, .calf, [.bodyweight], calves, bodyweight: true, mode: .reps, added: true),
        movement("db_calf_raise", "Dumbbell calf raise", .calves, .calf, [.dumbbells], calves),
        movement("seated_db_calf_raise", "Seated dumbbell calf raise", .calves, .calf, [.dumbbells, .bench], soleus),
        movement("band_calf_raise", "Band calf raise", .calves, .calf, [.bands], calves),
        movement("side_plank", "Side plank", .core, .coreStability, [.bodyweight], oblique, bodyweight: true, mode: .duration),
        movement("hanging_knee_raise", "Hanging knee raise", .core, .coreFlexion, [.pullUpBar], abs, bodyweight: true, mode: .reps, added: true),
        movement("hanging_leg_raise", "Hanging leg raise", .core, .coreFlexion, [.pullUpBar], abs, bodyweight: true, mode: .reps, added: true),
        movement("leg_raise", "Lying leg raise", .core, .coreFlexion, [.bodyweight], abs, bodyweight: true, mode: .reps, added: true),
        movement("crunch", "Crunch", .core, .coreFlexion, [.bodyweight], abs, bodyweight: true, mode: .reps, added: true),
        movement("reverse_crunch", "Reverse crunch", .core, .coreFlexion, [.bodyweight], abs, bodyweight: true, mode: .reps, added: true),
        movement("dead_bug", "Dead bug", .core, .coreStability, [.bodyweight], stability, bodyweight: true, mode: .reps, added: true),
        movement("russian_twist", "Bodyweight Russian twist", .core, .coreFlexion, [.bodyweight], oblique, bodyweight: true, mode: .reps, added: true),
        movement("db_russian_twist", "Dumbbell Russian twist", .core, .coreFlexion, [.dumbbells], oblique),
        movement("bird_dog", "Bird dog", .core, .coreStability, [.bodyweight], stability, bodyweight: true, mode: .reps, added: true),
        movement("hollow_hold", "Hollow-body hold", .core, .coreStability, [.bodyweight], stability, bodyweight: true, mode: .duration),
        movement("mountain_climber", "Mountain climber", .core, .coreStability, [.bodyweight], stability, bodyweight: true, mode: .reps, added: true),
        movement("cable_crunch", "Cable crunch", .core, .coreFlexion, [.cable], abs),
        movement("pallof_press", "Cable Pallof press", .core, .coreStability, [.cable], oblique),
        movement("band_pallof_press", "Band Pallof press", .core, .coreStability, [.bands], oblique),
        movement("burpee", "Burpee", .fullBody, .locomotion, [.bodyweight], full, bodyweight: true, mode: .reps, added: true),
        movement("db_thruster", "Dumbbell thruster", .fullBody, .squat, [.dumbbells], full),
        movement("farmer_carry", "Dumbbell farmer carry", .fullBody, .carry, [.dumbbells], carry, mode: .duration),
        movement("kettlebell_swing", "Kettlebell swing", .fullBody, .hinge, [.kettlebell], hinge),
        movement("suitcase_carry", "Dumbbell suitcase carry", .fullBody, .carry, [.dumbbells], carry, mode: .duration)
    ]
}
