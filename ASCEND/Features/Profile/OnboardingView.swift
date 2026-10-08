import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 1
    @State private var name = ""
    @State private var height = 175.0
    @State private var weight: Double?
    @State private var target: Double?
    @State private var chest: Double?
    @State private var waist: Double?
    @State private var hips: Double?
    @State private var biceps: Double?
    @State private var thigh: Double?
    @State private var calories = 3000.0
    @State private var protein = 130.0
    @State private var sleep = 8.0
    @State private var goal = TrainingGoal.strengthAndMuscle
    @State private var minutes = 45
    @State private var equipment: Set<GymEquipment> = [.bodyweight]
    @State private var initialFuel = true
    @State private var initialSleep = true
    @State private var restore = false
    @State private var hydrated = false
    @State private var savedMeasurement = false
    @FocusState private var focused: Bool
    private let titles = ["", "Identity", "Body", "Your direction", "Daily fuel", "Recovery", "Your training", "Daily rhythm", "Your system is ready"]
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack { Text("ASCEND").font(.headline).tracking(5); Spacer(); Text(step <= 7 ? "\(step) / 7" : "READY").font(.caption).foregroundStyle(AppColor.muted) }
                    LinearProgress(progress: Double(min(step, 7)) / 7, tint: AppColor.blue, height: 3)
                    FeatureHeader(eyebrow: "PERSONAL SETUP", title: titles[step])
                    PremiumCard(role: .hero, tint: AppColor.blue) { VStack(alignment: .leading, spacing: 20) { fields } }
                    if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(SemanticStatus.watch.tint) }
                    PrimaryAction(title: step == 8 ? "ENTER ASCEND" : "Continue", symbol: step == 8 ? "checkmark" : "arrow.right", tint: AppColor.blue) {
                        focused = false
                        guard validStep else { store.errorMessage = "Check the values on this step before continuing."; return }
                        store.errorMessage = nil
                        if step == 8 { complete() } else { withAnimation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.reveal) { step += 1 } }
                    }.accessibilityIdentifier("onboarding.continue")
                    HStack {
                        if step > 1 { Button("Back") { focused = false; step -= 1 }.frame(minHeight: 44) }
                        Spacer()
                        if step == 1 { Button("Restore existing backup") { restore = true }.font(.caption).frame(minHeight: 44) }
                    }
                    Text("Private. Local. Yours.").font(.caption2).foregroundStyle(AppColor.muted)
                }.padding(24)
            }.featureBackground(tint: AppColor.blue).accessibilityIdentifier("screen.onboarding")
                .onAppear {
                    guard !hydrated else { return }; hydrated = true
                    name = store.profile.displayName == "Athlete" ? "" : store.profile.displayName
                    weight = store.progress.actualWeight; target = store.profile.targetWeightKG
                    calories = store.profile.calorieGoal; protein = store.profile.proteinGoal; sleep = store.profile.sleepTargetHours
                    height = store.ownerSystem.heightCM ?? 175; goal = store.training.profile.goal; minutes = store.training.profile.sessionMinutes; equipment = store.training.profile.equipment
                }
                .toolbar { if focused { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { focused = false } } } }
                .sheet(isPresented: $restore) { NavigationStack { DataVaultView().environment(store).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { restore = false } } } } }
        }
    }
    @ViewBuilder private var fields: some View {
        switch step {
        case 1:
            Text("Build a system around your recorded training.").font(.subheadline).foregroundStyle(AppColor.muted)
            TextField("Display name", text: $name).focused($focused).textContentType(.nickname).padding(14).background(AppColor.background, in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("onboarding.name")
            NumericField(title: "Height · cm", value: $height).focused($focused)
        case 2:
            OptionalNumericField(title: "Current weight · kg", value: $weight).focused($focused)
            OptionalNumericField(title: "Target weight · kg", value: $target).focused($focused)
            Text("Optional. A target enables your weight trend; it does not change training measurements.").font(.caption).foregroundStyle(AppColor.muted)
            DisclosureGroup("Optional circumferences") {
                VStack(spacing: 16) { OptionalNumericField(title: "Chest · cm", value: $chest); OptionalNumericField(title: "Waist · cm", value: $waist); OptionalNumericField(title: "Hips · cm", value: $hips); OptionalNumericField(title: "Biceps · cm", value: $biceps); OptionalNumericField(title: "Thigh · cm", value: $thigh) }.padding(.top, 16).focused($focused)
            }
        case 3:
            Picker("Training goal", selection: $goal) { Text("Strength & muscle").tag(TrainingGoal.strengthAndMuscle); Text("Strength").tag(TrainingGoal.strength); Text("General fitness / maintain").tag(TrainingGoal.generalFitness) }.pickerStyle(.inline)
            Text("ASCEND uses the same deterministic recovery and progression rules, with your goal as personal context.").font(.caption).foregroundStyle(AppColor.muted)
        case 4:
            NumericField(title: "Daily energy · kcal", value: $calories).focused($focused); NumericField(title: "Protein · g", value: $protein).focused($focused)
            Text("Editable starting values, not a medical prescription. Choose your own daily targets.").font(.caption).foregroundStyle(AppColor.muted)
        case 5:
            NumericField(title: "Sleep target · hours", value: $sleep).focused($focused)
            Text("Sleep Mode records an interval you start and end. It never detects sleep stages.").font(.caption).foregroundStyle(AppColor.muted)
        case 6:
            Stepper("Session · \(minutes) min", value: $minutes, in: 15...180, step: 5)
            Text("Only select equipment you can use.").font(.caption).foregroundStyle(AppColor.muted)
            ForEach(GymEquipment.allCases) { item in
                Toggle(item.title, isOn: Binding(get: { equipment.contains(item) }, set: { selected in if selected { equipment.insert(item) } else { equipment.remove(item) } })).disabled(item == .bodyweight)
            }
        case 7:
            Text("Start with a simple daily rhythm. Add exercise and habit objectives later.").font(.subheadline).foregroundStyle(AppColor.muted)
            Toggle("Daily calorie & protein objectives", isOn: $initialFuel)
            Toggle("Daily recorded sleep objective", isOn: $initialSleep)
        default:
            Text("YOUR ASCEND SYSTEM IS READY").font(.headline)
            Text("\(name) · \(minutes) min sessions\n\(Int(calories)) kcal · \(Int(protein)) g protein\n\(sleep.formatted()) h recorded sleep target").font(.subheadline).foregroundStyle(AppColor.muted)
        }
    }
    private var validStep: Bool {
        switch step {
        case 1: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 40 && (80...250).contains(height)
        case 2: (weight.map { (20...400).contains($0) } ?? true) && (target.map { (20...400).contains($0) } ?? true) && BodyMeasurement(date: store.actionDate(), chest: chest, waist: waist, hips: hips, biceps: biceps, thigh: thigh).isValid
        case 4: (500...10000).contains(calories) && (10...600).contains(protein)
        case 5: (1...16).contains(sleep)
        default: true
        }
    }
    private func complete() {
        var draft = ProfileDraft(store: store); draft.name = name; draft.currentWeight = weight; draft.targetWeight = target; draft.calories = calories; draft.protein = protein; draft.sleepHours = sleep
        guard store.saveProfile(draft), store.editTraining({ $0.profile.goal = goal; $0.profile.equipment = equipment; $0.profile.sessionMinutes = minutes }) else { return }
        let hasMeasures = [chest, waist, hips, biceps, thigh].contains { $0 != nil }
        if hasMeasures && !savedMeasurement {
            guard store.addMeasurement(.init(date: store.actionDate(), chest: chest, waist: waist, hips: hips, biceps: biceps, thigh: thigh)) else { return }
            savedMeasurement = true
        }
        for kind in (initialFuel ? [ObjectiveKind.calories, .protein] : []) + (initialSleep ? [.sleep] : []) {
            if store.objectives.contains(where: { $0.kind == kind && $0.isActive }) { continue }
            var objective = ObjectiveDraft(); objective.kind = kind; objective.startsAt = store.actionDate()
            objective.title = kind == .sleep ? "Recorded sleep" : kind == .calories ? "Daily energy" : "Daily protein"
            objective.target = kind == .sleep ? sleep : kind == .calories ? calories : protein; objective.unit = kind == .sleep ? "hours" : kind == .calories ? "kcal" : "g"
            guard store.saveObjective(objective) else { return }
        }
        _ = store.saveOwnerSystem { $0.heightCM = height; $0.onboardingComplete = true }
    }
}
