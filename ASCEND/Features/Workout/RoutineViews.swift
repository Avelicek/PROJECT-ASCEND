import SwiftUI

struct RoutineRoute: Identifiable { let id: UUID }
struct RoutineDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let routineID: UUID
    var onStart: ((WorkoutRoutine) -> Void)? = nil
    @State private var editing = false
    @State private var deleting = false
    @State private var replacing: ExerciseRoute?
    private var routine: WorkoutRoutine? { store.training.routines.first { $0.id == routineID } }
    var body: some View {
        ScrollView {
            if let routine {
                VStack(alignment: .leading, spacing: 18) {
                    FeatureHeader(eyebrow: "YOUR ROUTINE", title: routine.name)
                    PremiumCard(role: .hero, tint: AppColor.strength) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack { StatBlock(title: "Exercises", value: "\(routine.exercises.count)", tint: AppColor.strength); StatBlock(title: "Planned sets", value: "\(routine.exercises.reduce(0) { $0 + $1.sets })", tint: AppColor.blue) }
                            Text("A starting point. Adjust sets, loads and order as you train.").font(.caption).foregroundStyle(AppColor.muted)
                            let unavailable = routine.exercises.filter { !store.missingEquipment($0.exerciseID).isEmpty || store.trainingMetadata($0.exerciseID) == nil }
                            if !unavailable.isEmpty { Label("\(unavailable.count) exercise\(unavailable.count == 1 ? "" : "s") unavailable", systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(AppColor.warning) }
                            if let onStart {
                                PrimaryAction(title: store.activeWorkout == nil ? "Start routine" : "Resume saved workout first", symbol: "play.fill", tint: AppColor.strength) { onStart(routine) }
                                    .disabled(!unavailable.isEmpty || store.activeWorkout != nil).accessibilityIdentifier("routine.start")
                            }
                        }
                    }
                    ForEach(Array(routine.exercises.enumerated()), id: \.element.id) { index, item in
                        PremiumCard(role: .metric, tint: ExerciseIdentity.tint(store.trainingMetadata(item.exerciseID))) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack { Text(String(format: "%02d", index + 1)).font(.caption).foregroundStyle(AppColor.muted); Text(store.trainingMetadata(item.exerciseID)?.name ?? "Unavailable exercise").font(.headline); Spacer() }
                                Text("\(item.sets) sets" + (item.repTarget.map { " · \($0) reps" } ?? "") + " · \(item.restSeconds)s rest").font(.caption).foregroundStyle(AppColor.secondary)
                                let missing = store.missingEquipment(item.exerciseID)
                                if !missing.isEmpty { Text("Missing: " + missing.map(\.title).sorted().joined(separator: ", ")).font(.caption).foregroundStyle(AppColor.warning) }
                                Button("Replace", systemImage: "arrow.triangle.2.circlepath") { replacing = .init(id: item.id.uuidString) }.font(.caption).frame(minHeight: 44).accessibilityIdentifier("routine.replace.\(item.exerciseID)")
                            }
                        }
                    }
                    if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(AppColor.warning) }
                }.padding(20)
            } else {
                EmptyStateCard(symbol: "dumbbell", title: "Routine unavailable", detail: "Choose another saved routine in Workout.").padding(AppSpacing.page)
            }
        }.accessibilityIdentifier("screen.routine").background(AppColor.background).navigationTitle("Routine").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Edit", systemImage: "pencil") { editing = true }
                        Button("Duplicate", systemImage: "plus.square.on.square") { if let routine { store.duplicateRoutine(routine) } }
                        Button("Delete", role: .destructive) { deleting = true }
                    } label: { Image(systemName: "ellipsis") }.accessibilityLabel("Routine options")
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $editing) { if let routine { NavigationStack { RoutineEditorView(routine: routine).environment(store) }.preferredColorScheme(.dark) } }
            .sheet(item: $replacing) { route in
                if let routine, let item = routine.exercises.first(where: { $0.id.uuidString == route.id }) {
                    NavigationStack { ExerciseLibraryView(onSelect: { exercise in
                        var copy = routine
                        if let index = copy.exercises.firstIndex(where: { $0.id == item.id }) {
                            copy.exercises[index].exerciseID = exercise.catalogID
                            if exercise.trackingMode == .duration || exercise.trackingMode == .distance { copy.exercises[index].repTarget = nil }
                            _ = store.saveRoutine(copy)
                            AppHaptics.selection(enabled: store.settings.hapticsEnabled)
                        }
                    }, replacing: item.exerciseID).environment(store) }.preferredColorScheme(.dark)
                }
            }
            .confirmationDialog("Delete this routine? Completed workouts stay in your history.", isPresented: $deleting, titleVisibility: .visible) {
                Button("Delete routine", role: .destructive) { if store.editTraining({ $0.routines.removeAll { $0.id == routineID } }) { dismiss() } }
            }
    }
}

struct RoutineEditorView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var routine: WorkoutRoutine
    @State private var adding = false
    init(routine: WorkoutRoutine = .init(name: "", exercises: [])) { _routine = State(initialValue: routine) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Routine name", text: $routine.name).font(.title2.weight(.semibold)).padding(14).background(AppColor.elevated, in: RoundedRectangle(cornerRadius: 14))
                    .accessibilityIdentifier("routine.name")
                ForEach(routine.exercises) { item in editorRow(item) }
                PrimaryAction(title: "Add exercise", symbol: "plus", tint: AppColor.strength) { adding = true }
                if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(AppColor.warning) }
            }.padding(20)
        }.background(AppColor.background).navigationTitle("Edit routine").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { routine.name = routine.name.trimmingCharacters(in: .whitespacesAndNewlines); if store.saveRoutine(routine) { dismiss() } }.disabled(!routine.isValid).accessibilityIdentifier("routine.save") }
            }
            .sheet(isPresented: $adding) {
                NavigationStack { ExerciseLibraryView(onSelect: { exercise in
                    guard !routine.exercises.contains(where: { $0.exerciseID == exercise.catalogID }), routine.exercises.count < 40 else { return }
                    routine.exercises.append(.init(exercise.catalogID))
                }).environment(store) }.preferredColorScheme(.dark)
            }
    }
    private func editorRow(_ item: RoutineExercise) -> some View {
        PremiumCard(role: .metric, tint: AppColor.strength) {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.trainingMetadata(item.exerciseID)?.name ?? item.exerciseID).font(.headline)
                Stepper("\(item.sets) working sets", value: binding(item.id, \.sets, fallback: item.sets), in: 1...40).font(.caption)
                if let metadata = store.trainingMetadata(item.exerciseID), metadata.mode == .reps || metadata.mode == .weightAndReps {
                    Toggle("Rep target", isOn: Binding(get: { item.repTarget != nil }, set: { value in edit(item.id) { $0.repTarget = value ? 10 : nil } })).font(.caption).tint(AppColor.strength)
                    if item.repTarget != nil { Stepper("\(item.repTarget ?? 10) reps", value: Binding(get: { item.repTarget ?? 10 }, set: { value in edit(item.id) { $0.repTarget = value } }), in: 1...2000).font(.caption) }
                }
                Stepper("\(item.restSeconds)s rest", value: binding(item.id, \.restSeconds, fallback: item.restSeconds), in: 15...900, step: 15).font(.caption)
                HStack {
                    Button("Earlier", systemImage: "arrow.up") { move(item.id, by: -1) }.disabled(routine.exercises.first?.id == item.id)
                    Button("Later", systemImage: "arrow.down") { move(item.id, by: 1) }.disabled(routine.exercises.last?.id == item.id)
                    Spacer(); Button("Remove") { routine.exercises.removeAll { $0.id == item.id } }.foregroundStyle(AppColor.muted)
                }.font(.caption).frame(minHeight: 44)
            }
        }
    }
    private func edit(_ id: UUID, _ change: (inout RoutineExercise) -> Void) { if let index = routine.exercises.firstIndex(where: { $0.id == id }) { change(&routine.exercises[index]) } }
    private func binding<Value>(_ id: UUID, _ key: WritableKeyPath<RoutineExercise, Value>, fallback: Value) -> Binding<Value> {
        Binding(get: { routine.exercises.first { $0.id == id }.map { $0[keyPath: key] } ?? fallback }, set: { value in edit(id) { $0[keyPath: key] = value } })
    }
    private func move(_ id: UUID, by offset: Int) { if let index = routine.exercises.firstIndex(where: { $0.id == id }), routine.exercises.indices.contains(index + offset) { routine.exercises.swapAt(index, index + offset) } }
}

struct WeeklyTrainingBalance: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        PremiumCard(role: .analytics, tint: AppColor.strength) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "THIS WEEK · TRAINING EXPOSURE")
                let maximum = max(1, store.weeklyExposure.map { $0.1 }.max() ?? 0)
                ForEach(store.weeklyExposure, id: \.0) { group, value in
                    HStack { Text(group).font(.caption).foregroundStyle(AppColor.secondary).frame(width: 72, alignment: .leading); LinearProgress(progress: value / maximum, tint: AppColor.strength, height: 4); Text(value.formatted(.number.precision(.fractionLength(1)))).font(.caption2).foregroundStyle(AppColor.muted).monospacedDigit() }
                }
                Text("Full-session set contributions show relative exposure, not muscle growth or a target to fill. Quick totals are excluded.").font(.caption2).foregroundStyle(AppColor.muted)
                DisclosureGroup("Movement balance") {
                    ForEach(store.weeklyMovementExposure, id: \.0) { movement, count in
                        HStack { Text(movement.title); Spacer(); Text("\(count) sets").monospacedDigit() }.font(.caption).foregroundStyle(AppColor.muted).padding(.vertical, 5)
                    }
                }.font(.caption).tint(AppColor.muted)
            }
        }
    }
}
