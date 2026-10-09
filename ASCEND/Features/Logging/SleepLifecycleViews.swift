import SwiftUI

struct EndOfDaySummaryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var body: some View {
        let workouts = store.sessions.filter { $0.hasWorkingSets && store.policy.sameDay($0.evaluationDate, store.now) }
        let completed = store.todayObjectives.filter { $0.completedAt != nil }.count
        let protected = store.todayObjectives.filter(\.recoveryExempt).count
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FeatureHeader(eyebrow: "END OF DAY", title: "Your day, complete")
                PremiumCard(role: .hero, tint: AppColor.sleep) {
                    VStack(alignment: .leading, spacing: 20) {
                        Eyebrow(text: "TODAY · LIVE TOTAL")
                        CountUpText(value: Double(store.projectedScore.delta), signed: true).font(.largeTitle.weight(.semibold))
                        Text("ELO").font(.caption).foregroundStyle(AppColor.muted)
                        summaryRow("Workout", workouts.isEmpty ? "Rest day" : "\(workouts.filter { !$0.isQuickLog }.count) workouts · \(workouts.filter(\.isQuickLog).count) quick activities")
                        if let food = store.todayNutrition {
                            let coverage = min(1, min(food.calories / max(1, food.calorieGoal), food.proteinGrams / max(1, food.proteinGoal)))
                            summaryRow("Nutrition", "\(Int(coverage * 100))% of both targets")
                        } else { summaryRow("Nutrition", "Not logged") }
                        summaryRow("Objectives", "\(completed) / \(store.todayObjectives.count)")
                        summaryRow("Recovery", protected > 0 ? "\(protected) training goals protected" : "\(store.ownerSystem.sickActive ? "Prioritized" : "Plan reviewed")")
                    }
                }
                Text(conclusion(workouts: workouts.count)).font(.headline).foregroundStyle(AppColor.secondary)
                Eyebrow(text: "READY TO SLEEP?")
                PrimaryAction(title: "START SLEEP", symbol: "moon.fill", tint: AppColor.sleep) { store.startSleep() }.accessibilityIdentifier("sleep.confirm.start")
                Text("Sleep Mode stays active until you end it. Your current workout is saved.").font(.caption).foregroundStyle(AppColor.muted)
            }.padding(24).opacity(appeared || AppMotion.snapshotMode ? 1 : 0).offset(y: appeared || reduceMotion || AppMotion.snapshotMode ? 0 : 12)
        }.featureBackground(tint: AppColor.sleep).navigationTitle("End of day").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("screen.sleepsummary")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Back") { dismiss() } } }
            .onAppear { withAnimation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.reveal) { appeared = true } }
    }
    private func summaryRow(_ title: String, _ value: String) -> some View { HStack(alignment: .top) { Text(title).foregroundStyle(AppColor.muted); Spacer(); Text(value).multilineTextAlignment(.trailing) }.font(.subheadline) }
    private func conclusion(workouts: Int) -> String {
        if store.ownerSystem.sickActive { return "You gave recovery room today. Keep resting." }
        if let food = store.todayNutrition, food.calories < food.calorieGoal * 0.9 {
            return "\(workouts > 0 ? "Training recorded. " : "Day reviewed. ")You logged about \(Int(food.calorieGoal - food.calories)) kcal below your fuel target."
        }
        return workouts > 0 ? "Your work is recorded. Give yourself time to recover." : "Rest supports tomorrow's plan. Let's check in when you wake."
    }
}

struct LockedSleepView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var phase
    let start: Date
    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 24)
            Text("ASCEND").font(.title3.weight(.semibold)).tracking(6)
            Eyebrow(text: "SLEEP MODE").accessibilityIdentifier("screen.sleepmode")
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion || phase != .active || AppMotion.snapshotMode)) { timeline in
                let breath = reduceMotion || AppMotion.snapshotMode ? 0.5 : (sin(timeline.date.timeIntervalSinceReferenceDate * .pi / 4) + 1) / 2
                ZStack {
                    Circle().fill(AppColor.sleep.opacity(0.04 + breath * 0.05)).frame(width: 240, height: 240).scaleEffect(0.85 + breath * 0.15)
                    Circle().stroke(AppColor.sleep.opacity(0.25), lineWidth: 1).frame(width: 180, height: 180).scaleEffect(0.9 + breath * 0.1)
                    AscendMark().fill(AppColor.sleep).frame(width: 64, height: 64)
                }
            }.frame(height: 250).accessibilityHidden(true)
            Text(start.formatted(date: .omitted, time: .shortened)).font(.largeTitle.weight(.light)).monospacedDigit()
            Text("Started \(start.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(AppColor.muted).accessibilityIdentifier("sleep.started")
            Text("Recovery in progress").font(.headline)
            Text("Keep resting. Tomorrow's plan updates after your morning check-in.").font(.subheadline).foregroundStyle(AppColor.secondary).multilineTextAlignment(.center)
            Spacer(minLength: 24)
            PrimaryAction(title: "END SLEEP", symbol: "sunrise", tint: AppColor.sleep) { store.endSleep() }.accessibilityIdentifier("sleep.end")
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).featureBackground(tint: AppColor.sleep)
    }
}
