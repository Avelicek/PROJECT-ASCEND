import SwiftUI

struct RecordCelebration: View {
    let record: RecordImprovement
    var pending = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var body: some View {
        PremiumCard(role: .hero, tint: SemanticStatus.excellent.tint) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Image(systemName: "trophy.fill").foregroundStyle(SemanticStatus.excellent.tint); Eyebrow(text: pending ? "PR · SAVE ON FINISH" : "NEW PERSONAL RECORD") }
                Text(record.exerciseName).font(.subheadline.weight(.medium)).foregroundStyle(AppColor.secondary)
                Text("\(record.value.formatted(.number.precision(.fractionLength(0...1)))) \(record.unit)")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold)).foregroundStyle(SemanticStatus.excellent.gradient).monospacedDigit()
                HStack {
                    Text(record.title).font(.caption).foregroundStyle(AppColor.muted)
                    Spacer(minLength: 4)
                    Text("+\((record.value - record.previous).formatted(.number.precision(.fractionLength(0...1))))").font(.headline).foregroundStyle(SemanticStatus.excellent.tint)
                }
                Text("Previous · \(record.previous.formatted(.number.precision(.fractionLength(0...1)))) \(record.unit)").font(.caption2).foregroundStyle(AppColor.muted)
            }
        }.scaleEffect(appeared || reduceMotion || AppMotion.snapshotMode ? 1 : 0.94)
            .onAppear { withAnimation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.reward) { appeared = true } }
    }
}

struct WorkoutCompletionView: View {
    @Environment(AppStore.self) private var store
    let summary: CompletedWorkoutSummary
    let done: () -> Void
    private var bestExercise: (String, String)? {
        if let record = summary.records.filter({ $0.kind == .estimatedOneRepMax && $0.previous > 0 }).max(by: { ($0.value / $0.previous) < ($1.value / $1.previous) }) {
            return (record.exerciseName, "+\(((record.value / record.previous - 1) * 100).formatted(.number.precision(.fractionLength(1))))% estimated 1RM")
        }
        let entries = store.sessions.first { $0.id == summary.id }?.exercises ?? []
        let volumes = entries.filter { $0.trackingMode == .reps || $0.trackingMode == .weightAndReps }.map { ($0.exerciseName, WorkoutEngine().volume($0.sets.filter { !$0.isWarmup }.map(\.performance))) }
        return volumes.filter { $0.1 > 0 }.max { $0.1 < $1.1 }.map { ($0.0, "\($0.1.formatted(.number.precision(.fractionLength(0)))) kg · most external volume") }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PremiumCard(role: .hero, tint: AppColor.positive) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack { Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColor.positive); Eyebrow(text: "SESSION COMPLETE") }
                        Text(WorkoutClockText.duration(summary.durationSeconds)).font(.system(size: 52, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(AppColor.text)
                        HStack {
                            StatBlock(title: "Exercises", value: "\(summary.exerciseCount)", tint: AppColor.strength)
                            StatBlock(title: "Working sets", value: "\(summary.workingSets)", tint: AppColor.positive)
                            StatBlock(title: "PRs", value: "\(summary.records.count)", tint: AppColor.gold)
                        }
                    }
                }
                HStack {
                    StatBlock(title: "Volume · kg", value: summary.volumeKG.formatted(.number.precision(.fractionLength(0))), tint: AppColor.strength)
                    VStack(alignment: .leading, spacing: 7) {
                        Eyebrow(text: "PENDING ELO")
                        CountUpText(value: Double(summary.pendingELO), signed: true).font(.title.weight(.semibold)).foregroundStyle(AppColor.eloGradient)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.horizontal, 8)
                if store.brainArchive.settings.enabled {
                    ContextExplanationView(focus: "Session read", facts: PersonalBrainEngine().sessionRead(summary), confidence: store.brainDecision.confidence)
                        .accessibilityIdentifier("brain.session.read")
                }
                PremiumCard(role: .analytics) {
                    VStack(alignment: .leading, spacing: 16) {
                        Eyebrow(text: "MUSCLE LOAD")
                        ForEach(summary.muscles) { muscle in
                            MuscleLoadRow(name: muscle.name, load: muscle.setLoad, maximum: summary.muscles.map(\.setLoad).max() ?? 1)
                        }
                        if summary.muscles.isEmpty { Text("No working load recorded.").font(.caption).foregroundStyle(AppColor.muted) }
                        HStack { Text("Recovery estimates updated").font(.caption2).foregroundStyle(AppColor.muted); Spacer(); Text("\(summary.progressedExercises) progressed").font(.caption2).foregroundStyle(AppColor.positive) }
                    }
                }
                WorkoutLoadImpactView(sessionID: summary.id)
                if let bestExercise {
                    PremiumCard(role: .status, tint: AppColor.strength) {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "SESSION HIGHLIGHT")
                            Text(bestExercise.0).font(.headline).foregroundStyle(AppColor.strength)
                            Text(bestExercise.1).font(.caption).foregroundStyle(AppColor.secondary)
                        }
                    }
                }
                ForEach(summary.records) { record in RecordCelebration(record: record) }
                PrimaryAction(title: "Done", symbol: "checkmark", tint: AppColor.positive, action: done).accessibilityIdentifier("live.summary.done")
            }.padding(20)
        }.accessibilityIdentifier("screen.workoutsummary").featureBackground(tint: AppColor.positive)
    }
}


/// Compares actual same-day weighted stimulus before and after the saved session.
struct WorkoutLoadImpactView: View {
    @Environment(AppStore.self) private var store
    let sessionID: UUID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var anatomy = false
    @State private var after = false
    private var loads: (before: [Muscle: Double], after: [Muscle: Double]) {
        var prior: [Muscle: Double] = [:], current: [Muscle: Double] = [:]
        for session in store.sessions where store.policy.sameDay(session.evaluationDate, store.now) {
            for exercise in session.exercises {
                let muscleLoad = TrainingLoadEngine().muscles(stimulus: store.stimulus(for: exercise, quick: session.isQuickLog), contributions: exercise.contributions)
                for (muscle, value) in muscleLoad {
                    current[muscle, default: 0] += value
                    if session.id != sessionID { prior[muscle, default: 0] += value }
                }
            }
        }
        return (prior, current)
    }
    var body: some View {
        let values = loads
        let groups = Dictionary(grouping: values.after.keys, by: \.group).map { group, muscles in
            (group, muscles.reduce(0) { $0 + (values.before[$1] ?? 0) }, muscles.reduce(0) { $0 + (values.after[$1] ?? 0) })
        }.sorted { $0.2 > $1.2 }
        let maximum = max(1, groups.first?.2 ?? 1)
        PremiumCard(role: .analytics) {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "YOUR ACTION CHANGED THE SYSTEM")
                Text("Today's modeled stimulus · before → after").font(.caption).foregroundStyle(AppColor.muted)
                ForEach(groups.prefix(5), id: \.0) { name, before, final in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack { Text(name); Spacer(); Text("\(before.formatted(.number.precision(.fractionLength(1)))) → \(final.formatted(.number.precision(.fractionLength(1))))") }.font(.caption)
                        LinearProgress(progress: (after ? final : before) / maximum, tint: AppColor.strength)
                    }
                }
                Button(anatomy ? "Hide muscle map" : "See the updated muscle map", systemImage: "figure.stand") { anatomy.toggle() }.font(.caption).frame(minHeight: 44)
                if anatomy {
                    let highest = max(0.01, values.after.values.max() ?? 1)
                    ExerciseAnatomyPreview(contributions: values.after.map { .init($0.key, $0.value / highest) })
                }
            }
        }.accessibilityIdentifier("workout.load.impact")
            .onAppear { withAnimation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.reveal) { after = true } }
    }
}
