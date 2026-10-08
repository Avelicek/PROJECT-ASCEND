import Foundation
import ActivityKit

enum RestLiveActivity {
    static func synchronize(_ workout: LiveWorkout?, enabled: Bool) {
        guard enabled, ActivityAuthorizationInfo().areActivitiesEnabled, let workout, let end = workout.rest.deadline, end > .now else {
            finish()
            return
        }

        let exercise = workout.exercises.first { $0.catalogID == workout.rest.exerciseID }
        let next = exercise?.sets.first { $0.completedAt == nil && !$0.isWarmup }
        let target: String
        if let exercise, let next {
            switch exercise.mode {
            case .reps, .weightAndReps:
                target = next.kilograms > 0 ? "\(next.kilograms.formatted()) kg × \(next.reps) reps" : "\(next.reps) reps"
            case .duration:
                target = "\(Int(FitnessMath.clamp(next.seconds.isFinite ? next.seconds : 0, 0...86400))) sec"
            case .distance:
                target = "\(Int(FitnessMath.clamp(next.distanceMeters.isFinite ? next.distanceMeters : 0, 0...500000))) m"
            }
        } else {
            target = "Next working set"
        }

        let sessionID = workout.id
        let sessionTitle = workout.title
        let state = RestActivityAttributes.ContentState(
            exercise: exercise?.name ?? "Training",
            target: target,
            startedAt: end.addingTimeInterval(-(workout.rest.spanSeconds ?? 90)),
            restEndsAt: end
        )
        let content = ActivityContent(state: state, staleDate: end)

        Task {
            if let existing = Activity<RestActivityAttributes>.activities.first(where: { $0.attributes.sessionID == sessionID }) {
                await existing.update(content)
            } else {
                await endAllActivities()
                _ = try? Activity.request(
                    attributes: RestActivityAttributes(sessionID: sessionID, sessionTitle: sessionTitle),
                    content: content,
                    pushType: nil
                )
            }
        }
    }

    static func finish() {
        Task {
            await endAllActivities()
        }
    }

    private static func endAllActivities() async {
        for activity in Activity<RestActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
