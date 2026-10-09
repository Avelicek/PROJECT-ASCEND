import Foundation

public struct ExerciseEducation: Sendable {
    public let steps: [String]
    public let cues: [String]
    public let visual: MovementPattern
    public static func guide(_ exercise: TrainingExercise) -> ExerciseEducation {
        let steps: [String]
        switch exercise.id {
        case "push_up", "close_grip_push_up", "wide_push_up": steps = ["Place hands under or slightly outside shoulders; keep a straight line from head to heels.", "Bend elbows to lower your chest under control, then press the floor away."]
        case "plank", "side_plank": steps = ["Support yourself on forearms (or one forearm for side plank), keeping ribs and pelvis stacked.", "Brace the trunk, breathe steadily and stop the hold before your hips sag."]
        case "dead_hang": steps = ["Take a secure grip on a stable overhead bar, with enough clearance beneath you.", "Hold with controlled shoulder position and steady breathing; step down before your grip slips."]
        case "hip_thrust", "db_hip_thrust", "glute_bridge": steps = ["Support your upper back on a stable bench (or lie on the floor for a bridge); plant your feet and brace.", "Drive through the heels to extend your hips, pause with ribs down, then lower under control."]
        case "leg_press": steps = ["Sit with back and pelvis supported, feet planted on the platform; release the machine safeties after taking the load.", "Bend the knees without lifting your pelvis, then press through your feet without locking the knees."]
        case "wall_sit": steps = ["Lean your back against a wall and slide into a comfortable squat.", "Keep feet planted and hold the position while breathing steadily."]
        default:
            switch exercise.pattern {
            case .horizontalPush: steps = ["Set a stable pressing position with your trunk supported or braced.", "Lower the load toward your chest under control, then press without bouncing."]
            case .verticalPush: steps = ["Brace with the load at shoulder height and wrists aligned over elbows.", "Press upward through a comfortable range, then lower under control."]
            case .horizontalPull: steps = ["Keep your torso stable and reach toward the resistance.", "Pull elbows back toward your hips; return slowly without twisting."]
            case .verticalPull: steps = ["Take a secure grip and brace your trunk below the bar or cable.", "Draw elbows down toward your ribs, then return under control."]
            case .squat, .kneeExtension: steps = ["Use a stable stance or seated machine setup, with knees tracking with your feet.", "Bend and straighten the knees through a controlled, comfortable range."]
            case .hinge: steps = ["Brace your trunk and move through the hips while keeping the load close.", "Drive through the hips without rounding or overextending your lower back."]
            case .lunge: steps = ["Take a stable split stance and lower your hips between your feet.", "Press through the working leg to rise; keep your knee aligned with your toes."]
            case .elbowFlexion: steps = ["Keep upper arms steady with a secure grip.", "Bend the elbows without swinging, then lower the resistance slowly."]
            case .elbowExtension: steps = ["Stabilize your upper arms and trunk.", "Straighten the elbows against resistance, then return without moving the shoulders."]
            case .shoulderIsolation: steps = ["Choose a light load and the arm path appropriate to this shoulder variation.", "Move from the shoulder under control; avoid shrugging or swinging."]
            case .coreFlexion: steps = ["Set a supported position and exhale while drawing ribs toward your pelvis.", "Return slowly; avoid pulling on your neck or swinging your legs."]
            case .coreStability, .carry: steps = ["Stack ribs over pelvis and establish stable contact with the floor or load.", "Brace and breathe while holding or carrying; stop before posture breaks down."]
            case .calf: steps = ["Use stable support and keep pressure through the balls of your feet.", "Raise your heels, pause briefly, then lower through a controlled range."]
            case .locomotion: steps = ["Use a comfortable pace and stable footing.", "Maintain relaxed posture and record only observed duration and distance."]
            case .kneeFlexion: steps = ["Align the machine pivot with your knee and keep hips supported.", "Bend the knees against resistance, then extend slowly without lifting your hips."]
            case .hipAbduction: steps = ["Stabilize your pelvis with the resistance against the outside of the legs.", "Move the legs apart without twisting, then return under control."]
            }
        }
        return .init(steps: steps, cues: ["Use a range you can control.", "Keep breathing; match load to repeatable technique.", "The loop illustrates the movement pattern; use the setup instructions for this variation."], visual: exercise.pattern)
    }
}
