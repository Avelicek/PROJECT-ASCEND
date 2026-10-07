import SwiftUI

struct LiveExerciseCard: View {
    @Environment(AppStore.self) private var store
    let exercise: LiveExercise
    private var history: [ExerciseHistory] { store.exerciseHistory }
    private var previous: ExerciseHistory? { ProgressionEngine().previous(history, exercise: exercise, now: store.actionDate()) }
    private var suggestion: ProgressionSuggestion {
        let limited = store.readiness.confidence != .low && store.readiness.muscles.contains { muscle in
            muscle.recoveryPercent < 50 && exercise.contributions.contains { $0.muscle == muscle.muscle && $0.fraction >= 0.1 }
        }
        return ProgressionEngine().suggest(history, exercise: exercise, now: store.actionDate(), recoveryLimited: limited)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(exercise.name).font(.system(.title, design: .rounded, weight: .semibold))
                Text(Array(Set(exercise.contributions.filter { $0.fraction >= 0.1 }.map { $0.muscle.group })).sorted().joined(separator: " · "))
                    .font(.caption).foregroundStyle(AppColor.blue)
            }
            previousPanel
            if let record = store.pendingRecords.first(where: { $0.exerciseID == exercise.catalogID }) { RecordCelebration(record: record, pending: true) }
            PremiumCard(accented: true) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack { Eyebrow(text: "SUGGESTED TARGET"); Spacer(); PillStatus(title: suggestion.confidence.rawValue.uppercased(), tint: AppColor.muted) }
                    if let target = suggestion.target {
                        HStack {
                            Text(performance(target)).font(.title3.weight(.semibold)).monospacedDigit()
                            Spacer()
                            Button("Use target") {
                                store.changeLiveExercise(exercise.id) { value in
                                    if let index = value.sets.firstIndex(where: { $0.completedAt == nil && !$0.isWarmup }) {
                                        value.sets[index].reps = target.reps; value.sets[index].kilograms = target.kilograms
                                    }
                                }
                            }.font(.caption).frame(minHeight: 44)
                        }
                    }
                    ContextExplanationView(focus: "Progression explained", facts: [suggestion.explanation], confidence: suggestion.confidence)
                }
            }
            HStack { Eyebrow(text: "TODAY'S SETS"); Spacer(); Text("\(exercise.completedWorkingSets.count) working").font(.caption).foregroundStyle(AppColor.muted) }
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                LiveSetRow(exercise: exercise, set: set, number: index + 1)
            }
            PrimaryAction(title: "Add set", symbol: "plus") { store.addLiveSet(exerciseID: exercise.id) }.accessibilityIdentifier("live.add.set")
        }
    }
    private var previousPanel: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Eyebrow(text: "LAST COMPARABLE SESSION"); Spacer(); if let previous { Text(previous.date.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(AppColor.muted) } }
                if let previous {
                    Text(previous.working.prefix(4).map { performance($0.performance) }.joined(separator: "  /  "))
                        .font(.subheadline.weight(.medium)).monospacedDigit()
                    if exercise.mode == .weightAndReps && !exercise.bodyweight {
                        let sets = history.filter { $0.exerciseID == exercise.catalogID && $0.mode == exercise.mode && !$0.quick && $0.date <= store.actionDate() }.flatMap { $0.working.map(\.performance) }
                        let candidates = WorkoutEngine().recordCandidates(sets)
                        HStack {
                            StatBlock(title: "Best load", value: "\((candidates.first { $0.kind == .weight }?.value ?? 0).formatted()) kg")
                            StatBlock(title: "Est. 1RM", value: candidates.first { $0.kind == .estimatedOneRepMax }.map { "\($0.value.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "—", tint: AppColor.blue)
                        }
                    }
                    if exercise.mode == .reps || exercise.mode == .weightAndReps,
                       let next = exercise.sets.first(where: { $0.completedAt == nil && !$0.isWarmup }) {
                        let bestReps = history.filter { $0.exerciseID == exercise.catalogID && $0.mode == exercise.mode && !$0.quick && $0.date < store.actionDate() }
                            .flatMap(\.working).filter { abs($0.performance.kilograms - next.kilograms) < 0.001 }.map { $0.performance.reps }.max()
                        if let bestReps {
                            Label("Rep PR begins at \(bestReps + 1) reps at this load · only if effort allows", systemImage: "trophy")
                                .font(.caption2).foregroundStyle(AppColor.warning)
                        }
                    }
                } else { Text("No recent comparable working sets.").font(.caption).foregroundStyle(AppColor.muted) }
            }
        }
    }
    private func performance(_ value: SetPerformance) -> String {
        switch exercise.mode {
        case .weightAndReps: "\(value.kilograms.formatted()) kg × \(value.reps)"
        case .reps: value.kilograms > 0 ? "+\(value.kilograms.formatted()) kg × \(value.reps)" : "\(value.reps) reps"
        case .duration: "\(Int(value.seconds)) sec"
        case .distance: "\(value.distanceMeters.formatted()) m · \(Int(value.seconds)) sec"
        }
    }
}

private struct LiveSetRow: View {
    @Environment(AppStore.self) private var store
    let exercise: LiveExercise
    let set: LiveSet
    let number: Int
    private var completed: Bool { set.completedAt != nil }
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(String(format: "%02d", number)).font(.headline).foregroundStyle(completed ? AppColor.positive : AppColor.blue)
                    Spacer()
                    Toggle("Warm-up", isOn: field(\.isWarmup)).font(.caption).fixedSize().disabled(completed)
                }
                HStack(spacing: 12) {
                    if exercise.mode == .reps || exercise.mode == .weightAndReps {
                        valueField("Reps", value: field(\.reps), id: "live.set.reps")
                    }
                    if exercise.allowsWeight { valueField(exercise.bodyweight ? "Added kg" : "Kilograms", value: field(\.kilograms), id: "live.set.kg") }
                    if exercise.mode == .duration || exercise.mode == .distance { valueField("Seconds", value: field(\.seconds), id: "live.set.seconds") }
                    if exercise.mode == .distance { valueField("Meters", value: field(\.distanceMeters), id: "live.set.meters") }
                }.disabled(completed)
                HStack {
                    Toggle("RPE", isOn: Binding(get: { set.rpe != nil }, set: { enabled in update { $0.rpe = enabled ? 7 : nil } }))
                        .font(.caption).fixedSize().disabled(completed)
                    if set.rpe != nil {
                        TextField("RPE", value: Binding(get: { set.rpe ?? 7 }, set: { new in update { $0.rpe = new } }), format: .number)
                            .keyboardType(.decimalPad).padding(10).background(AppColor.elevated, in: RoundedRectangle(cornerRadius: 10)).disabled(completed)
                    }
                    Spacer()
                    if completed {
                        Button("Undo", systemImage: "arrow.uturn.backward") { update { $0.completedAt = nil } }.font(.caption).frame(minHeight: 44)
                    } else {
                        Button("Remove", systemImage: "minus.circle") {
                            store.changeLiveExercise(exercise.id) { $0.sets.removeAll { $0.id == set.id } }
                        }.font(.caption).foregroundStyle(AppColor.muted).frame(minHeight: 44)
                    }
                }
                Button {
                    _ = store.completeLiveSet(exerciseID: exercise.id, setID: set.id)
                } label: {
                    Label(completed ? "Set complete" : "Complete set", systemImage: completed ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                        .background((completed ? AppColor.positive : AppColor.blue).opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(PremiumPressStyle()).disabled(completed).accessibilityIdentifier("live.set.complete")
            }
        }
    }
    private func field<Value>(_ keyPath: WritableKeyPath<LiveSet, Value>) -> Binding<Value> {
        Binding(get: { set[keyPath: keyPath] }, set: { value in update { $0[keyPath: keyPath] = value } })
    }
    private func update(_ change: (inout LiveSet) -> Void) {
        store.changeLiveExercise(exercise.id) { value in
            if let index = value.sets.firstIndex(where: { $0.id == set.id }) { change(&value.sets[index]) }
        }
    }
    private func valueField(_ title: String, value: Binding<Int>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption2).foregroundStyle(AppColor.muted)
            TextField(title, value: value, format: .number).font(.title3.weight(.semibold)).keyboardType(.numberPad)
                .padding(12).background(AppColor.elevated, in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier(id)
        }.frame(maxWidth: .infinity)
    }
    private func valueField(_ title: String, value: Binding<Double>, id: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption2).foregroundStyle(AppColor.muted)
            TextField(title, value: value, format: .number).font(.title3.weight(.semibold)).keyboardType(.decimalPad)
                .padding(12).background(AppColor.elevated, in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier(id)
        }.frame(maxWidth: .infinity)
    }
}
