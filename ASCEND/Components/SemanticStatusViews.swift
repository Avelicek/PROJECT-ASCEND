import SwiftUI

extension SemanticStatus {
    private static func color(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }
    var colors: [Color] {
        switch self {
        case .excellent: [Self.color(0xBB14F5), Self.color(0xFC67E6)]
        case .good: [Self.color(0x57F514), Self.color(0x75FC67)]
        case .watch: [Self.color(0xF58114), Self.color(0xFCA367)]
        case .low: [Self.color(0xF51414), Self.color(0xFC6767)]
        case .unknown: [AppColor.muted, AppColor.secondary]
        }
    }
    // The lighter endpoint keeps small text legible on graphite surfaces.
    var tint: Color { colors[1] }
    var gradient: LinearGradient { LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing) }
}

struct StatusPill: View {
    let status: SemanticStatus
    var title: String? = nil
    var body: some View { PillStatus(title: title ?? status.title.uppercased(), tint: status.tint) }
}

/// Shared by recovery and Brain. Unknown never produces a full recovery bar.
struct RecoveryStatusRow: View {
    let name: String
    let percent: Double?
    private var status: SemanticStatus { .recovery(percent) }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(name).font(.subheadline).foregroundStyle(AppColor.secondary)
                Spacer(minLength: 8)
                Text(percent.map { "\(Int($0.rounded()))% · \(status.title)" } ?? "Unknown")
                    .font(.caption).monospacedDigit().foregroundStyle(status.tint)
            }
            LinearProgress(progress: (percent ?? 0) / 100, tint: status.tint, gradient: status.gradient, height: 4)
        }.accessibilityElement(children: .combine)
    }
}

/// Load describes exposure, not readiness. High = attention; light = good.
struct MuscleLoadRow: View {
    let name: String
    let load: Double
    let maximum: Double
    private var status: SemanticStatus { load >= 5 ? .watch : .good }
    private var label: String { load >= 5 ? "HIGH" : load >= 2 ? "MEDIUM" : "LIGHT" }
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                Text(name).font(.caption).foregroundStyle(AppColor.secondary).frame(width: 76, alignment: .leading)
                LinearProgress(progress: load / max(1, maximum), tint: status.tint, gradient: status.gradient)
                Text(label).font(.caption2).foregroundStyle(status.tint).frame(width: 56, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text(name); Spacer(); Text(label).foregroundStyle(status.tint) }.font(.caption)
                LinearProgress(progress: load / max(1, maximum), tint: status.tint, gradient: status.gradient)
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel("\(name), \(label.lowercased()) training load")
    }
}
