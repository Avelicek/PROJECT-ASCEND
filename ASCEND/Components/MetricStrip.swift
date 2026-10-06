import SwiftUI

struct GlanceMetric: Identifiable {
    let title: String
    let value: String
    let symbol: String
    var tint: Color = AppColor.blue
    var id: String { title }
}

struct MetricStrip: View {
    let metrics: [GlanceMetric]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(metrics) { metric in
                VStack(alignment: .leading, spacing: 9) {
                    Image(systemName: metric.symbol).font(.caption).foregroundStyle(metric.tint).accessibilityHidden(true)
                    Text(metric.value).font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(metric.title).font(.caption2).foregroundStyle(AppColor.muted)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(AppColor.elevated.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: .top) { Rectangle().fill(metric.tint.opacity(0.4)).frame(height: 1).padding(.horizontal, 12) }
                    .accessibilityElement(children: .combine)
            }
        }
    }
}
