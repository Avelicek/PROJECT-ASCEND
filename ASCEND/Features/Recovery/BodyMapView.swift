import SwiftUI

struct BodyMapView: View {
    @Environment(AppStore.self) private var store
    let report: ReadinessReport
    @State private var presentation = AnatomyPresentation()
    @State private var metric = AnatomyMetricMode.recovery
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var states: [RegionVisualization] { BodyRegion.allCases.map { $0.visualization(in: report) } }
    private var selection: RegionVisualization { presentation.selected.visualization(in: report) }
    var body: some View {
        PremiumCard(accented: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Eyebrow(text: "BODY MAP"); Spacer(); PillStatus(title: "ESTIMATED", tint: AppColor.muted) }
                HStack(spacing: 4) {
                    ForEach(AnatomyMetricMode.allCases) { mode in
                        Button { change { metric = mode } } label: {
                            Text(mode.rawValue).font(.caption.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(metric == mode ? AppColor.recovery : AppColor.muted)
                                .background(metric == mode ? AppColor.recovery.opacity(0.10) : .clear, in: Capsule())
                        }.buttonStyle(.plain).accessibilityIdentifier("body.metric.\(mode.id)")
                            .accessibilityValue(metric == mode ? "Selected" : "")
                    }
                }.accessibilityElement(children: .contain)
                HStack(spacing: 4) {
                    ForEach(BodyViewMode.allCases) { mode in
                        Button { change { presentation.show(mode) } } label: {
                            Text(mode.rawValue).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                                .background(presentation.mode == mode ? AppColor.blue.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(presentation.mode == mode ? AppColor.blue.opacity(0.4) : .clear))
                        }.buttonStyle(.plain).accessibilityIdentifier("body.view.\(mode.id)")
                            .accessibilityValue(presentation.mode == mode ? "Selected" : "")
                            .accessibilityAddTraits(presentation.mode == mode ? .isSelected : [])
                    }
                }.padding(4).background(AppColor.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityElement(children: .contain)
                AnatomyCanvas(mode: presentation.mode, selected: presentation.selected, regions: states, metric: metric) { region in
                    change { presentation.select(region) }
                }.frame(height: 320).id(presentation.mode).transition(.opacity)
                regionControls
                selectionPanel
                if metric == .recovery { HStack(spacing: 10) {
                    ForEach([RegionPhase.recovering, .rebuilding, .ready, .unknown], id: \.rawValue) { phase in
                        HStack(spacing: 4) { Circle().fill(phase.tint).frame(width: 5, height: 5); Text(phase.rawValue).font(.caption2).foregroundStyle(AppColor.muted) }
                    }
                }.frame(maxWidth: .infinity, alignment: .center) }
                else { Text(metric == .load ? "Load intensity relative to logged regions" : "Remaining modeled fatigue · warmer means higher").font(.caption2).foregroundStyle(AppColor.muted) }
            }
        }.accessibilityIdentifier("recovery.bodymap")
    }
    private var regionControls: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 6)], spacing: 7) {
            ForEach(states) { state in
                Button { change { presentation.select(state.region) } } label: {
                    HStack(spacing: 5) {
                        Circle().fill(metric.tint(state, maximumLoad: states.compactMap(\.load).max() ?? 1)).frame(width: 4, height: 4)
                        Text(state.region.rawValue).font(.caption.weight(.medium))
                    }.frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(presentation.selected == state.region ? AppColor.text : AppColor.muted)
                        .background(presentation.selected == state.region ? AppColor.recovery.opacity(0.15) : AppColor.elevated.opacity(0.35), in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(presentation.selected == state.region ? AppColor.recovery.opacity(0.35) : .clear))
                }.buttonStyle(.plain).accessibilityIdentifier("body.region.\(state.id)")
                    .accessibilityValue(presentation.selected == state.region ? "Selected" : "")
                    .accessibilityHint(state.accessibilitySummary)
            }
        }
    }
    private var selectionPanel: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(selection.region.rawValue).font(.title2.weight(.semibold))
                    Text(metric == .recovery ? selection.phase.rawValue : metric == .load ? "Recent training" : "Remaining fatigue").font(.caption.weight(.medium)).foregroundStyle(AppColor.recovery)
                }
                Spacer()
                if let percent = metric.value(selection) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        CountUpText(value: percent).font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit().foregroundStyle(metric.tint(selection, maximumLoad: states.compactMap(\.load).max() ?? 1))
                        Text(metric == .recovery ? "%" : metric.rawValue.uppercased()).font(.caption2).foregroundStyle(AppColor.muted)
                    }
                } else { Text("—").font(.largeTitle).foregroundStyle(AppColor.muted) }
            }
            LinearProgress(progress: (metric.value(selection) ?? 0) / (metric == .load ? max(1, states.compactMap(\.load).max() ?? 1) : 100), tint: metric.tint(selection, maximumLoad: states.compactMap(\.load).max() ?? 1), height: 5)
            if let load = selection.load, let fatigue = selection.fatigue {
                HStack {
                    StatBlock(title: "Recent load", value: load.formatted(.number.precision(.fractionLength(0))), tint: AppColor.strength)
                    StatBlock(title: "Fatigue", value: fatigue.formatted(.number.precision(.fractionLength(0))), tint: AppColor.warning)
                }
                HStack {
                    Text("\(selection.loggedMuscles)/\(selection.totalMuscles) muscles logged").font(.caption2).foregroundStyle(AppColor.muted)
                    Spacer()
                    PillStatus(title: "\((selection.confidence?.rawValue ?? "low").uppercased()) CONFIDENCE", tint: AppColor.muted)
                }
                if let limiting = selection.limitingMuscle { Text("Limiting · \(limiting)").font(.caption2).foregroundStyle(AppColor.muted) }
                HStack {
                    StatBlock(title: "Last trained", value: selection.lastTrainedAt.map { elapsed($0) } ?? "—")
                    StatBlock(title: "Est. ready", value: readyEstimate, tint: AppColor.blue)
                }
                ContextExplanationView(focus: "Recovery explained", facts: [recoveryExplanation], confidence: selection.confidence ?? .low)
            } else {
                Text("Log training to reveal recovery, load and fatigue.").font(.caption).foregroundStyle(AppColor.muted)
            }
        }.padding(16).background(AppColor.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selection.phase.tint.opacity(0.18)))
            .accessibilityIdentifier("body.selection").accessibilityElement(children: .contain)
    }
    private func change(_ update: () -> Void) {
        AppHaptics.selection(enabled: store.settings.hapticsEnabled)
        withAnimation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.interaction, update)
    }
    private func elapsed(_ date: Date) -> String {
        let hours = max(0, Int(store.now.timeIntervalSince(date) / 3600))
        return hours < 1 ? "Under 1h ago" : hours < 48 ? "\(hours)h ago" : "\(hours / 24)d ago"
    }
    private var readyEstimate: String {
        guard let ready = selection.estimatedReadyAt else { return "Unlogged" }
        if ready <= store.now { return "Model ready" }
        guard selection.confidence != .low else { return "Low confidence" }
        let day = store.policy.sameDay(ready, store.now) ? "Today" : store.policy.sameDay(ready, store.policy.adding(days: 1, to: store.now)) ? "Tomorrow" : ready.formatted(.dateTime.weekday(.abbreviated))
        let hour = store.policy.calendar.component(.hour, from: ready)
        let phase = hour < 6 ? "overnight" : hour < 12 ? "morning" : hour < 18 ? "afternoon" : "evening"
        return "\(day) \(phase)"
    }
    private var recoveryExplanation: String {
        if selection.confidence == .low { return "Training load is estimated from completed working sets and effort. Recovery inputs or training history are limited; avoid treating this estimate as a precise deadline." }
        return selection.phase == .ready ? "Logged load has decayed below the model's readiness threshold. Sleep, fuel and training history support this estimate; use your own condition before training." : "Recent working sets and effort still contribute fatigue. Logged sleep, sleep quality and fuel adjust its estimated decay; the ready window is approximate."
    }
}
