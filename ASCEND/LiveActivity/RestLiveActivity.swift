import Foundation
import ActivityKit

@MainActor enum RestLiveActivity {
    static func synchronize(_ workout: LiveWorkout?, enabled: Bool) {
        guard enabled, ActivityAuthorizationInfo().areActivitiesEnabled, let workout, let end = workout.rest.deadline, end > .now else { finish(); return }
        let exercise = workout.exercises.first { $0.catalogID == workout.rest.exerciseID }
        let next = exercise?.sets.first { $0.completedAt == nil && !$0.isWarmup }
        let target: String
        if let exercise, let next {
            switch exercise.mode {
            case .reps, .weightAndReps: target = next.kilograms > 0 ? "\(next.kilograms.formatted()) kg × \(next.reps) reps" : "\(next.reps) reps"
            case .duration: target = "\(Int(FitnessMath.clamp(next.seconds.isFinite ? next.seconds : 0, 0...86400))) sec"
            case .distance: target = "\(Int(FitnessMath.clamp(next.distanceMeters.isFinite ? next.distanceMeters : 0, 0...500000))) m"
            }
        } else { target = "Next working set" }
        let state = RestActivityAttributes.ContentState(exercise: exercise?.name ?? "Training", target: target, startedAt: end.addingTimeInterval(-(workout.rest.spanSeconds ?? 90)), restEndsAt: end)
        let content = ActivityContent(state: state, staleDate: end)
        if let existing = Activity<RestActivityAttributes>.activities.first(where: { $0.attributes.sessionID == workout.id }) {
            Task { await existing.update(content) }
        } else {
            finish()
            _ = try? Activity.request(attributes: RestActivityAttributes(sessionID: workout.id, sessionTitle: workout.title), content: content, pushType: nil)
        }
    }
    static func finish() {
        let existing = Activity<RestActivityAttributes>.activities
        Task { for activity in existing { await activity.end(nil, dismissalPolicy: .immediate) } }
    }
}
