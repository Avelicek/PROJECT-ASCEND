import SwiftUI

// A single accessory lives on the workout's NavigationStack, rather than on
// individual scroll rows whose conditional toolbars may not be registered.
struct LiveWorkoutKeyboard: View {
    @Environment(AppStore.self) private var store
    let exercise: LiveExercise
    let focus: FocusState<LiveSetFocus?>.Binding
    private var inputs: [SetInput] {
        var values: [SetInput] = []
        if exercise.allowsWeight { values.append(.kg) }
        if exercise.mode == .reps || exercise.mode == .weightAndReps { values.append(.reps) }
        if exercise.mode == .duration || exercise.mode == .distance { values.append(.seconds) }
        if exercise.mode == .distance { values.append(.meters) }
        if exercise.sets.first(where: { $0.id == focus.wrappedValue?.setID })?.rpe != nil { values.append(.rpe) }
        return values
    }
    var body: some View {
        HStack {
            Button { adjust(-1) } label: { Image(systemName: "minus") }.accessibilityLabel("Decrease value")
            Button { adjust(1) } label: { Image(systemName: "plus") }.accessibilityLabel("Increase value")
            Spacer()
            Button("Next", action: nextInput)
            Button("Complete", action: complete).fontWeight(.semibold).accessibilityIdentifier("live.keyboard.complete")
            Button("Done") { focus.wrappedValue = nil }
        }.frame(maxWidth: .infinity)
    }
    private func nextInput() {
        guard let current = focus.wrappedValue, let index = inputs.firstIndex(of: current.input) else { return }
        focus.wrappedValue = index + 1 < inputs.count ? .init(setID: current.setID, input: inputs[index + 1]) : nil
    }
    private func complete() {
        guard let current = focus.wrappedValue else { return }
        focus.wrappedValue = nil
        _ = store.completeLiveSet(exerciseID: exercise.id, setID: current.setID)
    }
    private func adjust(_ direction: Double) {
        guard let current = focus.wrappedValue else { return }
        store.changeLiveExercise(exercise.id) { entry in
            guard let index = entry.sets.firstIndex(where: { $0.id == current.setID }), entry.sets[index].completedAt == nil else { return }
            var edited = entry.sets[index]
            switch current.input {
            case .kg: edited.kilograms = min(1000, max(0, edited.kilograms + direction * exercise.weightStep))
            case .reps: edited.reps = min(2000, max(1, edited.reps + Int(direction)))
            case .rpe: edited.rpe = min(10, max(1, (edited.rpe ?? 7) + direction * 0.5))
            case .seconds: edited.seconds = min(86400, max(1, edited.seconds + direction * 15))
            case .meters: edited.distanceMeters = min(500000, max(1, edited.distanceMeters + direction * 100))
            }
            entry.sets[index] = edited
        }
    }
}

enum WorkoutClockText {
    static func duration(_ seconds: Double) -> String {
        let value = max(0, Int(seconds))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}

struct LiveWorkoutHeader: View {
    @Environment(AppStore.self) private var store
    let draft: LiveWorkout
    let selected: LiveExercise?
    let minimize: () -> Void
    let discard: () -> Void
    private var index: Int { selected.flatMap { entry in draft.exercises.firstIndex { $0.id == entry.id } } ?? 0 }
    private var working: [LiveSet] { draft.exercises.flatMap(\.sets).filter { !$0.isWarmup } }
    private var done: Int { working.filter { $0.completedAt != nil }.count }
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: minimize) { Image(systemName: "chevron.down").frame(width: 44, height: 44) }.accessibilityLabel("Minimize").accessibilityIdentifier("live.minimize")
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(WorkoutClockText.duration(store.actionDate().timeIntervalSince(draft.startedAt))).font(.system(.title3, design: .rounded, weight: .semibold))
                        .monospacedDigit().foregroundStyle(AppColor.strength).accessibilityIdentifier("live.elapsed")
                }
                Spacer()
                Button(action: discard) { Image(systemName: "ellipsis").frame(width: 44, height: 44) }.accessibilityLabel("Discard workout")
            }
            HStack(spacing: 8) {
                Button { select(offset: -1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.disabled(index == 0).accessibilityLabel("Previous exercise")
                VStack(spacing: 5) {
                    Text(selected?.name ?? "Your session").font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(AppColor.text).lineLimit(1).minimumScaleFactor(0.7)
                    Text(draft.exercises.isEmpty ? "ADD YOUR FIRST EXERCISE" : "\(index + 1) / \(draft.exercises.count) EXERCISES · \(done) / \(working.count) WORKING SETS")
                        .font(.system(size: 9, weight: .medium)).tracking(0.7).foregroundStyle(AppColor.muted)
                }.frame(maxWidth: .infinity)
                Button { select(offset: 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.disabled(index + 1 >= draft.exercises.count).accessibilityLabel("Next exercise")
            }
            LinearProgress(progress: Double(done) / Double(max(1, working.count)), tint: AppColor.strength, height: 3)
        }.padding(.horizontal, 12).padding(.bottom, 12).background(.ultraThinMaterial)
    }
    private func select(offset: Int) {
        let next = index + offset
        guard draft.exercises.indices.contains(next) else { return }
        _ = store.updateWorkout { $0?.selectedExerciseID = draft.exercises[next].id }
        AppHaptics.selection(enabled: store.settings.hapticsEnabled)
    }
}

struct FloatingRestTimer: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let exerciseID: String?
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let rest = store.activeWorkout?.rest ?? RestClock()
            let seconds = rest.remaining(at: timeline.date)
            HStack(spacing: 12) {
                ZStack {
                    ProgressRing(progress: rest.isActive ? 1 - Double(seconds) / max(1, rest.spanSeconds ?? Double(store.settings.restTimerSeconds)) : 1, tint: AppColor.strength, lineWidth: 3)
                    Image(systemName: rest.isPaused ? "pause.fill" : rest.isActive ? "timer" : "checkmark").font(.caption).foregroundStyle(AppColor.strength)
                }.frame(width: 38, height: 38)
                    .opacity(rest.isActive && seconds <= 5 && !rest.isPaused && !reduceMotion && !AppMotion.snapshotMode && seconds.isMultiple(of: 2) ? 0.6 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(rest.isActive ? rest.isPaused ? "REST PAUSED" : "REST" : "READY FOR NEXT SET").font(.system(size: 9, weight: .semibold)).foregroundStyle(AppColor.muted)
                    Text(rest.isActive ? WorkoutClockText.duration(Double(seconds)) : "Ready").font(.system(.title2, design: .rounded, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(AppColor.strength).accessibilityIdentifier("live.rest.state")
                }
                Spacer(minLength: 0)
                if rest.isActive {
                    Button(rest.isPaused ? "Resume" : "Pause") {
                        _ = store.updateWorkout { value in if rest.isPaused { value?.rest.resume(at: .now) } else { value?.rest.pause(at: .now) } }
                    }.frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("live.rest.pause")
                    Button("+30") { _ = store.updateWorkout { $0?.rest.add(seconds: 30, at: .now) } }.frame(minWidth: 44, minHeight: 44).accessibilityLabel("Add 30 seconds")
                    Button("Skip") { _ = store.updateWorkout { $0?.rest.skip() } }.frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("live.rest.skip")
                } else if let exerciseID {
                    Menu("\(store.preferredRest(for: exerciseID))s") {
                        ForEach([30, 60, 90, 120, 180, 240], id: \.self) { seconds in Button("\(seconds) seconds") { store.setPreferredRest(seconds, for: exerciseID) } }
                        Button(store.settings.automaticRestTimer ? "Disable automatic rest" : "Enable automatic rest") { _ = store.perform { store.settings.automaticRestTimer.toggle() } }
                    }
                }
            }.font(.caption.weight(.medium)).buttonStyle(PremiumPressStyle()).tint(AppColor.strength).frame(minHeight: 58)
        }.accessibilityElement(children: .contain)
    }
}
