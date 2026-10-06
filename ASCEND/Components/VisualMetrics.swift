import SwiftUI

struct CountUpText: View {
    let value: Double
    var fractionDigits = 0
    var signed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed: Double?
    var body: some View {
        Text(formatted(displayed ?? (reduceMotion || AppMotion.snapshotMode ? value : 0)))
            .monospacedDigit()
            .accessibilityLabel(formatted(value))
            .task(id: value) {
                guard !reduceMotion && !AppMotion.snapshotMode else { displayed = value; return }
                let start = displayed ?? 0
                for step in 1...20 {
                    do { try await Task.sleep(for: .milliseconds(22)) } catch { return }
                    let fraction = Double(step) / 20
                    displayed = start + (value - start) * (1 - pow(1 - fraction, 3))
                }
                displayed = value
            }
    }
    private func formatted(_ number: Double) -> String {
        if signed { return number.formatted(.number.precision(.fractionLength(fractionDigits)).sign(strategy: .always)) }
        return number.formatted(.number.precision(.fractionLength(fractionDigits)))
    }
}

struct StatBlock: View {
    let title: String
    let value: String
    var symbol: String? = nil
    var tint: Color = AppColor.text
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).foregroundStyle(tint).accessibilityHidden(true) }
                Text(title.uppercased())
            }.font(.caption2.weight(.medium)).foregroundStyle(AppColor.muted)
            Text(value).font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
                .foregroundStyle(AppColor.text).lineLimit(1).minimumScaleFactor(0.7)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }
}

struct Sparkline: Shape {
    var values: [Double]
    func path(in rect: CGRect) -> Path {
        let finite = values.filter(\.isFinite)
        guard finite.count > 1, let minimum = finite.min(), let maximum = finite.max() else { return Path() }
        let range = max(maximum - minimum, 0.1)
        var path = Path()
        for (index, value) in finite.enumerated() {
            let point = CGPoint(x: rect.minX + rect.width * CGFloat(index) / CGFloat(finite.count - 1),
                y: rect.maxY - rect.height * CGFloat(maximum == minimum ? 0.5 : (value - minimum) / range))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }
}

struct TrendGraphic: View {
    let values: [Double]
    var tint: Color = AppColor.blue
    var body: some View {
        ZStack {
            VStack { ForEach(0..<3, id: \.self) { _ in Rectangle().fill(AppColor.separator).frame(height: 1); Spacer(minLength: 0) } }
            if values.count > 1 {
                Sparkline(values: values).stroke(tint.opacity(0.10), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                Sparkline(values: values).stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            } else {
                Rectangle().fill(AppColor.muted.opacity(0.35)).frame(height: 1)
            }
        }.frame(height: 35).accessibilityHidden(true)
    }
}

struct ReadinessGauge: View {
    let percent: Double?
    var size: CGFloat = 80
    var tint: Color = AppColor.blue
    var body: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { index in
                Capsule().fill(tint.opacity(index % 6 == 0 ? 0.40 : 0.16)).frame(width: 2, height: index % 6 == 0 ? 6 : 3)
                    .offset(y: -size / 2).rotationEffect(.degrees(Double(index) * 15))
            }
            ProgressRing(progress: (percent ?? 0) / 100, tint: tint, lineWidth: 5).padding(6)
            VStack(spacing: 1) {
                if let percent { CountUpText(value: percent).font(.system(.title2, design: .rounded, weight: .semibold)) }
                else { Text("—").font(.title2) }
                Text("READY").font(.system(size: 8, weight: .semibold)).tracking(1).foregroundStyle(AppColor.muted)
            }
        }.frame(width: size, height: size).accessibilityElement(children: .ignore)
            .accessibilityLabel("Body readiness")
            .accessibilityValue(percent.map { "\(Int($0.rounded())) percent" } ?? "Unknown, log training or sleep")
    }
}

struct MomentumCard: View {
    let report: ProgressReport
    var days = 7
    private var tint: Color { (report.momentumPercent ?? 0) < 0 ? AppColor.warning : AppColor.positive }
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Eyebrow(text: "MOMENTUM"); Spacer(); Text("\(days)D").font(.caption2).foregroundStyle(AppColor.muted) }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    if let value = report.momentumPercent {
                        CountUpText(value: value, signed: true).font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    } else { Text("—").font(.largeTitle) }
                    Text("%").font(.subheadline).foregroundStyle(AppColor.muted)
                    Spacer(minLength: 0)
                    Image(systemName: (report.momentumPercent ?? 0) < 0 ? "arrow.down.right" : "arrow.up.right")
                        .font(.title3).foregroundStyle(tint).accessibilityHidden(true)
                }
                TrendGraphic(values: report.trend.suffix(14).map(\.kilograms), tint: tint)
                Text(report.momentumPercent.map { $0 < 0 ? "Away from goal" : $0 > 0 ? "Toward your goal" : "Holding steady" } ?? "Building your baseline")
                    .font(.caption).foregroundStyle(AppColor.muted)
            }
        }.accessibilityElement(children: .combine)
    }
}
