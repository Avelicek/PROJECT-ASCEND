import SwiftUI

struct DailyCommandCard: View {
    @Environment(AppStore.self) private var store
    let showDetails: () -> Void
    private var result: DailyResult { store.dailyResult }
    var body: some View {
        PremiumCard(role: .status, tint: AppColor.elo) {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Eyebrow(text: "TODAY · PENDING"); Spacer(); Button("Details", action: showDetails).font(.caption).frame(minHeight: 44).accessibilityIdentifier("daily.open") }
                HStack(spacing: 16) {
                    Text(result.grade).font(.system(size: 44, weight: .semibold, design: .rounded)).foregroundStyle(AppColor.blue)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(result.status).font(.headline)
                        Text(result.momentum.map { "Momentum \($0.formatted(.number.precision(.fractionLength(0)).sign(strategy: .always())))%" } ?? "Momentum · building baseline")
                            .font(.caption).foregroundStyle(AppColor.muted)
                    }
                    Spacer(minLength: 0)
                    CountUpText(value: Double(result.elo.delta), signed: true).font(.title2.weight(.semibold)).foregroundStyle(result.elo.delta < 0 ? AppColor.negative : AppColor.positive)
                }
                if let reason = result.explanation.first { Text(reason).font(.caption).foregroundStyle(AppColor.muted) }
                let incomplete = store.todayObjectives.filter { $0.completedAt == nil && !$0.recoveryExempt }.count
                HStack { Text("\(incomplete) objectives remaining").font(.caption2).foregroundStyle(AppColor.muted); Spacer(); Text("Pending ELO").font(.caption2).foregroundStyle(AppColor.muted) }
            }
        }
    }

}

struct DailyEvaluationView: View {
    var preferFinalized = false
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var finalized = true
    @State private var showRank = false
    @State private var rankPresented = false
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
                    Button { showRank = true } label: { Label(result.elo.rank.rankedUp ? "View rank up" : "View rank change", systemImage: "sparkle").font(.headline).foregroundStyle(AppColor.elo) }
                        .frame(minHeight: 44).accessibilityIdentifier("daily.rank.open")
                }
                PremiumCard(role: .hero, tint: result.elo.delta < 0 ? AppColor.negative : AppColor.elo) {
                    HStack(spacing: 20) {
                        Text(result.grade).font(.system(size: 64, weight: .semibold, design: .rounded)).foregroundStyle(AppColor.blue)
                        VStack(alignment: .leading, spacing: 8) {
                            CountUpText(value: Double(result.elo.delta), signed: true).font(.largeTitle.weight(.semibold)).foregroundStyle(result.elo.delta < 0 ? AppColor.negative : AppColor.positive)
                            Text(finalized ? "FINALIZED ELO" : "PENDING ELO").font(.caption).foregroundStyle(AppColor.muted)
                            if let momentum = result.momentum { Text("Momentum \(momentum.formatted(.number.precision(.fractionLength(0)).sign(strategy: .always())))%").font(.caption) }
                        }
                    }
                }
                if finalized { ELOMovement(result: result.elo).frame(maxWidth: .infinity).padding(.vertical, 8) }
                PremiumCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Eyebrow(text: "WHAT MOVED YOUR RATING")
                        if result.elo.components.isEmpty { Text("No scored actions yet.").font(.subheadline).foregroundStyle(AppColor.muted) }
                        ForEach(result.elo.components) { part in
                            HStack { Text(part.label).font(.subheadline).foregroundStyle(AppColor.secondary); Spacer(); Text(part.points.formatted(.number.sign(strategy: .always()))).font(.headline).foregroundStyle(part.points < 0 ? AppColor.negative : AppColor.positive) }
                        }
                        Text(finalized ? "Closed local day · saved result" : "Missed objectives apply after the day closes.")
                            .font(.caption).foregroundStyle(AppColor.muted)
                    }
                }
                PrimaryAction(title: "Done", symbol: "checkmark") { store.acknowledgeEvaluation(); dismiss() }
            }.padding(20)
        }.background(AppColor.background).navigationTitle("Daily result").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("screen.dailyevaluation")
            .fullScreenCover(isPresented: $showRank) { RankRewardView(result: result.elo) { showRank = false }.environment(store) }
            .onAppear {
                finalized = preferFinalized && !store.history.isEmpty
                if preferFinalized, store.unseenEvaluation, let latest = store.history.last, latest.delta > 0 {
                    AppHaptics.success(enabled: store.settings.hapticsEnabled)
                }
            }
            .task(id: finalized) {
                guard preferFinalized && finalized && !rankPresented && (result.elo.rank.rankedUp || result.elo.rank.rankedDown) else { return }
                do { try await Task.sleep(for: .milliseconds(750)) } catch { return }
                rankPresented = true; showRank = true
            }
    }
}
