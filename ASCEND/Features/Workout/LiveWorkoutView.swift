import SwiftUI

struct LiveWorkoutView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var choosing = false
    @State private var discarding = false
    @State private var removing = false
    @State private var finishing = false
    @FocusState private var inputFocused: Bool
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
            .interactiveDismissDisabled()
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
            HStack {
                Button("Minimize", systemImage: "chevron.down") { dismiss() }.font(.caption).frame(minHeight: 44).accessibilityIdentifier("live.minimize")
                Spacer()
                PillStatus(title: "LIVE SESSION", tint: AppColor.positive)
                Spacer()
                Button { discarding = true } label: { Image(systemName: "trash").frame(width: 44, height: 44) }
                    .foregroundStyle(AppColor.muted).accessibilityLabel("Discard workout")
            }.padding(.horizontal, 20)
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
                            LiveExerciseCard(exercise: selected)
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
                }.padding(20)
            }.scrollDismissesKeyboard(.interactively).accessibilityIdentifier("screen.liveworkout")
            VStack(spacing: 10) {
                RestTimerPanel(exerciseID: selected?.catalogID)
                PrimaryAction(title: "Finish workout", symbol: "checkmark") { finishing = true }
                    .disabled(draft.completedSets == 0).accessibilityIdentifier("live.finish")
            }.padding(.horizontal, 20).padding(.vertical, 12).background(AppColor.surface)
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

private struct RestTimerPanel: View {
    @Environment(AppStore.self) private var store
    let exerciseID: String?
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let rest = store.activeWorkout?.rest ?? RestClock()
            HStack(spacing: 12) {
                Image(systemName: "timer").foregroundStyle(AppColor.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text(rest.isActive ? rest.isPaused ? "REST PAUSED" : "REST" : "REST TIMER").font(.caption2).foregroundStyle(AppColor.muted)
                    Text(rest.isActive ? String(format: "%d:%02d", rest.remaining(at: timeline.date) / 60, rest.remaining(at: timeline.date) % 60) : "Ready")
                        .font(.title3.weight(.semibold)).monospacedDigit().accessibilityIdentifier("live.rest.state")
                }
                Spacer()
                if rest.isActive {
                    Button(rest.isPaused ? "Resume" : "Pause") {
                        _ = store.updateWorkout { draft in
                            if rest.isPaused { draft?.rest.resume(at: .now) } else { draft?.rest.pause(at: .now) }
                        }
                    }.accessibilityIdentifier("live.rest.pause")
                    Button("+30") { _ = store.updateWorkout { $0?.rest.add(seconds: 30, at: .now) } }
                    Button("Skip") { _ = store.updateWorkout { $0?.rest.skip() } }.accessibilityIdentifier("live.rest.skip")
                } else if let exerciseID {
                    Menu("\(store.preferredRest(for: exerciseID))s") {
                        ForEach([30, 60, 90, 120, 180, 240], id: \.self) { seconds in
                            Button("\(seconds) seconds") { store.setPreferredRest(seconds, for: exerciseID) }
                        }
                        Button(store.settings.automaticRestTimer ? "Disable automatic rest" : "Enable automatic rest") {
                            _ = store.perform { store.settings.automaticRestTimer.toggle() }
                        }
                    }
                }
            }.font(.caption.weight(.medium)).frame(minHeight: 48)
        }.accessibilityElement(children: .contain)
    }
}
