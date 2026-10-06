import SwiftUI

struct BodyMapView: View {
    let report: ReadinessReport
    @State private var presentation = AnatomyPresentation()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var states: [RegionVisualization] { BodyRegion.allCases.map { $0.visualization(in: report) } }
    private var selection: RegionVisualization { presentation.selected.visualization(in: report) }
    var body: some View {
        PremiumCard(accented: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack { Eyebrow(text: "ANATOMY LAB"); Spacer(); PillStatus(title: "ESTIMATED", tint: AppColor.muted) }
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
                    .accessibilityIdentifier("body.view")
                AnatomyCanvas(mode: presentation.mode, selected: presentation.selected, regions: states) { region in
                    change { presentation.select(region) }
                }.frame(height: 340).id(presentation.mode).transition(.opacity)
                regionControls
                selectionPanel
                HStack(spacing: 10) {
                    ForEach([RegionPhase.recovering, .rebuilding, .ready, .unknown], id: \.rawValue) { phase in
                        HStack(spacing: 4) { Circle().fill(phase.tint).frame(width: 5, height: 5); Text(phase.rawValue).font(.caption2).foregroundStyle(AppColor.muted) }
                    }
                }.frame(maxWidth: .infinity, alignment: .center)
            }
        }.accessibilityIdentifier("recovery.bodymap")
    }
    private var regionControls: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 6)], spacing: 7) {
            ForEach(states) { state in
                Button { change { presentation.select(state.region) } } label: {
                    HStack(spacing: 5) {
                        Circle().fill(state.phase.tint).frame(width: 4, height: 4)
                        Text(state.region.rawValue).font(.caption.weight(.medium))
                    }.frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(presentation.selected == state.region ? AppColor.text : AppColor.muted)
                        .background(presentation.selected == state.region ? state.phase.tint.opacity(0.15) : AppColor.elevated.opacity(0.6), in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(presentation.selected == state.region ? state.phase.tint.opacity(0.8) : .clear))
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
                    Text(selection.phase.rawValue).font(.caption.weight(.medium)).foregroundStyle(selection.phase.tint)
                }
                Spacer()
                if let percent = selection.percent {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        CountUpText(value: percent).font(.system(.largeTitle, design: .rounded, weight: .semibold)).monospacedDigit()
                        Text("%").font(.caption).foregroundStyle(AppColor.muted)
                    }
                } else { Text("—").font(.largeTitle).foregroundStyle(AppColor.muted) }
            }
            LinearProgress(progress: (selection.percent ?? 0) / 100, tint: selection.phase.tint, height: 5)
            if let load = selection.load, let fatigue = selection.fatigue {
                HStack {
                    StatBlock(title: "Load index", value: load.formatted(.number.precision(.fractionLength(1))), tint: AppColor.blue)
                    StatBlock(title: "Fatigue index", value: fatigue.formatted(.number.precision(.fractionLength(1))), tint: selection.phase.tint)
                }
                HStack {
                    Text("\(selection.loggedMuscles)/\(selection.totalMuscles) muscles logged").font(.caption2).foregroundStyle(AppColor.muted)
                    Spacer()
                    PillStatus(title: "\((selection.confidence?.rawValue ?? "low").uppercased()) CONFIDENCE", tint: AppColor.muted)
                }
                if let limiting = selection.limitingMuscle { Text("Limiting · \(limiting)").font(.caption2).foregroundStyle(AppColor.muted) }
            } else {
                Text("Log training to reveal recovery, load and fatigue.").font(.caption).foregroundStyle(AppColor.muted)
            }
        }.padding(16).background(AppColor.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(selection.phase.tint.opacity(0.18)))
            .accessibilityIdentifier("body.selection").accessibilityElement(children: .contain)
    }
    private func change(_ update: () -> Void) {
        withAnimation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.interaction, update)
    }
}
