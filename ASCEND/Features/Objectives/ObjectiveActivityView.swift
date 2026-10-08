import SwiftUI

struct ObjectiveActivityView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let occurrence: DailyObjectiveCompletion
    @State private var amount = 20.0
    @State private var kilograms = 0.0
    @FocusState private var focused: Bool
    private var exercise: Exercise? { store.exercises.first { $0.catalogID == occurrence.objective?.exerciseCatalogID } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FeatureHeader(eyebrow: "TODAY'S OBJECTIVE", title: occurrence.title)
                ObjectiveRow(occurrence: occurrence) {}
                if occurrence.recoveryExempt {
                    Text("Training is protected today. Fuel and sleep objectives remain active.").font(.subheadline).foregroundStyle(AppColor.muted)
                } else {
                    PremiumCard {
                        VStack(alignment: .leading, spacing: 18) {
                            NumericField(title: occurrence.unit == "seconds" ? "Seconds" : "Count / reps", value: $amount, identifier: "objective.amount").focused($focused)
                            if let exercise, exercise.trackingMode == .weightAndReps || exercise.additionalWeightAllowed { NumericField(title: "Load · kg", value: $kilograms).focused($focused) }
                            Text(exercise == nil ? "Manual progress for this habit." : "One real working set. This enters exercise history and contributes to recovery once; objective progress is derived from that same set.").font(.caption).foregroundStyle(AppColor.muted)
                            PrimaryAction(title: exercise == nil ? "Add progress" : "Quick log real set", symbol: "plus", tint: AppColor.strength) { save() }.accessibilityIdentifier("objective.log")
                        }
                    }
                    if store.recoveryAlternative(for: occurrence) != nil {
                        Text("RECOVERY LIMIT · recorded recovery limits this exercise. Choose explicitly.").font(.caption).foregroundStyle(SemanticStatus.watch.tint)
                        Button("Reduce today by half") { _ = store.reduceObjectiveToday(occurrence) }.frame(minHeight: 44)
                        Button("Protect today") { _ = store.chooseRecoveryAlternative(occurrence); dismiss() }.frame(minHeight: 44)
                    }
                }
            }.padding(24)
        }.featureBackground().accessibilityIdentifier("screen.objectiveactivity").toolbar(.visible, for: .navigationBar).navigationTitle("Objective activity")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }; if focused { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } } } }
            .alert("Check activity", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) { Button("OK") { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
    }
    private func save() {
        focused = false
        guard amount.isFinite, amount > 0, amount <= (occurrence.unit == "seconds" ? 86400 : 2000), kilograms.isFinite, (0...1000).contains(kilograms) else { store.errorMessage = "Enter a valid positive count or duration."; return }
        if let exercise {
            guard exercise.trackingMode == .duration || amount.rounded(.down) == amount else { store.errorMessage = "Enter a whole number of reps."; return }
            let performance = exercise.trackingMode == .duration ? SetPerformance(reps: 0, seconds: amount) : SetPerformance(reps: Int(amount), kilograms: kilograms)
            if store.logWorkout(exercise: exercise, sets: [performance], at: store.actionDate(), quick: true, exertion: 7) { AppHaptics.success(enabled: store.settings.hapticsEnabled); dismiss() }
        } else if store.changeManualObjective(occurrence, adding: amount) { dismiss() }
    }
}
