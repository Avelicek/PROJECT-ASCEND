import SwiftUI

private struct RestWakeKey: Hashable { let active: Bool; let deadline: Date? }

struct LiveWorkoutView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var choosing = false
    @State private var discarding = false
    @State private var removing = false
    @State private var finishing = false
    @State private var replacing = false
    @State private var keptRecoveryExercises: Set<UUID> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var inputFocused: Bool
    @FocusState private var setFocus: LiveSetFocus?
    private var selected: LiveExercise? {
        guard let draft = store.activeWorkout else { return nil }
        return draft.exercises.first { $0.id == draft.selectedExerciseID } ?? draft.exercises.first
    }
    var body: some View {
        Group {
            if let summary = store.completedWorkout { WorkoutCompletionView(summary: summary) { store.completedWorkout = nil; dismiss() } }
            else if let draft = store.activeWorkout { training(draft) }
            else { Text("No active workout").task { dismiss() } }
        }.preferredColorScheme(.dark).tint(AppColor.blue).background(AppColor.background)
            .onChange(of: store.activeWorkout?.selectedExerciseID) { _, _ in setFocus = nil; inputFocused = false }
            .interactiveDismissDisabled().toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let keyboardTarget = setFocus, let selected {
                    LiveWorkoutKeyboard(exercise: selected, target: keyboardTarget, focus: $setFocus)
                        .padding(.horizontal, 18).frame(minHeight: 48).background(.regularMaterial)
                } else if inputFocused {
                    HStack { Spacer(); Button("Done") { inputFocused = false }.frame(minHeight: 48) }.padding(.horizontal, 18).background(.regularMaterial)
                }
            }
            .sheet(isPresented: $choosing) { NavigationStack { ExerciseLibraryView(onSelect: { exercise in
                store.addLiveExercise(exercise)
                if let id = store.activeWorkout?.exercises.last?.id { _ = store.updateWorkout { $0?.selectedExerciseID = id } }
            }).environment(store) }.preferredColorScheme(.dark) }
            .sheet(isPresented: $replacing) {
                if let selected { NavigationStack { ExerciseLibraryView(onSelect: { exercise in _ = store.replaceLiveExercise(selected.id, with: exercise) }, replacing: selected.catalogID).environment(store) }.preferredColorScheme(.dark) }
            }
            .confirmationDialog("Discard this workout? Completed history will be preserved.", isPresented: $discarding, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) { store.discardLiveWorkout() }
                Button("Keep training", role: .cancel) {}
            }
            .confirmationDialog("Remove this exercise and its sets?", isPresented: $removing, titleVisibility: .visible) {
                Button("Remove exercise", role: .destructive) {
                    guard let selected else { return }
                    if store.updateWorkout({ $0?.exercises.removeAll { $0.id == selected.id } }) { store.recordPreference(selected.catalogID, .exerciseSkipped) }
                }
            }
            .confirmationDialog("Finish workout? Only completed sets will be saved.", isPresented: $finishing, titleVisibility: .visible) {
                Button("Finish workout") { _ = store.finishLiveWorkout() }
                Button("Keep training", role: .cancel) {}
            }
    }
    private func training(_ draft: LiveWorkout) -> some View {
        VStack(spacing: 0) {
            LiveWorkoutHeader(draft: draft, selected: selected) { dismiss() } discard: { discarding = true }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Session title", text: Binding(get: { store.activeWorkout?.title ?? "" }, set: { text in _ = store.updateWorkout { $0?.title = String(text.prefix(80)) } }))
                        .focused($inputFocused)
                        .font(.subheadline.weight(.medium)).foregroundStyle(AppColor.muted).accessibilityIdentifier("live.title")
                    HStack {
                        Label("\(draft.completedSets) sets complete", systemImage: "checkmark.circle").font(.caption).foregroundStyle(AppColor.muted)
                        Spacer()
                        Button("Add exercise", systemImage: "plus") { choosing = true }.font(.caption.weight(.semibold)).frame(minHeight: 44).accessibilityIdentifier("live.add.exercise")
                    }
                    if draft.exercises.isEmpty {
                        EmptyStateCard(symbol: "dumbbell", title: "Choose your first exercise.", detail: "Your progress is saved locally as you train.")
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(draft.exercises) { exercise in
                                    Button { _ = store.updateWorkout { $0?.selectedExerciseID = exercise.id } } label: {
                                        Text(exercise.name).font(.caption.weight(.semibold)).padding(12)
                                            .background(selected?.id == exercise.id ? AppColor.blue.opacity(0.22) : AppColor.surface, in: Capsule())
                                    }.buttonStyle(.plain).accessibilityIdentifier("live.exercise.\(exercise.catalogID)")
                                }
                            }
                        }
                        if let selected {
                            if !keptRecoveryExercises.contains(selected.id), let warning = store.brainRecoveryWarning(selected) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(warning).font(.caption).foregroundStyle(AppColor.warning)
                                    HStack {
                                        Button("Keep") { keptRecoveryExercises.insert(selected.id); store.recordPreference(selected.catalogID, .substitutionRejected) }
                                        Spacer()
                                        Button("Replace") { setFocus = nil; replacing = true }.disabled(selected.sets.contains { $0.completedAt != nil })
                                        Button("Skip") {
                                            if store.updateWorkout({ $0?.exercises.removeAll { $0.id == selected.id } }) { store.recordPreference(selected.catalogID, .exerciseSkipped) }
                                        }.disabled(selected.sets.contains { $0.completedAt != nil })
                                    }.font(.caption).frame(minHeight: 44)
                                }.accessibilityIdentifier("brain.live.recovery")
                            }
                            LiveExerciseCard(exercise: selected, focus: $setFocus).id(selected.id)
                                .transition(.opacity).animation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.micro, value: draft.selectedExerciseID)
                            if let hint = store.brainHint(selected) { Text(hint).font(.caption).foregroundStyle(AppColor.muted).accessibilityIdentifier("brain.live.hint") }
                            HStack {
                                Button("Earlier", systemImage: "arrow.left") { move(selected.id, by: -1) }
                                    .disabled(draft.exercises.first?.id == selected.id)
                                Button("Later", systemImage: "arrow.right") { move(selected.id, by: 1) }
                                    .disabled(draft.exercises.last?.id == selected.id)
                                Spacer()
                                Button("Replace") { setFocus = nil; replacing = true }.disabled(selected.sets.contains { $0.completedAt != nil }).accessibilityIdentifier("live.replace")
                                Button("Remove") { removing = true }.foregroundStyle(AppColor.muted)
                            }.font(.caption).frame(minHeight: 44)
                        }
                    }
                    if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(AppColor.warning) }
                }.padding(.horizontal, 18).padding(.vertical, 14)
            }.scrollDismissesKeyboard(.interactively).accessibilityIdentifier("screen.liveworkout")
            VStack(spacing: 10) {
                FloatingRestTimer(exerciseID: selected?.catalogID)
                PrimaryAction(title: "Finish workout", symbol: "checkmark", tint: AppColor.strength) { finishing = true }
                    .disabled(draft.completedSets == 0).accessibilityIdentifier("live.finish")
            }.padding(.horizontal, 18).padding(.vertical, 10).background(.ultraThinMaterial)
        }.task(id: RestWakeKey(active: scenePhase == .active, deadline: draft.rest.deadline)) {
            guard scenePhase == .active, let deadline = draft.rest.deadline else { return }
            do { try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow))) } catch { return }
            store.tickRest(at: .now)
        }
    }
    private func move(_ id: UUID, by offset: Int) {
        _ = store.updateWorkout { draft in
            guard let index = draft?.exercises.firstIndex(where: { $0.id == id }), let count = draft?.exercises.count,
                  (0..<count).contains(index + offset) else { return }
            draft?.exercises.swapAt(index, index + offset)
        }
    }
}

