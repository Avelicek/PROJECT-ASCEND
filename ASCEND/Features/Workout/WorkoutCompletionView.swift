import SwiftUI

struct RecordCelebration: View {
    let record: RecordImprovement
    var pending = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var body: some View {
        PremiumCard(accented: true) {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Image(systemName: "trophy.fill").foregroundStyle(AppColor.warning); Eyebrow(text: pending ? "NEW PR · PENDING FINISH" : "NEW PERSONAL RECORD") }
                Text(record.exerciseName).font(.headline)
                Text(record.title).font(.caption).foregroundStyle(AppColor.muted)
                HStack(alignment: .firstTextBaseline) {
                    Text("\(record.previous.formatted(.number.precision(.fractionLength(0...1)))) → \(record.value.formatted(.number.precision(.fractionLength(0...1)))) \(record.unit)")
                        .font(.title3.weight(.semibold)).monospacedDigit()
                    Spacer()
                    Text("+\((record.value - record.previous).formatted(.number.precision(.fractionLength(0...1))))").font(.caption.weight(.semibold)).foregroundStyle(AppColor.positive)
                }
            }
        }.scaleEffect(appeared || reduceMotion || AppMotion.snapshotMode ? 1 : 0.96)
            .onAppear { withAnimation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.interaction) { appeared = true } }
    }
}

struct WorkoutCompletionView: View {
    let summary: CompletedWorkoutSummary
    let done: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FeatureHeader(eyebrow: "SESSION COMPLETE", title: "Work recorded.")
                MetricStrip(metrics: [
                    GlanceMetric(title: "Minutes", value: "\(Int(summary.durationSeconds / 60))", symbol: "timer"),
                    GlanceMetric(title: "Exercises", value: "\(summary.exerciseCount)", symbol: "dumbbell"),
                    GlanceMetric(title: "Working sets", value: "\(summary.workingSets)", symbol: "checkmark.circle", tint: AppColor.positive)
                ])
                PremiumCard(accented: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { StatBlock(title: "Volume · kg", value: summary.volumeKG.formatted(.number.precision(.fractionLength(0))), tint: AppColor.blue)
                            StatBlock(title: "Set-load index", value: summary.trainingLoad.formatted(.number.precision(.fractionLength(1)))) }
                        HStack { Text("\(summary.progressedExercises) exercises progressed"); Spacer(); PillStatus(title: "\(summary.records.count) PRs", tint: AppColor.warning) }.font(.caption)
                        ForEach(summary.muscles) { muscle in
                            HStack { Text(muscle.name).font(.subheadline); Spacer(); PillStatus(title: "\(muscle.label.uppercased()) LOAD", tint: AppColor.blue) }
                        }
                    }
                }
                ForEach(summary.records) { record in RecordCelebration(record: record) }
                PremiumCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "DAILY ELO CONTRIBUTION")
                        CountUpText(value: Double(summary.pendingELO), signed: true).font(.system(.largeTitle, design: .rounded, weight: .semibold)).foregroundStyle(AppColor.positive)
                        Text("Pending daily evaluation · recovery and objectives updated").font(.caption).foregroundStyle(AppColor.muted)
                    }
                }
                PrimaryAction(title: "Done", symbol: "checkmark", action: done).accessibilityIdentifier("live.summary.done")
            }.padding(20)
        }.accessibilityIdentifier("screen.workoutsummary").featureBackground()
    }
}
