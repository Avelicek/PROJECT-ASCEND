import SwiftUI

struct LiveWorkoutView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var choosing = false
    @State private var discarding = false
    @State private var removing = false
    @State private var finishing = false
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
            .interactiveDismissDisabled().toolbar(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if setFocus != nil, let selected {
                        LiveWorkoutKeyboard(exercise: selected, focus: $setFocus)
                    } else if inputFocused { Button("Done") { inputFocused = false } }
                }
            }
            .sheet(isPresented: $choosing) { LiveExercisePicker().environment(store) }
            .confirmationDialog("Discard this workout? Completed history will be preserved.", isPresented: $discarding, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) { store.discardLiveWorkout() }
                Button("Keep training", role: .cancel) {}
            }
            .confirmationDialog("Remove this exercise and its sets?", isPresented: $removing, titleVisibility: .visible) {
                Button("Remove exercise", role: .destructive) {
                    guard let selected else { return }
                    _ = store.updateWorkout { $0?.exercises.removeAll { $0.id == selected.id } }
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
                        .font(.title2.weight(.semibold)).accessibilityIdentifier("live.title")
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
                            LiveExerciseCard(exercise: selected, focus: $setFocus)
                            HStack {
                                Button("Earlier", systemImage: "arrow.left") { move(selected.id, by: -1) }
                                    .disabled(draft.exercises.first?.id == selected.id)
                                Button("Later", systemImage: "arrow.right") { move(selected.id, by: 1) }
                                    .disabled(draft.exercises.last?.id == selected.id)
                                Spacer()
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
        }.task {
            while !Task.isCancelled {
                store.tickRest(at: .now)
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
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

private struct LiveExercisePicker: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    TextField("Find an exercise", text: $search).padding(14).background(AppColor.elevated, in: RoundedRectangle(cornerRadius: 14))
                    ForEach(store.exercises.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }, id: \.catalogID) { exercise in
                        Button {
                            store.addLiveExercise(exercise)
                            if let id = store.activeWorkout?.exercises.last?.id { _ = store.updateWorkout { $0?.selectedExerciseID = id } }
                            dismiss()
                        } label: {
                            PremiumCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(exercise.name).font(.headline)
                                        Text(exercise.equipmentRaw.capitalized).font(.caption).foregroundStyle(AppColor.muted)
                                    }
                                    Spacer(); Image(systemName: "plus.circle").foregroundStyle(AppColor.blue)
                                }
                            }
                        }.buttonStyle(PremiumPressStyle()).accessibilityIdentifier("live.choose.\(exercise.catalogID)")
                            .disabled(store.activeWorkout?.exercises.contains { $0.catalogID == exercise.catalogID } ?? false)
                    }
                }.padding(20)
            }.background(AppColor.background).navigationTitle("Add exercise").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
}
