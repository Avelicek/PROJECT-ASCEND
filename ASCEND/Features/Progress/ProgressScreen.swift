import SwiftUI
import Charts

struct ProgressScreen: View {
    @Environment(AppStore.self) private var store
    @State private var window: EvaluationWindow = .week
    @State private var showELO = false
    private var report: ProgressReport { store.report(window: window) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "THE LONG GAME", title: "Progress")
                Picker("Evaluation window", selection: $window) {
                    Text("Day").tag(EvaluationWindow.day); Text("Week").tag(EvaluationWindow.week); Text("Month").tag(EvaluationWindow.month)
                }.pickerStyle(.segmented)
                PremiumCard(accented: true) {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Eyebrow(text: "GOAL PROGRESS")
                        Text(report.goalProgress.map { "\(Int(($0 * 100).rounded()))%" } ?? "Set your target")
                            .font(AppTypography.metric).monospacedDigit()
                        LinearProgress(progress: report.goalProgress ?? 0, tint: AppColor.blue)
                        HStack {
                            Text(store.profile.startingWeightKG.map { "\($0.formatted()) kg start" } ?? "Starting weight needed")
                            Spacer()
                            Text(store.profile.targetWeightKG.map { "\($0.formatted()) kg target" } ?? "Target needed")
                        }.font(.caption).foregroundStyle(AppColor.muted)
                        if let deadline = store.profile.targetDeadline { Text("Target · \(deadline.formatted(date: .abbreviated, time: .omitted))").font(.caption).foregroundStyle(AppColor.muted) }
                    }
                }
                MetricCard(title: "MOMENTUM · \(window.rawValue)D", value: report.momentumPercent.map { String(format: "%+.0f", $0) } ?? "—", suffix: "%",
                    detail: report.momentumPercent.map { $0 < 0 ? "MOVING AWAY FROM GOAL" : "MOVING TOWARD GOAL" } ?? "MORE HISTORY NEEDED",
                    tint: (report.momentumPercent ?? 0) < 0 ? AppColor.warning : AppColor.positive)
                PremiumCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeader(title: "Weight trend", detail: "\(report.confidence.rawValue.capitalized) confidence")
                        if report.trend.isEmpty {
                            Text("Log weight to reveal your trend. Daily water changes are smoothed over seven calendar days.")
                                .font(AppTypography.body).foregroundStyle(AppColor.muted)
                        } else {
                            Chart {
                                ForEach(store.weights.suffix(60), id: \.id) { point in
                                    PointMark(x: .value("Date", point.measuredAt), y: .value("Measured kg", point.kilograms))
                                        .foregroundStyle(AppColor.muted.opacity(0.35)).symbolSize(18)
                                }
                                ForEach(report.trend.suffix(60), id: \.date) { point in
                                    LineMark(x: .value("Date", point.date), y: .value("Trend kg", point.kilograms))
                                        .foregroundStyle(AppColor.blue).interpolationMethod(.monotone)
                                }
                            }.chartYScale(domain: .automatic(includesZero: false)).frame(height: 200)
                                .accessibilityLabel("Body weight: individual measurements and seven-day smoothed trend")
                            HStack { Label("Measured", systemImage: "circle.fill").foregroundStyle(AppColor.muted); Spacer(); Label("7-day trend", systemImage: "minus").foregroundStyle(AppColor.blue) }.font(.caption2)
                        }
                        HStack {
                            Text(report.actualWeight.map { "Actual \($0.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "Actual —")
                            Spacer()
                            Text(report.trendWeight.map { "Trend \($0.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "Trend —")
                        }.font(.caption).foregroundStyle(AppColor.muted)
                    }
                }
                PrimaryAction(title: "Log body weight", symbol: "plus") { store.presentedSheet = .weight }
                Button { showELO = true } label: {
                    PremiumCard { HStack { SectionHeader(title: "ELO history", detail: "\(store.currentELO) ELO"); Image(systemName: "chevron.right") } }
                }.buttonStyle(PremiumPressStyle())
                SectionHeader(title: "Personal baselines")
                ForEach(store.personalModel.windows, id: \.days) { baseline in
                    PremiumCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack { Text("\(baseline.days)-day window").font(.headline); Spacer(); PillStatus(title: baseline.confidence.rawValue.uppercased()) }
                            Text("\(baseline.observedWeightDays) weight days · \(baseline.observedNutritionDays) nutrition days · \(baseline.trainingDays) training days")
                                .font(.caption).foregroundStyle(AppColor.muted)
                        }
                    }
                }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.accessibilityIdentifier("screen.progress").featureBackground().sheet(isPresented: $showELO) { NavigationStack { ScoreBreakdownView().environment(store) }.preferredColorScheme(.dark) }
    }
}
