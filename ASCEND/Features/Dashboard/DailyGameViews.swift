import SwiftUI

struct DailyCommandCard: View {
    @Environment(AppStore.self) private var store
    let showDetails: () -> Void
    private var result: DailyResult { store.dailyResult }
    var body: some View {
        PremiumCard(accented: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Eyebrow(text: "TODAY · PENDING"); Spacer(); Button("Details", action: showDetails).font(.caption).frame(minHeight: 44) }
                HStack(spacing: 16) {
                    Text(result.grade).font(.system(size: 44, weight: .semibold, design: .rounded)).foregroundStyle(AppColor.blue)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(result.status).font(.headline)
                        Text(result.momentum.map { "Momentum \($0.formatted(.number.precision(.fractionLength(0)).sign(strategy: .always())))%" } ?? "Momentum · building baseline")
                            .font(.caption).foregroundStyle(AppColor.muted)
                    }
                    Spacer(minLength: 0)
                    CountUpText(value: Double(result.elo.delta), signed: true).font(.title2.weight(.semibold)).foregroundStyle(AppColor.positive)
                }
                if let reason = result.explanation.first { Text(reason).font(.caption).foregroundStyle(AppColor.muted) }
                let incomplete = store.todayObjectives.filter { $0.completedAt == nil && !$0.recoveryExempt }.count
                HStack { Text("\(incomplete) objectives remaining").font(.caption2).foregroundStyle(AppColor.muted); Spacer(); Text("ELO closes after midnight").font(.caption2).foregroundStyle(AppColor.muted) }
                PrimaryAction(title: nextTitle, symbol: store.activeWorkout == nil ? "arrow.right" : "play.fill", action: nextAction)
            }
        }
    }
    private var nextTitle: String {
        if store.activeWorkout != nil { return "Resume workout" }
        if store.todaySleep == nil { return "Next · log sleep" }
        if store.todayNutrition == nil { return "Next · log nutrition" }
        if store.todayObjectives.contains(where: { $0.completedAt == nil && !$0.recoveryExempt }) { return "Next · review objectives" }
        return "Start workout"
    }
    private func nextAction() {
        if store.activeWorkout != nil { store.startLiveWorkout() }
        else if store.todaySleep == nil { store.presentedSheet = .sleep }
        else if store.todayNutrition == nil { store.presentedSheet = .nutrition }
        else if store.todayObjectives.contains(where: { $0.completedAt == nil && !$0.recoveryExempt }) { store.presentedSheet = .objectives }
        else { store.startLiveWorkout() }
    }
}

struct DailyEvaluationView: View {
    var preferFinalized = false
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var finalized = true
    private var result: DailyResult {
        if finalized, let latest = store.history.last { return store.finalizedResult(latest) }
        return store.dailyResult
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("Result", selection: $finalized) {
                    Text("Today · pending").tag(false)
                    if !store.history.isEmpty { Text("Last closed day").tag(true) }
                }.pickerStyle(.segmented)
                FeatureHeader(eyebrow: finalized ? store.history.last?.dayKey ?? "TODAY" : "TODAY · PENDING", title: result.status.capitalized)
                if finalized && (result.elo.rank.rankedUp || result.elo.rank.rankedDown) {
                    PremiumCard(accented: true) {
                        VStack(spacing: 14) {
                            Eyebrow(text: result.elo.rank.rankedUp ? "RANK UP" : "RANK DOWN")
                            RankBadgeView(rank: result.elo.rank.rank, size: 170, animated: true)
                            Text(result.elo.rank.rank.title).font(.title2.weight(.semibold))
                            Text("\(result.elo.previousELO) → \(result.elo.elo) ELO").font(.headline).monospacedDigit()
                            RankProgressView(status: result.elo.rank)
                        }.frame(maxWidth: .infinity)
                    }
                }
                PremiumCard(accented: true) {
                    HStack(spacing: 20) {
                        Text(result.grade).font(.system(size: 64, weight: .semibold, design: .rounded)).foregroundStyle(AppColor.blue)
                        VStack(alignment: .leading, spacing: 8) {
                            CountUpText(value: Double(result.elo.delta), signed: true).font(.largeTitle.weight(.semibold))
                            Text(finalized ? "FINALIZED ELO" : "PENDING ELO").font(.caption).foregroundStyle(AppColor.muted)
                            if let momentum = result.momentum { Text("Momentum \(momentum.formatted(.number.precision(.fractionLength(0)).sign(strategy: .always())))%").font(.caption) }
                        }
                    }
                }
                PremiumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Eyebrow(text: "WHAT MOVED YOUR RATING")
                        if result.elo.components.isEmpty { Text("No scored actions yet.").font(.subheadline).foregroundStyle(AppColor.muted) }
                        ForEach(result.elo.components) { part in
                            HStack { Text(part.label).font(.subheadline); Spacer(); Text(part.points.formatted(.number.sign(strategy: .always()))).font(.headline).foregroundStyle(part.points < 0 ? AppColor.warning : AppColor.positive) }
                        }
                        Text(finalized ? "Recorded inputs from this closed local day." : "Incomplete objectives are excluded from this preview. Their final result is evaluated after the day closes.")
                            .font(.caption).foregroundStyle(AppColor.muted)
                    }
                }
                PrimaryAction(title: "Done", symbol: "checkmark") { store.acknowledgeEvaluation(); dismiss() }
            }.padding(20)
        }.background(AppColor.background).navigationTitle("Daily result").navigationBarTitleDisplayMode(.inline)
            .onAppear {
                finalized = preferFinalized && !store.history.isEmpty
                if preferFinalized, store.unseenEvaluation, let latest = store.history.last, latest.delta > 0 {
                    AppHaptics.success(enabled: store.settings.hapticsEnabled)
                }
            }
    }
}
