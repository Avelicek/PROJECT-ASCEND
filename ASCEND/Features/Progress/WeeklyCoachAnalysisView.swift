import SwiftUI

struct WeeklyCoachAnalysisView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        let lower = store.policy.adding(days: -6, to: store.policy.start(of: store.now))
        let completed = store.sessions.filter { $0.hasWorkingSets && $0.evaluationDate >= lower && $0.evaluationDate <= store.now }
        let productive = completed.reduce(0) { total, session in total + session.exercises.reduce(0) { sum, exercise in
            sum + exercise.sets.filter { !$0.isWarmup && TrainingLoadEngine().stimulus([.init($0.performance, rpe: $0.perceivedExertion)], mode: exercise.trackingMode, quick: session.isQuickLog) >= 0.5 }.count
        } }
        let checkIns = Set((store.ownerSystem.checkIns ?? []).filter { $0.date >= lower && $0.date <= store.now }.map { store.policy.key(for: $0.date) }).count
        let sleep = store.sleep.filter { $0.date >= lower && $0.date <= store.now }
        let previousSleep = store.sleep.filter { $0.date >= store.policy.adding(days: -7, to: lower) && $0.date < lower }
        let average = FitnessMath.average(sleep.map(\.durationHours)), previous = FitnessMath.average(previousSleep.map(\.durationHours))
        VStack(alignment: .leading, spacing: 18) {
            MetricStrip(metrics: [GlanceMetric(title: "Productive sets", value: String(productive), symbol: "checkmark.circle", tint: AppColor.strength), GlanceMetric(title: "Check-ins", value: "\(checkIns)/7", symbol: "sun.horizon"), GlanceMetric(title: "Sleep · avg h", value: average.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—", symbol: "moon", tint: AppColor.sleep)])
            PremiumCard {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "WHAT WENT WELL")
                    Text(store.weeklyExplanation).font(.subheadline)
                    Text("\(checkIns) real check-ins and \(productive) recorded productive sets this week.").font(.caption).foregroundStyle(AppColor.secondary)
                    Eyebrow(text: "NEEDS ATTENTION")
                    if let lowest = store.weeklyExposure.min(by: { $0.1 < $1.1 }), lowest.1 < 2 { Text("\(lowest.0) stimulus is low this week. The generator gives available, recovered muscles priority.").font(.subheadline) }
                    if let average, let previous, average < previous - 0.25 { Text("Recorded sleep decreased by \((previous - average).formatted(.number.precision(.fractionLength(1)))) hours versus the prior week.").font(.subheadline) }
                    if completed.isEmpty { Text("Learning your training baseline. Complete a comfortable first session.").font(.subheadline) }
                    Eyebrow(text: "ASCEND ADJUSTMENT")
                    Text(store.brainDecision.reasons.joined(separator: " ")).font(.subheadline).foregroundStyle(AppColor.secondary)
                    Text("The next plan is adjusted when you log new activity or check in; no future session is claimed as completed.").font(.caption).foregroundStyle(AppColor.muted)
                }
            }
            GoalProjectionCard()
        }.accessibilityIdentifier("coach.weekly.analysis")
    }
}
