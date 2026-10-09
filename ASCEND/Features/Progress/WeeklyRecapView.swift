import SwiftUI

struct WeeklyRecapView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private var recap: WeeklyRecap { store.weeklyRecap }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FeatureHeader(eyebrow: "WEEK \(store.policy.calendar.component(.weekOfYear, from: store.now)) · LAST 7 DAYS", title: "Your ascent")
                PremiumCard(accented: true) {
                    HStack(spacing: 18) {
                        RankBadgeView(rank: recap.currentRank, size: 100, animated: true)
                        VStack(alignment: .leading, spacing: 8) {
                            CountUpText(value: Double(recap.eloDelta), signed: true).font(.largeTitle.weight(.semibold))
                                .foregroundStyle(recap.eloDelta < 0 ? AppColor.negative : AppColor.positive)
                            Text("FINALIZED ELO").font(.caption2).foregroundStyle(AppColor.muted)
                            Text(recap.previousRank == recap.currentRank ? recap.currentRank.title : "\(recap.previousRank.title) → \(recap.currentRank.title)")
                                .font(.caption.weight(.semibold)).foregroundStyle(AppColor.blue)
                        }
                    }
                }
                TrendGraphic(values: store.history.suffix(7).map { Double($0.elo) }, tint: AppColor.elo).padding(.horizontal, 10)
                if let highlight = store.weeklyStrengthHighlight {
                    PremiumCard(role: .status, tint: AppColor.gold) {
                        VStack(alignment: .leading, spacing: 8) {
                            Eyebrow(text: "BEST OBSERVED STRENGTH IMPROVEMENT")
                            Text(highlight.0).font(.headline).foregroundStyle(AppColor.gold)
                            Text("+\(highlight.1.formatted(.number.precision(.fractionLength(1))))% estimated 1RM").font(.title3.weight(.semibold)).foregroundStyle(AppColor.goldGradient)
                        }
                    }
                }
                MetricStrip(metrics: [GlanceMetric(title: "Workouts", value: "\(recap.workouts)", symbol: "dumbbell", tint: AppColor.positive),
                    GlanceMetric(title: "Training days", value: "\(recap.trainingDays)/7", symbol: "calendar"),
                    GlanceMetric(title: "New PRs", value: "\(recap.records)", symbol: "trophy", tint: AppColor.gold)])
                PremiumCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Eyebrow(text: "CONSISTENCY")
                        HStack { Text("Nutrition adherence"); Spacer(); Text(recap.fuelAdherence.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—").foregroundStyle(AppColor.blue) }.font(.subheadline)
                        LinearProgress(progress: recap.fuelAdherence ?? 0, tint: AppColor.nutrition)
                        Text("\(recap.fuelDays)/7 days logged · calorie range and protein goal both met").font(.caption).foregroundStyle(AppColor.muted)
                        HStack { StatBlock(title: "Objectives", value: "\(recap.objectivesCompleted)/\(recap.objectivesDue)"); StatBlock(title: "Recovery protected", value: "\(recap.recoveryProtected)", tint: AppColor.positive) }
                    }
                }
                PremiumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Eyebrow(text: "DIRECTION")
                        HStack {
                            StatBlock(title: "Trend change", value: recap.trendChange.map { "\($0.formatted(.number.precision(.fractionLength(2)).sign(strategy: .always()))) kg" } ?? "Building baseline")
                        }
                        Text("Recovery · current estimate only").font(.caption2).foregroundStyle(AppColor.muted)
                    }
                }
                PremiumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Eyebrow(text: "CONSISTENCY STREAKS")
                        ForEach(Array(store.streaks.enumerated()), id: \.offset) { _, streak in
                            HStack { Text(streak.0).font(.subheadline); Spacer(); Text("\(streak.1) \(streak.2)").font(.headline).foregroundStyle(AppColor.blue) }
                        }
                        DisclosureGroup("How streaks count") { Text("Training: two distinct days per week. Perfect: fuel goals and all due objectives completed or protected.").font(.caption).foregroundStyle(AppColor.muted).padding(.top, 8) }.font(.caption2)
                    }
                }
                PremiumCard {
                    VStack(alignment: .leading, spacing: 10) {
                        ContextExplanationView(focus: "Week explained", facts: [store.weeklyExplanation], confidence: recap.fuelDays >= 4 && recap.trainingDays >= 2 ? .medium : .low)
                    }
                }
                WeeklyCoachAnalysisView()
                PrimaryAction(title: "Done", symbol: "checkmark") { dismiss() }
            }.padding(20)
        }.background(AppColor.background).accessibilityIdentifier("screen.weeklyrecap").navigationTitle("Weekly recap").navigationBarTitleDisplayMode(.inline)
    }
}
