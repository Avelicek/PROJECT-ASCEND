import SwiftUI

struct ExerciseEffortReview: View {
    @Environment(AppStore.self) private var store
    let exercise: LiveExercise
    private var measuresReps: Bool { exercise.mode == .reps || exercise.mode == .weightAndReps }
    var body: some View {
        if !exercise.completedWorkingSets.isEmpty {
            DisclosureGroup("Effort review · \(exercise.completedWorkingSets.filter { $0.rpe != nil }.count)/\(exercise.completedWorkingSets.count) rated") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(measuresReps ? "How many reps were left? Optional; rate all sets in seconds." : "How hard did each set feel? Optional; rate all sets in seconds.").font(.caption).foregroundStyle(AppColor.muted)
                    ForEach(Array(exercise.completedWorkingSets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Set \(index + 1)").font(.subheadline)
                            Spacer()
                            Menu {
                                ForEach(EffortRating.allCases, id: \.self) { rating in Button(measuresReps ? rating.title : rating.intensityTitle) { store.setEffort(exerciseID: exercise.id, setID: set.id, rating: rating) } }
                                Button("Skip / clear") { store.setEffort(exerciseID: exercise.id, setID: set.id, rating: nil) }
                            } label: {
                                Text(set.rpe.map { effort in
                                    if !measuresReps { return EffortRating(rawValue: min(10, max(6, Int(effort.rounded()))))?.intensityTitle ?? "Rate effort" }
                                    return effort >= 10 ? "0 left · failure" : effort <= 6 ? "4+ left" : "\(Int(10 - effort)) left"
                                } ?? "Rate effort").font(.subheadline.weight(.medium)).frame(minHeight: 44)
                            }.accessibilityIdentifier("effort.\(index)")
                        }
                    }
                }.padding(.top, 10)
            }.font(.subheadline).accessibilityIdentifier("live.effort.review")
        }
    }
}
struct LiveAutoregulationCard: View {
    @Environment(AppStore.self) private var store
    let exercise: LiveExercise
    @State private var dismissed: Set<UUID> = []
    var body: some View {
        if let advice = AdaptiveRestEngine().advice(exercise), !dismissed.contains(advice.id) {
            PremiumCard(role: .status, tint: AppColor.warning) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "PERFORMANCE DROP DETECTED")
                    Text(advice.explanation).font(.subheadline).foregroundStyle(AppColor.secondary)
                    Button("Accept · +45 sec rest") { store.acceptAutoregulation(advice, exerciseID: exercise.id, lowerLoad: false); dismissed.insert(advice.id) }.frame(minHeight: 44)
                    if let kilograms = advice.kilograms {
                        Button("Accept · \(exercise.completedWorkingSets.last?.kilograms.formatted() ?? "") → \(kilograms.formatted()) kg for remaining sets") { store.acceptAutoregulation(advice, exerciseID: exercise.id, lowerLoad: true); dismissed.insert(advice.id) }.frame(minHeight: 44)
                    }
                    Button("Ignore") { dismissed.insert(advice.id) }.font(.caption).foregroundStyle(AppColor.muted).frame(minHeight: 44)
                }
            }.accessibilityIdentifier("live.autoregulation")
        }
    }
}
struct TimedExerciseView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var phase
    var body: some View {
        if let clock = store.activeWorkout?.exerciseClock, let exercise = store.activeWorkout?.exercises.first(where: { $0.id == clock.exerciseID }) {
            VStack(spacing: 28) {
                Eyebrow(text: "TIMED EXERCISE")
                Text(exercise.name).font(.title.weight(.semibold)).accessibilityIdentifier("screen.exercisetimer")
                let index = (exercise.sets.firstIndex { $0.id == clock.setID } ?? 0) + 1
                Text("SET \(index) / \(exercise.sets.count)").font(.caption).foregroundStyle(AppColor.muted)
                TimelineView(.animation(minimumInterval: 1, paused: phase != .active || clock.startedAt == nil || AppMotion.snapshotMode)) { timeline in
                    let seconds = Int(clock.elapsed(at: store.isDemo ? store.actionDate() : timeline.date))
                    Text(String(format: "%02d:%02d", seconds / 60, seconds % 60)).font(.system(size: 76, weight: .light, design: .rounded)).monospacedDigit().contentTransition(.numericText())
                }
                let target = exercise.sets.first { $0.id == clock.setID }?.seconds ?? 60
                Text("Target \(WorkoutClockText.duration(target))").font(.subheadline).foregroundStyle(AppColor.secondary)
                Spacer()
                PrimaryAction(title: clock.startedAt == nil ? "Resume" : "Pause", symbol: clock.startedAt == nil ? "play.fill" : "pause.fill") { store.pauseExerciseClock() }.accessibilityIdentifier("exercise.timer.pause")
                PrimaryAction(title: "Finish set", symbol: "checkmark", tint: AppColor.positive) { _ = store.finishExerciseClock() }.accessibilityIdentifier("exercise.timer.finish")
                Text("Elapsed time is saved using the clock, including while your iPhone is locked.").font(.caption).foregroundStyle(AppColor.muted)
            }.padding(28).padding(.top, 24).frame(maxWidth: .infinity, maxHeight: .infinity).background(AppColor.background).interactiveDismissDisabled()
        }
    }
}
