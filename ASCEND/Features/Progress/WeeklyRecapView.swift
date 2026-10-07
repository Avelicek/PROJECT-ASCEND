import SwiftUI

struct WeeklyRecapView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private var recap: WeeklyRecap { store.weeklyRecap }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FeatureHeader(eyebrow: "LAST 7 LOCAL DAYS", title: "Your weekly ascent")
                PremiumCard(accented: true) {
                    HStack(spacing: 18) {
                        RankBadgeView(rank: recap.currentRank, size: 100, animated: true)
                        VStack(alignment: .leading, spacing: 8) {
                            CountUpText(value: Double(recap.eloDelta), signed: true).font(.largeTitle.weight(.semibold))
                            Text("FINALIZED ELO").font(.caption2).foregroundStyle(AppColor.muted)
                            Text(recap.previousRank == recap.currentRank ? recap.currentRank.title : "\(recap.previousRank.title) → \(recap.currentRank.title)")
                                .font(.caption.weight(.semibold)).foregroundStyle(AppColor.blue)
                        }
                    }
                }
                MetricStrip(metrics: [GlanceMetric(title: "Workouts", value: "\(recap.workouts)", symbol: "dumbbell", tint: AppColor.positive),
                    GlanceMetric(title: "Training days", value: "\(recap.trainingDays)/7", symbol: "calendar"),
                    GlanceMetric(title: "New PRs", value: "\(recap.records)", symbol: "trophy", tint: AppColor.warning)])
                PremiumCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Eyebrow(text: "CONSISTENCY")
                        HStack { Text("Nutrition adherence"); Spacer(); Text(recap.fuelAdherence.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—").foregroundStyle(AppColor.blue) }.font(.subheadline)
                        LinearProgress(progress: recap.fuelAdherence ?? 0, tint: AppColor.blue)
                        Text("\(recap.fuelDays)/7 days logged · calorie range and protein goal both met").font(.caption).foregroundStyle(AppColor.muted)
                        HStack { StatBlock(title: "Objectives", value: "\(recap.objectivesCompleted)/\(recap.objectivesDue)"); StatBlock(title: "Recovery protected", value: "\(recap.recoveryProtected)", tint: AppColor.positive) }
                    }
                }
                PremiumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Eyebrow(text: "DIRECTION")
                        HStack {
                            StatBlock(title: "Trend change", value: recap.trendChange.map { "\($0.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always()))) kg" } ?? "Building baseline")
                            StatBlock(title: "Momentum", value: recap.momentum.map { "\($0.formatted(.number.precision(.fractionLength(0)).sign(strategy: .always())))%" } ?? "—", tint: AppColor.blue)
                        }
                        Text("Readiness history is not yet established; current estimates stay in Body intelligence.").font(.caption).foregroundStyle(AppColor.muted)
                    }
                }
                PremiumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Eyebrow(text: "STREAKS · SECONDARY TO ELO")
                        ForEach(Array(store.streaks.enumerated()), id: \.offset) { _, streak in
                            HStack { Text(streak.0).font(.subheadline); Spacer(); Text("\(streak.1) \(streak.2)").font(.headline).foregroundStyle(AppColor.blue) }
                        }
                        Text("Training counts weeks with two distinct training days. Perfect days require fuel goals and every due objective completed or recovery protected.").font(.caption).foregroundStyle(AppColor.muted)
                    }
                }
                PremiumCard {
                    VStack(alignment: .leading, spacing: 10) {
                        ContextExplanationView(focus: "Week explained", facts: [store.weeklyExplanation], confidence: recap.fuelDays >= 4 && recap.trainingDays >= 2 ? .medium : .low)
                    }
                }
                PrimaryAction(title: "Done", symbol: "checkmark") { dismiss() }
            }.padding(20)
        }.background(AppColor.background).navigationTitle("Weekly recap").navigationBarTitleDisplayMode(.inline)
    }
}
