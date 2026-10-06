import SwiftUI

struct ProgressRing: View {
    let progress: Double
    var tint: Color = AppColor.accent
    var lineWidth: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.12), lineWidth: lineWidth)
            Circle().trim(from: 0, to: appeared || reduceMotion || AppMotion.snapshotMode ? FitnessMath.clamp(progress, 0...1) : 0)
                .stroke(LinearGradient(colors: [tint.opacity(0.65), tint], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }.onAppear { appeared = true }
            .animation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.reveal, value: appeared)
            .animation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.reveal, value: progress)
            .accessibilityLabel("Progress").accessibilityValue("\(Int(FitnessMath.clamp(progress, 0...1) * 100)) percent")
    }
}
struct LinearProgress: View {
    let progress: Double
    var tint: Color = AppColor.accent
    var height: CGFloat = 5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(tint.opacity(0.12))
                .overlay(alignment: .leading) {
                    Capsule().fill(LinearGradient(colors: [tint.opacity(0.6), tint], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * (appeared || reduceMotion || AppMotion.snapshotMode ? FitnessMath.clamp(progress, 0...1) : 0))
                }
        }.frame(height: height).onAppear { appeared = true }
            .animation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.reveal, value: appeared)
            .animation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.reveal, value: progress).accessibilityHidden(true)
    }
}
