import SwiftUI

struct RecordCelebration: View {
    let record: RecordImprovement
    var pending = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var body: some View {
        PremiumCard(role: .hero, tint: AppColor.gold) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Image(systemName: "trophy.fill").foregroundStyle(AppColor.gold); Eyebrow(text: pending ? "PR · SAVE ON FINISH" : "NEW PERSONAL RECORD") }
                Text(record.exerciseName).font(.subheadline.weight(.medium)).foregroundStyle(AppColor.secondary)
                Text("\(record.value.formatted(.number.precision(.fractionLength(0...1)))) \(record.unit)")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold)).foregroundStyle(AppColor.goldGradient).monospacedDigit()
                HStack {
                    Text(record.title).font(.caption).foregroundStyle(AppColor.muted)
                    Spacer(minLength: 4)
                    Text("+\((record.value - record.previous).formatted(.number.precision(.fractionLength(0...1))))").font(.headline).foregroundStyle(AppColor.gold)
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
                            HStack(spacing: 12) {
                                Text(muscle.name).font(.caption).foregroundStyle(AppColor.secondary).frame(width: 72, alignment: .leading)
                                LinearProgress(progress: muscle.setLoad / max(1, summary.muscles.map(\.setLoad).max() ?? 1), tint: AppColor.recovery, height: 5)
                                Text(muscle.label).font(.caption2).foregroundStyle(AppColor.recovery).frame(width: 42, alignment: .trailing)
                            }
                        }
                        if summary.muscles.isEmpty { Text("No working load recorded.").font(.caption).foregroundStyle(AppColor.muted) }
                        HStack { Text("Recovery estimates updated").font(.caption2).foregroundStyle(AppColor.muted); Spacer(); Text("\(summary.progressedExercises) progressed").font(.caption2).foregroundStyle(AppColor.positive) }
                    }
                }
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
