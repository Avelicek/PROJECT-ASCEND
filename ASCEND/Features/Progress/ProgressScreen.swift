import SwiftUI
import Charts

struct ProgressScreen: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showELO = false
    @State private var showRecap = false
    @State private var showAnalytics = false
    @State private var showExercises = false
    @State private var showRecords = false
    @State private var settingTarget = false
    private var weekStart: Date {
        let weekday = (store.policy.calendar.component(.weekday, from: store.now) + 5) % 7
        return store.policy.adding(days: -weekday, to: store.policy.start(of: store.now))
    }
    private var workouts: Int { store.sessions.filter { !$0.isQuickLog && $0.hasWorkingSets && $0.evaluationDate >= weekStart && $0.evaluationDate <= store.now }.count }
    private var weighIns: Int { Set(store.weights.filter { $0.measuredAt >= weekStart && $0.measuredAt <= store.now }.map { store.policy.key(for: $0.measuredAt) }).count }
    private var fuelDays: Int { Set(store.nutrition.filter { $0.date >= weekStart && $0.date <= store.now }.map(\.dayKey)).count }
    private var weekELO: Int { store.history.filter { $0.date >= weekStart && $0.date < store.policy.start(of: store.now) }.reduce(0) { $0 + $1.delta } + store.projectedScore.delta }
    private var summary: String {
        if store.ownerSystem.sickActive { return "Recovery takes priority this week. Your training goals are protected." }
        if let target = store.ownerSystem.weeklyWorkoutTarget, workouts < target { return "\(target - workouts) more workouts would meet your weekly plan. Choose days when you feel recovered." }
        if let pace = store.goalProjection.weeklyChange, let current = store.goalProjection.current, let target = store.goalProjection.target, (target - current) * pace > 0 { return "You're moving toward your goal. Keep your training and fuel routine steady." }
        return "Keep logging your weight and fuel so we can see your direction more clearly."
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FeatureHeader(eyebrow: "YOUR LONG-TERM PROGRESS", title: "Progress")
                GoalProjectionCard()
                PremiumCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Eyebrow(text: "THIS WEEK")
                        Text("\(weekELO.formatted(.number.sign(strategy: .always()))) ELO").font(.title2.weight(.semibold)).contentTransition(.numericText())
                        MetricStrip(metrics: [GlanceMetric(title: "Workouts", value: "\(workouts)", symbol: "dumbbell"), GlanceMetric(title: "Weigh-ins", value: "\(weighIns)", symbol: "scalemass"), GlanceMetric(title: "Fuel days", value: "\(fuelDays)", symbol: "flame")])
                        Text(summary).font(.subheadline).foregroundStyle(AppColor.secondary)
                        Button("Review this week", systemImage: "arrow.up.right") { showRecap = true }.frame(minHeight: 44)
                        Text("Monday–today · includes today's live ELO; past days stay finalized.").font(.caption2).foregroundStyle(AppColor.muted)
                    }
                }
                weightCard(store.report(window: .month))
                HStack {
                    Button("Log weight", systemImage: "plus") { store.presentedSheet = .weight }.frame(minHeight: 44)
                    Spacer()
                    ContextualCoachButton(title: "Why this trend?", question: "Why is my bodyweight trend slowing?")
                }
                strengthCard
                trainingCard
                Eyebrow(text: "HISTORY")
                Button("Daily ELO history", systemImage: "chart.line.uptrend.xyaxis") { showELO = true }.frame(minHeight: 44)
                Button("Personal records", systemImage: "trophy") { showRecords = true }.frame(minHeight: 44)
                DisclosureGroup("More details") {
                    Button("Explore training and rating charts") { showAnalytics = true }.frame(minHeight: 44)
                    Text("Today's score: \(store.projectedScore.delta.formatted(.number.sign(strategy: .always()))) · finalized total: \(store.currentELO) ELO.").font(.caption)
                }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, 32)
        }.accessibilityIdentifier("screen.progress").featureBackground(tint: AppColor.elo)
            .animation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.interaction, value: store.revision)
            .sheet(isPresented: $showELO) { NavigationStack { ScoreBreakdownView().environment(store) }.preferredColorScheme(.dark) }
            .sheet(isPresented: $showRecap) { NavigationStack { WeeklyRecapView().environment(store) }.preferredColorScheme(.dark) }
            .sheet(isPresented: $showAnalytics) { NavigationStack { TrainingAnalyticsView().environment(store) }.preferredColorScheme(.dark) }
            .sheet(isPresented: $showExercises) { NavigationStack { TrainingAnalyticsView(exercises: true).environment(store) }.preferredColorScheme(.dark) }
            .sheet(isPresented: $showRecords) { NavigationStack { RecordHistoryView().environment(store) }.preferredColorScheme(.dark) }
    }
    private var strengthCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "STRENGTH · LAST 30 DAYS")
                let trends = strengthTrends
                if trends.isEmpty { Text("Record two comparable sessions to reveal your strength trend.").font(.subheadline).foregroundStyle(AppColor.secondary) }
                ForEach(trends.prefix(3), id: \.0) { name, change in
                    HStack { Text(name); Spacer(); Text(abs(change) < 1 ? "Stable" : "\(change.formatted(.number.precision(.fractionLength(1)).sign(strategy: .always())))%") }.font(.subheadline)
                }
                Button("Exercise details", systemImage: "arrow.up.right") { showExercises = true }.frame(minHeight: 44)
            }
        }
    }
    private var strengthTrends: [(String, Double)] {
        let lower = store.policy.adding(days: -30, to: store.now)
        let groups = Dictionary(grouping: store.exerciseHistory.filter { !$0.quick && $0.mode == .weightAndReps && $0.date >= lower && $0.date <= store.now }, by: \.exerciseID)
        var output: [(String, Double)] = []
        for (id, entries) in groups {
            let values = entries.sorted { $0.date < $1.date }.compactMap { entry in
                WorkoutEngine().recordCandidates(entry.working.map(\.performance)).first { $0.kind == .estimatedOneRepMax }?.value
            }
            guard values.count >= 2, let first = values.first, first > 0, let last = values.last else { continue }
            output.append((store.trainingMetadata(id)?.name ?? id, (last / first - 1) * 100))
        }
        return output.sorted { $0.0 < $1.0 }
    }
    private var trainingCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "TRAINING · THIS WEEK")
                Text(store.ownerSystem.weeklyWorkoutTarget.map { "\(workouts) sessions / target \($0)" } ?? "\(workouts) workouts completed").font(.headline)
                Button(settingTarget ? "Done" : "Set weekly target") { settingTarget.toggle() }.font(.caption).frame(minHeight: 44)
                if settingTarget {
                    Stepper("\(store.ownerSystem.weeklyWorkoutTarget ?? 3) workouts / week", value: Binding(get: { store.ownerSystem.weeklyWorkoutTarget ?? 3 }, set: { value in _ = store.saveOwnerSystem { $0.weeklyWorkoutTarget = value } }), in: 1...7)
                }
                let groups = store.weeklyExposure.filter { ["Chest", "Back", "Legs"].contains($0.0) }
                let maximum = max(1, groups.map { $0.1 }.max() ?? 1)
                ForEach(groups, id: \.0) { name, amount in HStack { Text(name).font(.caption).frame(width: 55, alignment: .leading); LinearProgress(progress: amount / maximum, tint: AppColor.strength) } }
                Text(store.ownerSystem.sickActive ? "Rest is part of your plan while you're sick." : balanceConclusion).font(.subheadline).foregroundStyle(AppColor.secondary)
                ContextualCoachButton(title: "Talk about my training", question: "What should I train this week?")
            }
        }
    }
    private var balanceConclusion: String {
        let groups = store.weeklyExposure
        let legs = groups.first { $0.0 == "Legs" }?.1 ?? 0
        let upper = max(groups.first { $0.0 == "Chest" }?.1 ?? 0, groups.first { $0.0 == "Back" }?.1 ?? 0)
        if upper > 1 && legs < upper * 0.5 { return "Lower-body training is behind this week." }
        return workouts == 0 ? "Start with a comfortable session when you're ready." : "Keep your next session balanced with work you've already done."
    }
    private func weightCard(_ report: ProgressReport) -> some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Bodyweight").font(.headline)
                HStack {
                    StatBlock(title: "Measured", value: weight(report.actualWeight), symbol: "circle.fill", tint: AppColor.muted)
                    StatBlock(title: "7-day trend", value: weight(report.trendWeight), symbol: "waveform.path", tint: AppColor.blue)
                }
                if report.trend.isEmpty {
                    Text("Log weight to reveal your trend.").font(.caption).foregroundStyle(AppColor.muted).frame(minHeight: 100)
                } else {
                    Chart {
                        ForEach(store.weights.suffix(60), id: \.id) { point in
                            PointMark(x: .value("Date", point.measuredAt), y: .value("Measured kg", point.kilograms))
                                .foregroundStyle(AppColor.muted.opacity(0.4)).symbolSize(18)
                        }
                        ForEach(report.trend.suffix(60), id: \.date) { point in
                            LineMark(x: .value("Date", point.date), y: .value("Trend kg", point.kilograms))
                                .foregroundStyle(AppColor.blue).lineStyle(StrokeStyle(lineWidth: 2.5)).interpolationMethod(.monotone)
                        }
                    }.chartYScale(domain: .automatic(includesZero: false)).frame(height: 190)
                        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) }
                        .padding(12).background(AppColor.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                        .accessibilityLabel("Body weight: individual measurements and seven-day smoothed trend")
                    HStack { Label("Measured", systemImage: "circle.fill").foregroundStyle(AppColor.muted); Spacer(); Label("7-day trend", systemImage: "minus").foregroundStyle(AppColor.blue) }.font(.caption2)
                }
            }
        }
    }
    private func weight(_ value: Double?) -> String { value.map { "\($0.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "—" }
}
