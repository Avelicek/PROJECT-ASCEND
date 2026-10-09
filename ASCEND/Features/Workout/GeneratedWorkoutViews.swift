import SwiftUI

struct GeneratedWorkoutCard: View {
    @Environment(AppStore.self) private var store
    @State private var showPlan = false
    var body: some View {
        let decision = store.brainDecision
        PremiumCard(role: .hero, tint: AppColor.strength) {
            VStack(alignment: .leading, spacing: 16) {
                HStack { CoachIdentity(); Eyebrow(text: "TODAY'S GENERATED WORKOUT") }
                Text(decision.session?.name ?? "Recovery today").font(.title2.weight(.semibold))
                if let plan = decision.session {
                    Text("~\(decision.duration ?? 0) min · \(plan.exercises.count) exercises").font(.subheadline).foregroundStyle(AppColor.secondary)
                    Button("Why this workout?", systemImage: "info.circle") { showPlan = true }.font(.subheadline).frame(minHeight: 44).accessibilityIdentifier("workout.why")
                    PrimaryAction(title: "Start workout", symbol: "play.fill", tint: AppColor.strength) { store.startBrainSession() }.accessibilityIdentifier("workout.start")
                    // Stable accessibility target for the existing generated-session journey.
                    Button("Review exercises") { showPlan = true }.font(.caption).frame(minHeight: 44).accessibilityIdentifier("workout.brain.start")
                    ContextualCoachButton(title: "Talk about this workout", question: "Why this workout?")
                } else {
                    Text(decision.reasons.last ?? "Give recovery time today.").font(.subheadline).foregroundStyle(AppColor.secondary)
                    PrimaryAction(title: "Review recovery", symbol: "figure.stand", tint: AppColor.recovery) { store.navigationRequest = .recovery }
                }
                Button("Build my own session") { store.startLiveWorkout() }.font(.caption).frame(minHeight: 44).accessibilityIdentifier("workout.manual.start")
            }
        }.onAppear {
            #if DEBUG
            if store.isDemo && AppMotion.snapshotMode && ProcessInfo.processInfo.arguments.contains("--capture-plan") { showPlan = true }
            #endif
        }.sheet(isPresented: $showPlan) { NavigationStack { GeneratedPlanView().environment(store) }.preferredColorScheme(.dark) }
    }
}
struct GeneratedPlanView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var pendingStart = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FeatureHeader(eyebrow: "TODAY'S PLAN", title: store.brainDecision.focus)
                Text("~\(store.brainDecision.duration ?? 0) min · \(store.brainDecision.confidence.rawValue) confidence").font(.caption).foregroundStyle(AppColor.muted)
                Eyebrow(text: "WHY THIS WORKOUT?")
                ForEach(Array((store.brainDecision.reasons + store.brainDecision.warnings).enumerated()), id: \.offset) { _, reason in Text(reason).font(.subheadline).foregroundStyle(AppColor.secondary) }
                if let plan = store.brainDecision.session {
                    WorkoutFocusMap(exerciseIDs: plan.exercises.map(\.exerciseID), sets: Dictionary(grouping: plan.exercises, by: \.exerciseID).mapValues { $0.reduce(0) { $0 + $1.sets } })
                    ForEach(plan.exercises) { item in
                        let exercise = store.trainingMetadata(item.exerciseID)
                        PremiumCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(exercise?.name ?? item.exerciseID).font(.headline)
                                Text("\(item.sets) sets · \(item.restSeconds)s rest").font(.caption).foregroundStyle(AppColor.muted)
                                if let opportunity = store.brainDecision.opportunities.first(where: { $0.exerciseID == item.exerciseID }) { Text(opportunity.suggestion.explanation).font(.caption).foregroundStyle(AppColor.secondary) }
                                NavigationLink("How do I do this?") { ExerciseEducationView(exerciseID: item.exerciseID) }.font(.caption).frame(minHeight: 44)
                            }
                        }
                    }
                    PrimaryAction(title: "Use this plan", symbol: "play.fill") { pendingStart = true; dismiss() }.accessibilityIdentifier("workout.plan.start")
                }
            }.padding(20)
        }.featureBackground(tint: AppColor.strength).toolbar(.visible, for: .navigationBar).navigationTitle("Your plan").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("screen.generatedplan")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onDisappear { if pendingStart { pendingStart = false; store.startBrainSession() } }
    }
}
struct QuickActivityCard: View {
    @Environment(AppStore.self) private var store
    @State private var selection: String?
    @State private var custom = false
    var body: some View {
        PremiumCard(role: .inline) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "QUICK ACTIVITY")
                Text("Every bit of work changes your plan.").font(.subheadline).foregroundStyle(AppColor.secondary)
                ViewThatFits(in: .horizontal) {
                    HStack { shortcuts }
                    VStack(alignment: .leading) { shortcuts }
                }
                Button("Custom activity", systemImage: "plus") { custom = true }.font(.caption).frame(minHeight: 44)
            }
        }.onAppear {
            #if DEBUG
            if store.isDemo && AppMotion.snapshotMode && ProcessInfo.processInfo.arguments.contains("--capture-quick") { selection = "push_up" }
            #endif
        }.sheet(isPresented: Binding(get: { selection != nil }, set: { if !$0 { selection = nil } })) {
            if let selection { NavigationStack { QuickActivityEditor(exerciseID: selection).environment(store) }.preferredColorScheme(.dark) }
        }.sheet(isPresented: $custom) { NavigationStack { WorkoutEditor().environment(store) }.preferredColorScheme(.dark) }
    }
    private var shortcuts: some View {
        ForEach([("push_up", "Push-ups"), ("bodyweight_squat", "Squats"), ("pull_up", "Pull-ups"), ("plank", "Plank"), ("running", "Run")], id: \.0) { id, title in
            Button(title) { selection = id }.font(.caption.weight(.medium)).frame(minHeight: 44).accessibilityIdentifier("quick.\(id)")
        }
    }
}
struct QuickActivityEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let exerciseID: String
    @State private var amount = 20.0
    @State private var distance = 1.0
    @State private var rating: EffortRating = .moderate
    @State private var measurementMode: ExerciseMeasurementMode = .repsBodyweight
    @State private var measuredValue = 0.0
    @State private var measuredUnit = "count"
    @State private var saved = false
    @State private var before = 0
    private var exercise: Exercise? { store.exercises.first { $0.catalogID == exerciseID } }
    var body: some View {
        Form {
            if saved {
                Section("Activity integrated") {
                    Text("\(before.formatted(.number.sign(strategy: .always()))) → \(store.projectedScore.delta.formatted(.number.sign(strategy: .always()))) ELO").font(.title2.weight(.semibold)).contentTransition(.numericText())
                    if let exercise { MuscleActivationPreview(contributions: exercise.contributions, pattern: store.trainingMetadata(exerciseID)?.pattern ?? .coreStability, exerciseID: exerciseID) }
                    Text("Muscle exposure, recovery and today's plan updated.")
                    if measurementMode == .caloriesDuration || measurementMode == .custom { Text("Observed \(measuredValue.formatted()) \(measurementMode == .caloriesDuration ? "kcal" : measuredUnit)").font(.caption) }
                    Text(store.brainDecision.reasons.joined(separator: " ")).font(.caption)
                }
            } else if let exercise {
                Section(exercise.name) {
                    NumericField(title: exercise.trackingMode == .duration || exercise.trackingMode == .distance ? "Minutes" : "Total reps", value: $amount)
                    if exercise.trackingMode == .distance { NumericField(title: "Distance · km", value: $distance) }
                    if exercise.trackingMode == .duration || exercise.trackingMode == .distance {
                        Picker("Measurement", selection: $measurementMode) {
                            Text(exercise.trackingMode == .distance ? "Distance and duration" : "Duration / hold").tag(exercise.trackingMode == .distance ? ExerciseMeasurementMode.distanceDuration : .duration)
                            Text("Observed calories + duration").tag(ExerciseMeasurementMode.caloriesDuration)
                            Text("Custom quantity + duration").tag(ExerciseMeasurementMode.custom)
                        }
                        if measurementMode == .caloriesDuration || measurementMode == .custom {
                            NumericField(title: measurementMode == .caloriesDuration ? "Observed kcal" : "Observed quantity", value: $measuredValue)
                            if measurementMode == .custom { TextField("Unit", text: $measuredUnit) }
                            Text("Use your observed device reading or own count. Duration and effort determine modeled training load; arbitrary units are not converted into calories or muscle fatigue.").font(.caption).foregroundStyle(AppColor.muted)
                        }
                    }
                    Picker("Effort", selection: $rating) { ForEach(EffortRating.allCases, id: \.self) { Text(exercise.trackingMode == .reps || exercise.trackingMode == .weightAndReps ? $0.title : $0.intensityTitle).tag($0) } }
                }
                Section { PrimaryAction(title: "Log activity", symbol: "checkmark") {
                    guard amount.isFinite, amount > 0, amount <= (exercise.trackingMode == .reps ? 2000 : 1440), distance.isFinite,
                          (0...500).contains(distance), exercise.trackingMode != .reps || amount.rounded() == amount else { store.errorMessage = "Enter a valid amount; repetitions must be whole numbers."; return }
                    let timed = exercise.trackingMode == .duration || exercise.trackingMode == .distance
                    let performance = SetPerformance(reps: timed ? 0 : Int(amount), seconds: timed ? amount * 60 : 0, distanceMeters: exercise.trackingMode == .distance ? distance * 1000 : 0)
                    let measurement = measurementMode == .caloriesDuration || measurementMode == .custom ? ActivityMeasurement(mode: measurementMode, value: measuredValue, unit: measurementMode == .caloriesDuration ? "kcal" : measuredUnit.trimmingCharacters(in: .whitespacesAndNewlines)) : nil
                    if let measurement, !measurement.isValid { store.errorMessage = "Enter a positive observed quantity and a short unit."; return }
                    before = store.projectedScore.delta
                    if store.logWorkout(exercise: exercise, sets: [performance], at: store.actionDate(), quick: true, exertion: Double(rating.rawValue), measurement: measurement) { saved = true; AppHaptics.success(enabled: store.settings.hapticsEnabled) }
                }.accessibilityIdentifier("quick.save") }
            }
        }.navigationTitle("Quick activity").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("screen.quickactivity")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .onAppear {
                if exercise?.trackingMode == .duration { amount = 1; measurementMode = .duration }
                if exercise?.trackingMode == .distance { measurementMode = .distanceDuration }
            }
    }
}
