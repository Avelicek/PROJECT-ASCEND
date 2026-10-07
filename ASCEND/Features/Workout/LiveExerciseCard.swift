import SwiftUI

struct LiveExerciseCard: View {
    @Environment(AppStore.self) private var store
    let exercise: LiveExercise
    let focus: FocusState<LiveSetFocus?>.Binding
    private var metadata: TrainingExercise? { store.trainingMetadata(exercise.catalogID) }
    private var previous: ExerciseHistory? { ProgressionEngine().previous(store.exerciseHistory, exercise: exercise, now: store.actionDate()) }
    private var suggestion: ProgressionSuggestion {
        let limited = store.readiness.confidence != .low && store.readiness.muscles.contains { muscle in
            muscle.recoveryPercent < 50 && exercise.contributions.contains { $0.muscle == muscle.muscle && $0.fraction >= 0.1 }
        }
        return ProgressionEngine().suggest(store.exerciseHistory, exercise: exercise, now: store.actionDate(), recoveryLimited: limited)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text(metadata?.required.map(\.title).sorted().joined(separator: " · ") ?? "Personal exercise").font(.caption2).foregroundStyle(ExerciseIdentity.tint(metadata)); Spacer(); if !store.missingEquipment(exercise.catalogID).isEmpty { PillStatus(title: "EQUIPMENT UNAVAILABLE", tint: AppColor.warning) } }
            Text(Array(Set(exercise.contributions.filter { $0.fraction >= 0.1 }.map { $0.muscle.group })).sorted().joined(separator: " · "))
                .font(.caption).foregroundStyle(AppColor.strength)
            comparison
            if exercise.bodyweight && exercise.addedWeight && exercise.mode == .reps {
                Toggle("Bodyweight + added load", isOn: Binding(get: { exercise.allowsWeight }, set: { enabled in
                    focus.wrappedValue = nil
                    store.changeLiveExercise(exercise.id) { entry in
                        entry.usesAddedWeight = enabled
                        if !enabled { for index in entry.sets.indices where entry.sets[index].completedAt == nil { entry.sets[index].kilograms = 0 } }
                    }
                })).font(.caption).tint(AppColor.recovery).disabled(exercise.sets.contains { $0.completedAt != nil && $0.kilograms > 0 }).accessibilityIdentifier("live.added.load")
            }
            if suggestion.additionalSetSuggested { Text("Three consistent sessions. Consider one extra working set if recovery permits.").font(.caption).foregroundStyle(AppColor.recovery) }
            if let metadata, let variation = TrainingSystem().harderVariation(for: metadata, history: store.exerciseHistory, state: store.training, now: store.actionDate()) {
                Text("Variation to consider · \(variation.name)").font(.caption).foregroundStyle(AppColor.recovery)
            }
            if let record = store.pendingRecords.first(where: { $0.exerciseID == exercise.catalogID }) { RecordCelebration(record: record, pending: true) }
            HStack { Eyebrow(text: "WORKING SETS"); Spacer(); Text("\(exercise.completedWorkingSets.count) / \(exercise.sets.filter { !$0.isWarmup }.count)").font(.caption).foregroundStyle(AppColor.strength) }
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, liveSet in
                LiveSetRow(exercise: exercise, liveSet: liveSet, number: index + 1, focus: focus)
            }
            PrimaryAction(title: "Add set", symbol: "plus", tint: AppColor.strength) { store.addLiveSet(exerciseID: exercise.id) }.accessibilityIdentifier("live.add.set")
        }
    }
    private var comparison: some View {
        PremiumCard(role: .metric, tint: AppColor.strength) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Eyebrow(text: "LAST")
                        if let value = previous?.working.first?.performance {
                            Button { copyPrevious(value) } label: { Text(performance(value)).font(.headline).foregroundStyle(AppColor.secondary) }
                                .buttonStyle(.plain).frame(minHeight: 44, alignment: .leading).accessibilityIdentifier("live.copy.previous").accessibilityHint("Copy to the next unfinished set")
                        } else { Text("First session").font(.subheadline).foregroundStyle(AppColor.muted) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: suggestion.target == nil ? "equal" : "arrow.up.right").font(.caption).foregroundStyle(AppColor.strength).padding(.top, 26)
                    VStack(alignment: .leading, spacing: 7) {
                        Eyebrow(text: suggestion.target == nil ? "MATCH / HOLD" : "OPTIONAL TARGET")
                        if let target = suggestion.target {
                            Button { copyPrevious(target) } label: { Text(performance(target)).font(.headline).foregroundStyle(AppColor.strength) }
                                .buttonStyle(.plain).frame(minHeight: 44, alignment: .leading).accessibilityHint("Use the optional target for the next unfinished set")
                        } else { Text(previous?.working.first.map { performance($0.performance) } ?? "Build a baseline").font(.subheadline).foregroundStyle(AppColor.muted).frame(minHeight: 44, alignment: .leading) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack { PillStatus(title: suggestion.confidence.rawValue.uppercased(), tint: AppColor.muted); Spacer(); if let date = previous?.date { Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(AppColor.muted) } }
                if let opportunity = repOpportunity { Label(opportunity, systemImage: "trophy").font(.caption).foregroundStyle(AppColor.gold) }
                DisclosureGroup("Performance & explanation") {
                    VStack(alignment: .leading, spacing: 12) {
                        if let previous { Text(previous.working.map { performance($0.performance) }.joined(separator: "  /  ")).font(.caption).foregroundStyle(AppColor.secondary) }
                        if exercise.mode == .weightAndReps && !exercise.bodyweight {
                            let values = store.exerciseHistory.filter { $0.exerciseID == exercise.catalogID && $0.mode == exercise.mode && !$0.quick && $0.date <= store.actionDate() }.flatMap { $0.working.map(\.performance) }
                            let records = WorkoutEngine().recordCandidates(values)
                            HStack {
                                StatBlock(title: "Best load", value: records.first { $0.kind == .weight }.map { "\($0.value.formatted()) kg" } ?? "—", tint: AppColor.strength)
                                StatBlock(title: "Est. 1RM", value: records.first { $0.kind == .estimatedOneRepMax }.map { "\($0.value.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "—", tint: AppColor.gold)
                            }
                        }
                        ContextExplanationView(focus: "Progression", facts: [suggestion.explanation], confidence: suggestion.confidence)
                    }.padding(.top, 10)
                }.font(.caption).tint(AppColor.muted)
            }
        }
    }
    private var repOpportunity: String? {
        guard exercise.mode == .reps || exercise.mode == .weightAndReps,
              let next = exercise.sets.first(where: { $0.completedAt == nil && !$0.isWarmup }) else { return nil }
        let best = store.exerciseHistory.filter { $0.exerciseID == exercise.catalogID && $0.mode == exercise.mode && !$0.quick && $0.date < store.actionDate() }
            .flatMap(\.working).filter { abs($0.performance.kilograms - next.kilograms) < 0.001 }.map { $0.performance.reps }.max()
        return best.map {
            let gap = $0 + 1 - next.reps
            return gap <= 0 ? "Rep PR target entered · complete to record" : "\(gap) rep\(gap == 1 ? "" : "s") to a rep PR · effort permitting"
        }
    }
    private func copyPrevious(_ value: SetPerformance) {
        store.changeLiveExercise(exercise.id) { entry in
            if let index = entry.sets.firstIndex(where: { $0.completedAt == nil && !$0.isWarmup }) {
                entry.sets[index].reps = value.reps; entry.sets[index].kilograms = value.kilograms
                entry.sets[index].seconds = value.seconds; entry.sets[index].distanceMeters = value.distanceMeters
                    if value.kilograms > 0 && entry.bodyweight { entry.usesAddedWeight = true }
            }
        }
        AppHaptics.selection(enabled: store.settings.hapticsEnabled)
    }
    private func performance(_ value: SetPerformance) -> String {
        switch exercise.mode {
        case .weightAndReps: "\(value.kilograms.formatted()) × \(value.reps)"
        case .reps: value.kilograms > 0 ? "+\(value.kilograms.formatted()) × \(value.reps)" : "\(value.reps) reps"
        case .duration: "\(Int(value.seconds)) sec"
        case .distance: "\(value.distanceMeters.formatted()) m · \(Int(value.seconds)) sec"
        }
    }
}

enum SetInput: Hashable { case kg, reps, rpe, seconds, meters }
struct LiveSetFocus: Hashable {
    let setID: UUID
    let input: SetInput
}

private struct LiveSetRow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let exercise: LiveExercise
    let liveSet: LiveSet
    let number: Int
    let focus: FocusState<LiveSetFocus?>.Binding
    private var completed: Bool { liveSet.completedAt != nil }
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                VStack(spacing: 7) {
                    Text("SET").font(.system(size: 9, weight: .medium)).foregroundStyle(AppColor.muted)
                    Text(String(format: "%02d", number)).font(.headline).foregroundStyle(completed ? AppColor.positive : AppColor.strength)
                }.frame(width: 28)
                if exercise.allowsWeight { decimalField(exercise.bodyweight ? "+ KG" : "KG", key: \.kilograms, focus: .kg, id: "live.set.kg") }
                if exercise.mode == .reps || exercise.mode == .weightAndReps {
                    VStack(spacing: 7) {
                        fieldLabel("REPS")
                        TextField("Reps", value: binding(\.reps), format: .number).keyboardType(.numberPad).focused(focus, equals: .init(setID: liveSet.id, input: .reps))
                            .accessibilityIdentifier("live.set.reps").modifier(SetInputSurface(locked: completed))
                    }
                }
                if exercise.mode == .duration || exercise.mode == .distance { decimalField("SEC", key: \.seconds, focus: .seconds, id: "live.set.seconds") }
                if exercise.mode == .distance { decimalField("METERS", key: \.distanceMeters, focus: .meters, id: "live.set.meters") }
                rpeField
                Button(action: complete) {
                    Image(systemName: completed ? "checkmark.circle.fill" : "checkmark.circle")
                        .font(.system(size: 27, weight: .light)).foregroundStyle(completed ? AppColor.positive : AppColor.strength)
                        .frame(width: 44, height: 54)
                }.buttonStyle(PremiumPressStyle()).disabled(completed).accessibilityIdentifier("live.set.complete")
                    .accessibilityLabel(completed ? "Set complete" : "Complete set")
            }
            HStack {
                Button { if !completed { update { $0.isWarmup.toggle() } } } label: {
                    Text(liveSet.isWarmup ? "WARM-UP" : "WORKING").font(.system(size: 9, weight: .semibold)).foregroundStyle(liveSet.isWarmup ? AppColor.muted : AppColor.strength)
                        .frame(minHeight: 44)
                }.disabled(completed).accessibilityLabel("Toggle warm-up")
                Spacer()
                if completed { Text("Locked").font(.caption2).foregroundStyle(AppColor.muted) }
                Menu {
                    if completed { Button("Undo completion") { update { $0.completedAt = nil } } }
                    else { Button("Remove set", role: .destructive) { store.changeLiveExercise(exercise.id) { $0.sets.removeAll { $0.id == liveSet.id } } } }
                    if !completed && liveSet.rpe != nil { Button("Remove RPE") { focus.wrappedValue = nil; update { $0.rpe = nil } } }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).foregroundStyle(AppColor.muted) }.accessibilityLabel("Set options")
            }
        }.padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 2)
            .background((completed ? AppColor.positive.opacity(0.045) : AppColor.surface), in: RoundedRectangle(cornerRadius: 17))
            .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(completed ? AppColor.positive.opacity(0.55) : AppColor.strength.opacity(0.25)).frame(width: 2).padding(.vertical, 16) }
            .animation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.micro, value: completed)
    }
    private var rpeField: some View {
        VStack(spacing: 7) {
            fieldLabel("RPE")
            if liveSet.rpe != nil {
                TextField("RPE", value: Binding(get: { liveSet.rpe ?? 7 }, set: { value in update { $0.rpe = value } }), format: .number)
                    .keyboardType(.decimalPad).focused(focus, equals: .init(setID: liveSet.id, input: .rpe)).modifier(SetInputSurface(locked: completed)).accessibilityIdentifier("live.set.rpe")
            } else {
                Button { update { $0.rpe = 7 }; focus.wrappedValue = .init(setID: liveSet.id, input: .rpe) } label: { Text("—").font(.headline).foregroundStyle(AppColor.muted).frame(maxWidth: .infinity, minHeight: 44) }
                    .disabled(completed).accessibilityLabel("Add optional RPE")
            }
        }.frame(maxWidth: .infinity)
    }
    private func fieldLabel(_ title: String) -> some View { Text(title).font(.system(size: 9, weight: .medium)).foregroundStyle(AppColor.muted) }
    private func decimalField(_ title: String, key: WritableKeyPath<LiveSet, Double>, focus input: SetInput, id: String) -> some View {
        VStack(spacing: 7) {
            fieldLabel(title)
            TextField(title, value: binding(key), format: .number).keyboardType(.decimalPad).focused(focus, equals: .init(setID: liveSet.id, input: input))
                .modifier(SetInputSurface(locked: completed)).accessibilityIdentifier(id)
        }
    }
    private func binding<Value>(_ key: WritableKeyPath<LiveSet, Value>) -> Binding<Value> {
        Binding(get: { liveSet[keyPath: key] }, set: { value in update { $0[keyPath: key] = value } })
    }
    private func update(_ change: (inout LiveSet) -> Void) {
        store.changeLiveExercise(exercise.id) { value in if let index = value.sets.firstIndex(where: { $0.id == liveSet.id }) { change(&value.sets[index]) } }
    }
    private func complete() {
        focus.wrappedValue = nil
        _ = store.completeLiveSet(exerciseID: exercise.id, setID: liveSet.id)
    }
}

private struct SetInputSurface: ViewModifier {
    let locked: Bool
    func body(content: Content) -> some View {
        content.font(.system(.headline, design: .rounded, weight: .medium)).monospacedDigit().multilineTextAlignment(.center)
            .foregroundStyle(locked ? AppColor.positive.opacity(0.8) : AppColor.text).frame(maxWidth: .infinity, minHeight: 44)
            .background(locked ? .clear : AppColor.elevated.opacity(0.6), in: RoundedRectangle(cornerRadius: 10)).disabled(locked)
    }
}
