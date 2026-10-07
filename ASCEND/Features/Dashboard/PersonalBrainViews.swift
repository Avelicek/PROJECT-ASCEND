import SwiftUI

private extension BrainDecision {
    var status: SemanticStatus {
        switch action {
        case .train: intensity == .progressIfReady ? .excellent : .good
        case .trainLight: .watch
        case .recover: .low
        case .maintain: .good
        }
    }
    var shortReasons: [String] {
        (warnings + reasons).prefix(2).map {
            $0.replacingOccurrences(of: "Some muscle history is unknown. Establish a familiar, easy baseline.", with: "Some muscles are unknown. Start light.")
                .replacingOccurrences(of: "matches your equipment and current recorded recovery.", with: "fits your equipment and recovery logs.")
                .replacingOccurrences(of: "Lowest relevant muscle estimate:", with: "Lowest relevant estimate:")
                .replacingOccurrences(of: "Recent sleep duration or quality is low; reduce intensity.", with: "Recent sleep is low. Reduce intensity.")
        }
    }
    var shortStatus: String {
        switch action { case .train: "READY"; case .trainLight: "TRAIN LIGHT"; case .recover: "RECOVER"; case .maintain: "MAINTAIN" }
    }
}

struct BrainSignal: View {
    let confidence: Confidence
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path").foregroundStyle(AppColor.recovery).accessibilityHidden(true)
            Eyebrow(text: "ASCEND INTELLIGENCE")
            Spacer(minLength: 0)
            Text(confidence == .low ? "LEARNING" : "LOCAL").font(.caption2).foregroundStyle(AppColor.muted)
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
                    StatusPill(status: decision.status, title: decision.shortStatus)
                }
                Spacer(minLength: 6)
                Button("Why", systemImage: "arrow.up.right", action: showDetails).font(.caption).frame(minHeight: 44).accessibilityIdentifier("brain.detail")
            }
            if let session = decision.session {
                HStack { Text(session.name).font(.subheadline); Spacer(); Text("~\(decision.duration ?? 0) min").font(.caption).foregroundStyle(AppColor.muted) }
                PrimaryAction(title: store.activeWorkout == nil ? "Start \(decision.focus)" : "Resume workout", symbol: "play.fill", tint: decision.status.tint) { store.startBrainSession() }
                    .accessibilityIdentifier("brain.start")
            }
            HStack(spacing: 14) {
                ForEach(decision.muscles.prefix(3)) { muscle in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(muscle.name).font(.caption2).foregroundStyle(AppColor.muted)
                        Text(muscle.recovery.map { "\(Int($0.rounded()))%" } ?? "Unknown").font(.caption.weight(.medium)).foregroundStyle(SemanticStatus.recovery(muscle.recovery).tint)
                    }.accessibilityElement(children: .combine)
                }
                Spacer(minLength: 0)
            }
            Text("Why · " + decision.shortReasons.joined(separator: " "))
                .font(.caption).foregroundStyle(AppColor.secondary).fixedSize(horizontal: false, vertical: true)
            if decision.warnings.isEmpty, let opportunity = decision.opportunities.first(where: { $0.suggestion.target != nil }) {
                Text("\(opportunity.recordWindow ? "PR window" : "Optional progression") · \(opportunity.name)").font(.caption2).foregroundStyle(SemanticStatus.excellent.tint)
            }
            Text("\(decision.confidence.rawValue.capitalized) confidence · local estimates")
                .font(.caption2).foregroundStyle(AppColor.muted).accessibilityIdentifier("brain.confidence")
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.hero).fill(AppColor.surface)
                RoundedRectangle(cornerRadius: AppRadius.hero).fill(LinearGradient(colors: [AppColor.recovery.opacity(0.055), AppColor.background.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
            }.overlay(alignment: .top) {
                Capsule().fill(LinearGradient(colors: [.clear, AppColor.recovery.opacity(0.3), .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 1).padding(.horizontal, 30)
            }.shadow(color: AppColor.recovery.opacity(0.06), radius: 16).shadow(color: .black.opacity(0.3), radius: 22, y: 12).accessibilityElement(children: .contain).accessibilityIdentifier("brain.hero")
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
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                FeatureHeader(eyebrow: "TODAY", title: decision.focus)
                HStack { StatusPill(status: decision.status, title: decision.shortStatus); Spacer(); Text(decision.intensity.title).font(.caption).foregroundStyle(AppColor.muted) }
                why
                session
                recovery
                progression
                confidence
                DisclosureGroup("Training balance") { WeeklyTrainingBalance().padding(.top, 12) }.font(.subheadline)
                HStack {
                    Button("Not today") { store.respondToBrain(.rejected) }.accessibilityIdentifier("brain.reject")
                    Spacer()
                    Button("Dismiss advice") { store.respondToBrain(.ignored) }
                }.font(.caption).frame(minHeight: 44)
                DisclosureGroup("Recent recommendations") {
                    ForEach(store.brainArchive.history.suffix(7).reversed()) { entry in
                        HStack { Text(entry.date, style: .date); Text(entry.focus); Spacer(); Text(entry.response?.rawValue ?? "Shown") }.font(.caption2).padding(.vertical, 6)
                    }
                    Text("Explicit responses modestly adjust compatible routines.").font(.caption2).foregroundStyle(AppColor.muted)
                }.font(.caption)
            }.padding(AppSpacing.page)
        }.featureBackground(tint: AppColor.recovery).accessibilityIdentifier("screen.braindetail")
            .toolbar(.visible, for: .navigationBar)
            .navigationTitle("ASCEND Intelligence").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }; ToolbarItem(placement: .topBarLeading) { Button("Settings") { settings = true } } }
            .sheet(isPresented: $settings) { NavigationStack { BrainSettingsView().environment(store) }.preferredColorScheme(.dark) }
    }
    private var why: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "WHY")
            ForEach(Array(decision.shortReasons.enumerated()), id: \.offset) { _, reason in
                Text(reason).font(.subheadline).foregroundStyle(AppColor.secondary)
            }
            DisclosureGroup("More context") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array((decision.warnings + decision.reasons).dropFirst(2).enumerated()), id: \.offset) { _, reason in Text(reason).font(.caption) }
                    ContextExplanationView(focus: "Interpretation", facts: decision.facts, confidence: decision.confidence)
                }.padding(.top, 10)
            }.font(.caption).tint(AppColor.muted)
        }
    }
    @ViewBuilder private var session: some View {
        if let session = decision.session {
            PremiumCard(role: .glass) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "SESSION · " + (decision.routineID == nil ? "SUGGESTED" : "SAVED ROUTINE"))
                    HStack { Text(session.name).font(.headline).foregroundStyle(AppColor.text); Spacer(); Text("~\(decision.duration ?? 0) min").font(.caption).foregroundStyle(AppColor.muted) }
                    DisclosureGroup("\(session.exercises.count) exercises") {
                        ForEach(session.exercises) { item in
                            HStack { Text(store.trainingMetadata(item.exerciseID)?.name ?? item.exerciseID); Spacer(); Text("\(item.sets) sets").foregroundStyle(AppColor.muted) }.font(.caption).padding(.vertical, 5)
                        }
                    }.font(.subheadline)
                    PrimaryAction(title: store.activeWorkout == nil ? "Start session" : "Resume workout", symbol: "play.fill", tint: decision.status.tint) { startSession(); dismiss() }.accessibilityIdentifier("brain.detail.start")
                }
            }
        }
    }
    private var recovery: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(text: "RECOVERY · ESTIMATES")
            ForEach(decision.muscles.prefix(3)) { muscle in RecoveryStatusRow(name: muscle.name, percent: muscle.recovery) }
            DisclosureGroup("All muscles") {
                VStack(spacing: 14) { ForEach(decision.muscles.dropFirst(3)) { muscle in RecoveryStatusRow(name: muscle.name, percent: muscle.recovery) } }.padding(.top, 12)
            }.font(.caption)
            Text("Unknown = no relevant training logged. Recovery is estimated.").font(.caption2).foregroundStyle(AppColor.muted)
        }
    }
    @ViewBuilder private var progression: some View {
        if !decision.opportunities.isEmpty {
            DisclosureGroup("Progression · \(decision.opportunities.count) exercises") {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(decision.opportunities) { opportunity in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(opportunity.name).font(.subheadline.weight(.medium)).foregroundStyle(AppColor.text)
                            if let previous = opportunity.previous { Text("Last · \(performance(previous))").font(.caption).foregroundStyle(AppColor.muted) }
                            if let target = opportunity.suggestion.target { Text("Optional · \(performance(target))").font(.caption).foregroundStyle(SemanticStatus.excellent.tint) }
                            if opportunity.recordWindow { StatusPill(status: .excellent, title: "PR WINDOW · OPTIONAL") }
                            Text(opportunity.suggestion.explanation).font(.caption)
                            if opportunity.improved { Text("Progress observed.").font(.caption).foregroundStyle(AppColor.positive) }
                            if opportunity.plateau { Text("Watch · four comparable sessions without improvement. Consider a lighter load or another variation.").font(.caption).foregroundStyle(AppColor.warning) }
                        }
                    }
                }.padding(.top, 14)
            }.font(.subheadline)
        }
    }
    private var confidence: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Eyebrow(text: "DATA CONFIDENCE"); Spacer(); StatusPill(status: .confidence(decision.confidence), title: decision.confidence.rawValue.uppercased()) }
            if decision.confidence == .low { Text("Learning your baseline. Use familiar loads.").font(.caption).foregroundStyle(AppColor.secondary) }
            DisclosureGroup("Inputs & missing data") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("\(store.personalContext.sessionDates.count) full sessions · \(store.personalContext.nutritionDays) recent nutrition days").font(.caption)
                    if let sleep = store.personalContext.sleepHours { Text("Recent sleep · \(sleep.formatted()) h").font(.caption) }
                    Text("\(store.training.profile.resolvedEquipment.count) available equipment types").font(.caption)
                    ForEach(decision.missing, id: \.self) { Text("Missing · \($0)").font(.caption).foregroundStyle(AppColor.muted) }
                    Text("Local logs guide estimates. Your condition takes priority.").font(.caption2).foregroundStyle(AppColor.muted)
                }.padding(.top, 10)
            }.font(.caption)
        }
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
