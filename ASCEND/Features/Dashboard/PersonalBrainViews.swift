import SwiftUI

struct BrainSignal: View {
    let confidence: Confidence
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path").foregroundStyle(AppColor.recovery).accessibilityHidden(true)
            Eyebrow(text: "ASCEND INTELLIGENCE")
            Spacer(minLength: 0)
            Text(confidence == .low ? "LEARNING" : "READY").font(.caption2).foregroundStyle(AppColor.muted)
        }
    }
}

struct BrainHeroView: View {
    @Environment(AppStore.self) private var store
    let showDetails: () -> Void
    private var decision: BrainDecision { store.brainDecision }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BrainSignal(confidence: decision.confidence)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 5) {
                    Eyebrow(text: "TODAY")
                    Text(decision.focus.uppercased()).font(.system(.largeTitle, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppColor.text).accessibilityIdentifier("brain.focus")
                    Text(decision.action.title.uppercased()).font(.caption.weight(.medium)).tracking(1).foregroundStyle(AppColor.recovery)
                }
                Spacer(minLength: 6)
                Button("Why", systemImage: "arrow.up.right", action: showDetails).font(.caption).frame(minHeight: 44).accessibilityIdentifier("brain.detail")
            }
            if let session = decision.session {
                HStack { Text(session.name).font(.subheadline); Spacer(); Text("~\(decision.duration ?? 0) min · \(decision.intensity.title)").font(.caption).foregroundStyle(AppColor.muted) }
                PrimaryAction(title: store.activeWorkout == nil ? "Start \(decision.focus)" : "Resume workout", symbol: "play.fill", tint: AppColor.recovery) { store.startBrainSession() }
                    .accessibilityIdentifier("brain.start")
            }
            HStack(spacing: 14) {
                ForEach(decision.muscles.prefix(3)) { muscle in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(muscle.name).font(.caption2).foregroundStyle(AppColor.muted)
                        Text(muscle.recovery.map { "\(Int($0.rounded()))%" } ?? "Unknown").font(.caption.weight(.medium)).foregroundStyle(AppColor.secondary)
                    }.accessibilityElement(children: .combine)
                }
                Spacer(minLength: 0)
            }
            Text((decision.warnings + decision.reasons).prefix(2).joined(separator: " "))
                .font(.caption).foregroundStyle(AppColor.secondary).fixedSize(horizontal: false, vertical: true)
            if decision.warnings.isEmpty, let opportunity = decision.opportunities.first(where: { $0.suggestion.target != nil }) {
                Text("\(opportunity.recordWindow ? "PR window" : "Optional progression") · \(opportunity.name)").font(.caption2).foregroundStyle(AppColor.recovery)
            }
            Text("\(decision.confidence.rawValue.capitalized) confidence · estimates from local logs")
                .font(.caption2).foregroundStyle(AppColor.muted).accessibilityIdentifier("brain.confidence")
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.hero).fill(AppColor.surface)
                RoundedRectangle(cornerRadius: AppRadius.hero).fill(LinearGradient(colors: [AppColor.recovery.opacity(0.055), AppColor.background.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }.overlay(alignment: .top) {
                Capsule().fill(LinearGradient(colors: [.clear, AppColor.recovery.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 1).padding(.horizontal, 30)
            }.shadow(color: .black.opacity(0.3), radius: 22, y: 12).accessibilityElement(children: .contain).accessibilityIdentifier("brain.hero")
    }
}

struct BrainDetailView: View {
    var startSession: () -> Void = {}
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var settings = false
    private var decision: BrainDecision { store.brainDecision }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                FeatureHeader(eyebrow: "PERSONAL BRAIN · TODAY", title: decision.focus)
                HStack { Text(decision.action.title).foregroundStyle(AppColor.recovery); Spacer(); Text(decision.intensity.title).foregroundStyle(AppColor.muted) }.font(.subheadline)
                if let session = decision.session {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: decision.routineID == nil ? "SUGGESTED SESSION" : "SAVED ROUTINE")
                        ForEach(session.exercises) { item in
                            HStack { Text(store.trainingMetadata(item.exerciseID)?.name ?? item.exerciseID); Spacer(); Text("\(item.sets) sets").foregroundStyle(AppColor.muted) }.font(.subheadline)
                        }
                        PrimaryAction(title: "Start session", symbol: "play.fill", tint: AppColor.recovery) { startSession(); dismiss() }.accessibilityIdentifier("brain.detail.start")
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "WHY THIS DECISION")
                    ForEach(Array((decision.warnings + decision.reasons).enumerated()), id: \.offset) { _, reason in Text(reason).font(.subheadline).foregroundStyle(AppColor.secondary) }
                    ContextExplanationView(focus: "Interpretation", facts: decision.facts, confidence: decision.confidence)
                }
                PremiumCard(role: .glass) {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "RECOVERY · ESTIMATES")
                        ForEach(decision.muscles) { muscle in HStack { Text(muscle.name); Spacer(); Text(muscle.recovery.map { "\(Int($0.rounded()))%" } ?? "Unknown") }.font(.subheadline) }
                        Text("Unknown means no relevant training load was recorded. These are model estimates, never measured readiness.").font(.caption).foregroundStyle(AppColor.muted)
                    }
                }
                if !decision.opportunities.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Eyebrow(text: "PROGRESSION")
                        ForEach(decision.opportunities) { opportunity in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(opportunity.name).font(.subheadline.weight(.medium))
                                if let previous = opportunity.previous { Text("Last · \(performance(previous))").font(.caption).foregroundStyle(AppColor.muted) }
                                if let target = opportunity.suggestion.target { Text("Optional · \(performance(target))").font(.caption).foregroundStyle(AppColor.recovery) }
                                if opportunity.recordWindow { Text("PR window · optional target exceeds a recorded comparable best.").font(.caption2).foregroundStyle(AppColor.gold) }
                                Text(opportunity.suggestion.explanation).font(.caption).foregroundStyle(AppColor.secondary)
                                if opportunity.improved { Text("Progress observed at comparable load and effort.").font(.caption).foregroundStyle(AppColor.positive) }
                                if opportunity.plateau { Text("Plateau signal · four comparable exposures at the same load and best reps with high effort. Consider an easier load or another available variation.").font(.caption).foregroundStyle(AppColor.warning) }
                            }
                        }
                    }
                }
                WeeklyTrainingBalance()
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(text: "DATA CONFIDENCE · \(decision.confidence.rawValue.uppercased())")
                    Text("Known: \(store.personalContext.sessionDates.count) full sessions · \(store.personalContext.nutritionDays) recent closed nutrition days · \(store.training.profile.resolvedEquipment.count) available equipment types.").font(.caption)
                    if let sleep = store.personalContext.sleepHours { Text("Recent sleep · \(sleep.formatted()) h · \(store.personalContext.sleepConfidence.rawValue) input confidence").font(.caption) }
                    if let calories = store.personalContext.calories, let protein = store.personalContext.protein {
                        Text("Today · \(Int(calories.rounded())) / \(Int(store.personalContext.calorieGoal.rounded())) kcal · \(Int(protein.rounded())) / \(Int(store.personalContext.proteinGoal.rounded())) g protein").font(.caption)
                    }
                    Text("Goal · \(store.training.profile.goal.rawValue.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized)").font(.caption)
                    if let weight = store.personalContext.weight { Text("Body weight · \(weight.formatted()) kg" + (store.personalContext.targetWeight.map { " → \($0.formatted()) kg target" } ?? "")).font(.caption) }
                    ForEach(decision.missing, id: \.self) { Text("Missing · \($0)").font(.caption).foregroundStyle(AppColor.muted) }
                    if decision.confidence == .low { Text("Learning your baseline. Use familiar loads; another workout and supported sleep / nutrition logs improve guidance.").font(.caption).foregroundStyle(AppColor.secondary) }
                }
                HStack {
                    Button("Not today") { store.respondToBrain(.rejected) }.accessibilityIdentifier("brain.reject")
                    Spacer()
                    Button("Dismiss advice") { store.respondToBrain(.ignored) }
                }.font(.caption).frame(minHeight: 44)
                Text("Responses modestly rerank compatible routines. Dismiss is an explicit ignored signal; time passing never counts as acceptance.").font(.caption2).foregroundStyle(AppColor.muted)
                DisclosureGroup("Recent recommendations") {
                    ForEach(store.brainArchive.history.suffix(7).reversed()) { entry in
                        HStack { Text(entry.date, style: .date); Text(entry.focus); Spacer(); Text(entry.response?.rawValue ?? "Shown") }.font(.caption2).padding(.vertical, 6)
                    }
                }.font(.caption)
            }.padding(20)
        }.featureBackground(tint: AppColor.recovery).accessibilityIdentifier("screen.braindetail")
            .toolbar(.visible, for: .navigationBar)
            .navigationTitle("ASCEND Intelligence").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }; ToolbarItem(placement: .topBarLeading) { Button("Settings") { settings = true } } }
            .sheet(isPresented: $settings) { NavigationStack { BrainSettingsView().environment(store) }.preferredColorScheme(.dark) }
    }
    private func performance(_ value: SetPerformance) -> String { (value.kilograms > 0 ? value.kilograms.formatted() + " kg × " : "") + "\(value.reps) reps" }
}

struct BrainSettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FeatureHeader(eyebrow: "LOCAL INTELLIGENCE", title: "Personal Brain")
                Toggle("Personal Brain", isOn: setting(\.enabled)).accessibilityIdentifier("brain.settings.enabled")
                Text("Balanced · recovery first, modest progression, explicit preferences.").font(.caption).foregroundStyle(AppColor.muted)
                Picker("Session duration", selection: Binding(get: { store.brainArchive.settings.duration }, set: { duration in store.editBrainSettings { $0.duration = duration } })) {
                    ForEach(BrainDuration.allCases, id: \.rawValue) { Text($0.title).tag($0) }
                }.pickerStyle(.menu)
                Toggle("Use recent sleep", isOn: setting(\.useSleep)).accessibilityIdentifier("brain.settings.sleep")
                Toggle("Use recent nutrition", isOn: setting(\.useNutrition))
                Toggle("On-device interpretation", isOn: Binding(get: { store.settings.onDeviceAIEnabled }, set: { enabled in _ = store.perform { store.settings.onDeviceAIEnabled = enabled } }))
                Text("Optional Apple on-device interpretation explains fixed engine facts. Decisions, confidence, targets and ELO always come from local rules. If unavailable, the same facts remain visible.").font(.caption).foregroundStyle(AppColor.muted)
            }.padding(20)
        }.accessibilityIdentifier("screen.brainsettings").featureBackground().navigationTitle("Brain settings").navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
    private func setting(_ key: WritableKeyPath<BrainSettings, Bool>) -> Binding<Bool> { Binding(get: { store.brainArchive.settings[keyPath: key] }, set: { value in store.editBrainSettings { $0[keyPath: key] = value } }) }
}
