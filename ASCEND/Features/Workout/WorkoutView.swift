import SwiftUI

struct WorkoutView: View {
    @Environment(AppStore.self) private var store
    @State private var showRecords = false
    @State private var showLibrary = false
    @State private var showGym = false
    @State private var createRoutine = false
    @State private var routineRoute: RoutineRoute?
    @State private var historyRoute: ExerciseRoute?
    @State private var pendingStart: WorkoutRoutine?
    @State private var capturePrepared = false
    @State private var guide = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "PUT IN THE WORK", title: "Training")
                if store.activeWorkout != nil {
                    PremiumCard(role: .hero, tint: AppColor.strength) {
                        VStack(alignment: .leading, spacing: 16) {
                            Eyebrow(text: "SAVED SESSION")
                            Text(store.activeWorkout?.title ?? "Your workout").font(.title2.weight(.semibold))
                            PrimaryAction(title: "Resume workout", symbol: "play.fill", tint: AppColor.strength) { store.startLiveWorkout() }.accessibilityIdentifier("workout.start")
                        }
                    }
                } else if store.brainArchive.settings.enabled {
                    GeneratedWorkoutCard()
                } else {
                    PrimaryAction(title: "Start workout", symbol: "play.fill", tint: AppColor.strength) { store.startLiveWorkout() }.accessibilityIdentifier("workout.start")
                }
                QuickActivityCard()
                DisclosureGroup("Saved templates & favorites") {
                HStack { SectionHeader(title: "Templates"); Spacer(); Button("Create", systemImage: "plus") { createRoutine = true }.font(.caption).frame(minHeight: 44).accessibilityIdentifier("workout.routine.create") }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.training.routines) { routine in
                            Button { routineRoute = .init(id: routine.id) } label: {
                                PremiumCard(role: .action, tint: AppColor.strength) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(routine.name).font(.headline).foregroundStyle(AppColor.text)
                                        Text("\(routine.exercises.count) exercises · \(routine.exercises.reduce(0) { $0 + $1.sets }) sets").font(.caption).foregroundStyle(AppColor.strength)
                                        let missing = routine.exercises.filter { !store.missingEquipment($0.exerciseID).isEmpty }.count
                                        Text(missing > 0 ? "\(missing) unavailable · replace" : "Ready in My Gym").font(.caption2).foregroundStyle(missing > 0 ? AppColor.warning : AppColor.muted)
                                    }.frame(width: 180, alignment: .leading)
                                }
                            }.buttonStyle(PremiumPressStyle()).accessibilityIdentifier("workout.routine.\(routine.name)")
                        }
                    }
                }
                }.font(.subheadline)
                SectionHeader(title: "Equipment & exercises")
                HStack {
                    Button("Exercise library", systemImage: "books.vertical") { showLibrary = true }.accessibilityIdentifier("workout.library")
                    Spacer(); Button("My Gym", systemImage: "slider.horizontal.3") { showGym = true }.accessibilityIdentifier("workout.gym")
                }.font(.caption.weight(.medium)).tint(AppColor.blue).frame(minHeight: 44)
                DisclosureGroup("Training balance") { WeeklyTrainingBalance().padding(.top, 12) }.font(.subheadline)
                HStack {
                    Button("Log previous workout") { store.presentedSheet = .workout }
                    Spacer()
                    Button("PR history") { showRecords = true }
                }.font(.caption).frame(minHeight: 44)
                SectionHeader(title: "Recent sessions", detail: "\(store.sessions.count) total")
                if store.sessions.isEmpty {
                    EmptyStateCard(symbol: "dumbbell", title: "Your first session awaits.", detail: "Choose an exercise and log your sets.")
                }
                ForEach(store.sessions.prefix(3), id: \.id) { session in WorkoutSessionCard(session: session) }
                if store.sessions.count > 3 {
                    DisclosureGroup("Earlier sessions") {
                        VStack(spacing: 16) { ForEach(store.sessions.dropFirst(3).prefix(17), id: \.id) { session in WorkoutSessionCard(session: session) } }.padding(.top, 12)
                    }.font(.subheadline)
                }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.accessibilityIdentifier("screen.workout").featureBackground(tint: AppColor.strength)
            .sheet(isPresented: $guide) { NavigationStack { ExerciseEducationView(exerciseID: "push_up").environment(store) }.preferredColorScheme(.dark) }
            .sheet(isPresented: $showRecords) { NavigationStack { RecordHistoryView().environment(store) }.preferredColorScheme(.dark) }
            .sheet(isPresented: $showLibrary) { NavigationStack { ExerciseLibraryView().environment(store) }.preferredColorScheme(.dark) }
            .sheet(isPresented: $showGym) { NavigationStack { TrainingProfileView().environment(store) }.preferredColorScheme(.dark) }
            .sheet(isPresented: $createRoutine) { NavigationStack { RoutineEditorView().environment(store) }.preferredColorScheme(.dark) }
            .sheet(item: $routineRoute, onDismiss: {
                if let pendingStart { self.pendingStart = nil; _ = store.startRoutine(pendingStart) }
            }) { route in
                NavigationStack { RoutineDetailView(routineID: route.id, onStart: { routine in pendingStart = routine; routineRoute = nil }).environment(store) }.preferredColorScheme(.dark)
            }
            .sheet(item: $historyRoute) { route in NavigationStack { ExerciseHistoryView(exerciseID: route.id).environment(store) }.preferredColorScheme(.dark) }
            .task {
                #if DEBUG
                guard store.isDemo, !capturePrepared, ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return }
                capturePrepared = true
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("--capture-guide") { guide = true }
                if arguments.contains("--capture-library") { showLibrary = true }
                if arguments.contains("--capture-routine"), let routine = store.training.routines.first(where: { $0.name == "Upper body" }) { routineRoute = .init(id: routine.id) }
                if arguments.contains("--capture-history") { historyRoute = .init(id: "db_row") }
                #endif
            }
    }
}

private struct WorkoutSessionCard: View {
    let session: WorkoutSession
    var body: some View {
        let snapshot = SessionSnapshot(session: session)
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(session.title).font(.headline)
                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(AppColor.muted)
                    }
                    Spacer()
                    PillStatus(title: session.isQuickLog ? "QUICK" : "FULL")
                }
                HStack {
                    StatBlock(title: "Working sets", value: "\(snapshot.workingSets)")
                    if snapshot.volumeKG > 0 { StatBlock(title: "External volume", value: "\(Int(snapshot.volumeKG).formatted()) kg", tint: AppColor.blue) }
                    if let rpe = snapshot.exertion { StatBlock(title: "Avg RPE", value: rpe.formatted(.number.precision(.fractionLength(1))), tint: AppColor.warning) }
                }
                if !snapshot.focus.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "SET FOCUS")
                        ForEach(snapshot.focus.prefix(3)) { focus in
                            HStack(spacing: 10) {
                                Text(focus.group).font(.caption).foregroundStyle(AppColor.muted).frame(width: 68, alignment: .leading)
                                LinearProgress(progress: focus.share, tint: AppColor.blue, height: 4)
                                Text(focus.share.formatted(.percent.precision(.fractionLength(0)))).font(.caption2).monospacedDigit().frame(width: 32, alignment: .trailing)
                            }
                        }
                    }.padding(12).background(AppColor.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                }
                DisclosureGroup("Exercises & sets") {
                ForEach(session.exercises.sorted { $0.order < $1.order }, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 7) {
                        Text(entry.exerciseName).font(.subheadline.weight(.medium))
                        ForEach(Array(entry.sets.sorted { $0.order < $1.order }.enumerated()), id: \.element.id) { index, set in
                            HStack {
                                Text(String(format: "%02d", index + 1)).font(.caption2).foregroundStyle(AppColor.muted)
                                    .frame(width: 27, height: 27).background(AppColor.elevated, in: RoundedRectangle(cornerRadius: 7))
                                Text(ExerciseIdentity.performance(set.performance, mode: entry.trackingMode, bodyweight: entry.exercise?.bodyweightCapable ?? false)).font(.subheadline.weight(.medium)).monospacedDigit()
                                Spacer()
                                if set.isWarmup { Text("WARM-UP").font(.caption2).foregroundStyle(AppColor.muted) }
                                else if let rpe = set.perceivedExertion { Text("RPE \(rpe.formatted())").font(.caption2).foregroundStyle(AppColor.blue) }
                                else { Image(systemName: "checkmark").font(.caption).foregroundStyle(AppColor.positive).accessibilityHidden(true) }
                            }.padding(.vertical, 5).padding(.horizontal, 8)
                                .background(AppColor.elevated.opacity(index.isMultiple(of: 2) ? 0.32 : 0.08), in: RoundedRectangle(cornerRadius: 10))
                                .accessibilityElement(children: .combine)
                        }
                    }
                }
                }.font(.caption)
            }
        }
    }
}
