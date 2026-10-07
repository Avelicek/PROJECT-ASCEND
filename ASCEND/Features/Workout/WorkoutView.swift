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
    private var sets: Int { store.sessions.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.sets.count } } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "PUT IN THE WORK", title: "Training")
                PremiumCard(role: .hero, tint: AppColor.strength) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            VStack(alignment: .leading, spacing: 9) {
                                Eyebrow(text: store.activeWorkout == nil ? "YOUR NEXT SESSION" : "SAVED SESSION")
                                Text(store.activeWorkout == nil ? "Ready when you are." : "Pick up where you left off.").font(.system(.title3, design: .rounded, weight: .semibold)).foregroundStyle(AppColor.text)
                            }
                            Spacer(minLength: 8)
                            ZStack {
                                Circle().stroke(AppColor.strength.opacity(0.12), lineWidth: 1)
                                Circle().trim(from: 0.05, to: 0.75).stroke(AppColor.strength.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round)).padding(8)
                                Image(systemName: "dumbbell.fill").font(.system(size: 26)).foregroundStyle(AppColor.strength)
                            }.frame(width: 64, height: 64).accessibilityHidden(true)
                        }
                        MetricStrip(metrics: [
                            GlanceMetric(title: "Sessions", value: "\(store.sessions.count)", symbol: "bolt.fill", tint: AppColor.strength),
                            GlanceMetric(title: "Sets logged", value: "\(sets)", symbol: "square.stack", tint: AppColor.strength),
                            GlanceMetric(title: "Records", value: "\(store.records.count)", symbol: "trophy", tint: AppColor.gold)
                        ])
                        PrimaryAction(title: store.activeWorkout == nil ? "Start workout" : "Resume workout", symbol: "play.fill", tint: AppColor.strength) { store.startLiveWorkout() }
                            .accessibilityIdentifier("workout.start")
                        HStack {
                            Button("Log previous workout") { store.presentedSheet = .workout }
                            Spacer()
                            Button("PR history") { showRecords = true }
                        }.font(.caption).frame(minHeight: 44)
                    }
                }
                HStack {
                    Button("Exercise library", systemImage: "books.vertical") { showLibrary = true }.accessibilityIdentifier("workout.library")
                    Spacer(); Button("My Gym", systemImage: "slider.horizontal.3") { showGym = true }.accessibilityIdentifier("workout.gym")
                }.font(.caption.weight(.medium)).tint(AppColor.blue).frame(minHeight: 44)
                if let recommendation = store.recommendedRoutine {
                    Button { routineRoute = .init(id: recommendation.routineID) } label: {
                        PremiumCard(role: .status, tint: AppColor.recovery) {
                            VStack(alignment: .leading, spacing: 8) { Eyebrow(text: "SUGGESTED FOCUS · OPTIONAL"); Text(recommendation.title).font(.headline).foregroundStyle(AppColor.recovery); Text(recommendation.reason).font(.caption).foregroundStyle(AppColor.muted) }
                        }
                    }.buttonStyle(PremiumPressStyle())
                }
                HStack { SectionHeader(title: "Routines"); Spacer(); Button("Create", systemImage: "plus") { createRoutine = true }.font(.caption).frame(minHeight: 44).accessibilityIdentifier("workout.routine.create") }
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
                WeeklyTrainingBalance()
                SectionHeader(title: "Recent sessions", detail: "\(store.sessions.count) total")
                if store.sessions.isEmpty {
                    EmptyStateCard(symbol: "dumbbell", title: "Your first session awaits.", detail: "Choose an exercise and log your sets.")
                }
                ForEach(store.sessions.prefix(20), id: \.id) { session in WorkoutSessionCard(session: session) }
            }.padding(.horizontal, AppSpacing.page).padding(.bottom, AppSpacing.lg)
        }.accessibilityIdentifier("screen.workout").featureBackground(tint: AppColor.strength)
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
                if arguments.contains("--capture-library") { showLibrary = true }
                if arguments.contains("--capture-routine"), let routine = store.training.routines.first(where: { $0.name == "Upper body" }) { routineRoute = .init(id: routine.id) }
                if arguments.contains("--capture-history") { historyRoute = .init(id: "db_row") }
                #endif
            }
    }
}

private struct WorkoutSessionCard: View {
    let session: WorkoutSession
    private var snapshot: SessionSnapshot { SessionSnapshot(session: session) }
    var body: some View {
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
            }
        }
    }
    private func setDescription(_ set: WorkoutSet, mode: TrackingMode) -> String {
        switch mode {
        case .reps: "\(set.reps) reps" + (set.weightKG > 0 ? " · +\(set.weightKG.formatted()) kg" : "")
        case .weightAndReps: "\(set.weightKG.formatted()) kg × \(set.reps)"
        case .duration: "\((set.durationSeconds / 60).formatted(.number.precision(.fractionLength(0...1)))) min"
        case .distance: "\((set.distanceMeters / 1000).formatted()) km · \(Int(set.durationSeconds / 60)) min"
        }
    }
}
