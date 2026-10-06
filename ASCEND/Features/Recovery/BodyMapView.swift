import SwiftUI

enum BodyRegion: String, CaseIterable, Identifiable, Sendable {
    case chest = "Chest", shoulders = "Shoulders", arms = "Arms", back = "Back"
    case core = "Core", glutes = "Glutes", legs = "Legs", calves = "Calves"
    var id: String { rawValue.lowercased() }
    func recovery(in report: ReadinessReport) -> Double? {
        report.muscles.filter { $0.muscle.group == rawValue && $0.lastTrainedAt != nil }.map(\.recoveryPercent).min()
    }
    func tint(in report: ReadinessReport) -> Color {
        guard let value = recovery(in: report) else { return AppColor.muted.opacity(0.25) }
        return value < 50 ? AppColor.warning : value < 85 ? AppColor.blue : AppColor.positive
    }
}

struct BodyMapView: View {
    let report: ReadinessReport
    @State private var selected = BodyRegion.chest
    @State private var back = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Eyebrow(text: "RECOVERY MAP"); Spacer(); PillStatus(title: "ESTIMATE", tint: AppColor.muted) }
                Picker("Body view", selection: $back) {
                    Text("Front").tag(false); Text("Back").tag(true)
                }.pickerStyle(.segmented).accessibilityIdentifier("body.view")
                HStack(spacing: 14) {
                    ZStack {
                        Ellipse().fill(RadialGradient(colors: [AppColor.blue.opacity(0.12), .clear], center: .center, startRadius: 1, endRadius: 140))
                        BodySilhouette().fill(AppColor.elevated)
                        BodySilhouette().stroke(AppColor.muted.opacity(0.35), lineWidth: 1)
                        ForEach(BodyRegion.allCases) { region in
                            MusclePatch(region: region, back: back).fill(region.tint(in: report).opacity(selected == region ? 0.85 : 0.4))
                            if selected == region {
                                MusclePatch(region: region, back: back).stroke(region.tint(in: report), lineWidth: 1.5)
                            }
                        }
                    }.frame(width: 150, height: 290).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 12) {
                        Text(selected.rawValue).font(.title3.weight(.semibold))
                        if let percent = selected.recovery(in: report) {
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                CountUpText(value: percent).font(.system(.largeTitle, design: .rounded, weight: .semibold))
                                Text("%").font(.caption).foregroundStyle(AppColor.muted)
                            }
                            LinearProgress(progress: percent / 100, tint: selected.tint(in: report))
                            Text(percent < 50 ? "Recovering" : percent < 85 ? "Rebuilding" : "Ready")
                                .font(.caption).foregroundStyle(selected.tint(in: report))
                        } else {
                            Text("—").font(.largeTitle)
                            Text("No load logged").font(.caption).foregroundStyle(AppColor.muted)
                        }
                        Text("\(report.confidence.rawValue.capitalized) confidence").font(.caption2).foregroundStyle(AppColor.muted)
                        Text("Lowest logged muscle\nin this region").font(.caption2).foregroundStyle(AppColor.muted)
                    }.frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("body.selection")
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], spacing: 7) {
                    ForEach(BodyRegion.allCases) { region in
                        Button {
                            withAnimation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.interaction) {
                                selected = region
                                if region == .back || region == .glutes { back = true }
                                if region == .chest || region == .core { back = false }
                            }
                        } label: {
                            Text(region.rawValue).font(.caption.weight(.medium)).frame(maxWidth: .infinity, minHeight: 44)
                                .background(selected == region ? AppColor.blue.opacity(0.13) : AppColor.elevated.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected == region ? AppColor.blue.opacity(0.55) : .clear))
                        }.buttonStyle(.plain).accessibilityIdentifier("body.region.\(region.id)")
                            .accessibilityValue(selected == region ? "Selected" : "")
                            .accessibilityHint(region.recovery(in: report).map { "\(Int($0)) percent estimated recovery" } ?? "No training load logged")
                    }
                }
                HStack(spacing: 12) {
                    legend("Recovering", AppColor.warning); legend("Ready", AppColor.positive); legend("Unknown", AppColor.muted)
                }
            }
        }.accessibilityIdentifier("recovery.bodymap")
            .onChange(of: back) { _, showingBack in
                if showingBack && (selected == .chest || selected == .core) { selected = .back }
                if !showingBack && (selected == .back || selected == .glutes) { selected = .chest }
            }
    }
    private func legend(_ label: String, _ tint: Color) -> some View {
        HStack(spacing: 4) { Circle().fill(tint).frame(width: 5, height: 5); Text(label).font(.system(size: 9)).foregroundStyle(AppColor.muted) }
    }
}

// Stylized, symmetric vector diagram. Coordinates are normalized to a 200 × 400 canvas.
private struct BodySilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: rect.width * 0.41, y: rect.height * 0.02, width: rect.width * 0.18, height: rect.height * 0.1))
        let points: [[Double]] = [[88,48],[88,57],[61,67],[48,88],[42,129],[29,183],[31,204],[40,209],[50,193],[63,153],[67,124],[73,178],[68,205],[70,254],[78,295],[77,340],[72,376],[68,388],[91,388],[95,373],[96,332],[98,291],[100,236],[102,291],[104,332],[105,373],[109,388],[132,388],[128,376],[123,340],[122,295],[130,254],[132,205],[127,178],[133,124],[137,153],[150,193],[160,209],[169,204],[171,183],[158,129],[152,88],[139,67],[112,57],[112,48]]
        path.addLines(points.map { CGPoint(x: rect.width * CGFloat($0[0]) / 200, y: rect.height * CGFloat($0[1]) / 400) })
        path.closeSubpath()
        return path
    }
}

private struct MusclePatch: Shape {
    let region: BodyRegion
    let back: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for polygon in polygons {
            path.addLines(polygon.map { CGPoint(x: rect.width * CGFloat($0[0]) / 200, y: rect.height * CGFloat($0[1]) / 400) })
            path.closeSubpath()
            // Mirror the left patch onto the right side.
            path.addLines(polygon.map { CGPoint(x: rect.width * CGFloat(200 - $0[0]) / 200, y: rect.height * CGFloat($0[1]) / 400) })
            path.closeSubpath()
        }
        return path
    }
    private var polygons: [[[Double]]] {
        switch region {
        case .chest: return back ? [] : [[[72,79],[97,77],[97,108],[76,117],[68,106]]]
        case .shoulders: return [[[61,74],[70,76],[66,104],[53,110],[52,91]]]
        case .arms: return [[[52,116],[63,113],[60,151],[47,163],[44,153]], [[44,164],[52,159],[43,189],[35,195],[34,183]]]
        case .back: return back ? [[[73,73],[97,64],[97,117],[77,148],[69,110]], [[78,151],[97,126],[97,181],[79,179]]] : []
        case .core: return back ? [] : [[[78,123],[97,116],[97,177],[82,179],[76,153]]]
        case .glutes: return back ? [[[78,186],[97,185],[97,219],[75,227],[73,207]]] : []
        case .legs: return [[[75,230],[96,230],[94,275],[87,291],[79,280],[74,253]]]
        case .calves: return [[[81,305],[93,304],[92,342],[87,366],[80,342]]]
        }
    }
}
