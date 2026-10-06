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
                }.pickerStyle(.segmented).padding(5).background(AppColor.surface, in: RoundedRectangle(cornerRadius: 13))
                goalCard
                momentumCard
                weightCard
                PrimaryAction(title: "Log body weight", symbol: "plus") { store.presentedSheet = .weight }
                Button { showELO = true } label: {
                    PremiumCard {
                        HStack(spacing: 14) {
                            RankBadgeView(rank: store.rank.rank, size: 55)
                            VStack(alignment: .leading, spacing: 7) {
                                Eyebrow(text: "ELO HISTORY")
                                Text("\(store.currentELO) ELO").font(.title3.weight(.semibold))
                                TrendGraphic(values: store.history.suffix(28).map { Double($0.elo) }, tint: AppColor.rank(store.rank.rank.tier)).frame(maxWidth: 180)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(AppColor.muted)
                        }
                    }
                }.buttonStyle(PremiumPressStyle()).accessibilityLabel("ELO history, \(store.currentELO) ELO")
                PremiumCard {
                    DisclosureGroup {
                        VStack(spacing: 16) {
                            ForEach(store.personalModel.windows, id: \.days) { baseline in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack { Text("\(baseline.days)D").font(.caption.weight(.semibold)); Spacer(); PillStatus(title: baseline.confidence.rawValue.uppercased(), tint: AppColor.muted) }
                                    HStack {
                                        StatBlock(title: "Weight days", value: "\(baseline.observedWeightDays)")
                                        StatBlock(title: "Fuel days", value: "\(baseline.observedNutritionDays)")
                                        StatBlock(title: "Training days", value: "\(baseline.trainingDays)")
                                    }
                                }
                            }
                        }.padding(.top, 16)
                    } label: {
                        HStack { Text("Personal baselines").font(.headline); Spacer(); Image(systemName: "waveform.path").foregroundStyle(AppColor.blue) }
                    }
                }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.accessibilityIdentifier("screen.progress").featureBackground()
            .sheet(isPresented: $showELO) { NavigationStack { ScoreBreakdownView().environment(store) }.preferredColorScheme(.dark) }
    }
    private var goalCard: some View {
        PremiumCard(accented: true) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 20) {
                    ZStack {
                        ProgressRing(progress: report.goalProgress ?? 0, tint: AppColor.blue, lineWidth: 7)
                        Image(systemName: "scope").font(.system(size: 30, weight: .light)).foregroundStyle(AppColor.blue)
                    }.frame(width: 82, height: 82).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "GOAL PROGRESS")
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            if let progress = report.goalProgress {
                                CountUpText(value: progress * 100).font(.system(.largeTitle, design: .rounded, weight: .semibold))
                                Text("%").font(.title3).foregroundStyle(AppColor.muted)
                            } else { Text("Set your target").font(.title2.weight(.semibold)) }
                        }
                        if let deadline = store.profile.targetDeadline {
                            Text(deadline.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(AppColor.muted)
                        }
                    }
                }
                HStack {
                    StatBlock(title: "Start", value: weight(store.profile.startingWeightKG))
                    StatBlock(title: "Trend", value: weight(report.trendWeight), tint: AppColor.blue)
                    StatBlock(title: "Target", value: weight(store.profile.targetWeightKG))
                }
            }
        }
    }
    private var momentumCard: some View {
        PremiumCard {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Eyebrow(text: "MOMENTUM · \(window.rawValue)D")
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        if let value = report.momentumPercent { CountUpText(value: value, signed: true).font(.title.weight(.semibold)) }
                        else { Text("—").font(.title) }
                        Text("%").font(.caption).foregroundStyle(AppColor.muted)
                    }
                    Text(report.momentumPercent.map { $0 < 0 ? "Away from goal" : $0 > 0 ? "Toward your goal" : "Holding steady" } ?? "Building baseline")
                        .font(.caption).foregroundStyle(AppColor.muted)
                }
                TrendGraphic(values: report.trend.suffix(max(2, window.rawValue)).map(\.kilograms),
                    tint: (report.momentumPercent ?? 0) < 0 ? AppColor.warning : AppColor.positive).frame(maxWidth: 100)
            }
        }
    }
    private var weightCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack { Text("Weight trend").font(.headline); Spacer(); PillStatus(title: report.confidence.rawValue.uppercased(), tint: AppColor.muted) }
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
                    }.chartYScale(domain: .automatic(includesZero: false)).frame(height: 180)
                        .accessibilityLabel("Body weight: individual measurements and seven-day smoothed trend")
                    HStack { Label("Measured", systemImage: "circle.fill").foregroundStyle(AppColor.muted); Spacer(); Label("7-day trend", systemImage: "minus").foregroundStyle(AppColor.blue) }.font(.caption2)
                }
            }
        }
    }
    private func weight(_ value: Double?) -> String { value.map { "\($0.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "—" }
}
