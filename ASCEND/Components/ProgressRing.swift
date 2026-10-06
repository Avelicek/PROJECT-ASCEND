import SwiftUI

struct ProgressRing: View {
    let progress: Double
    var tint: Color = AppColor.accent
    var lineWidth: CGFloat = 8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.12), lineWidth: lineWidth)
            Circle().trim(from: 0, to: FitnessMath.clamp(progress, 0...1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }.animation(reduceMotion ? nil : AppAnimation.reveal, value: progress)
            .accessibilityLabel("Progress").accessibilityValue("\(Int(FitnessMath.clamp(progress, 0...1) * 100)) percent")
    }
}
struct LinearProgress: View {
    let progress: Double
    var tint: Color = AppColor.accent
    var height: CGFloat = 5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            Capsule().fill(tint.opacity(0.12))
                .overlay(alignment: .leading) {
                    Capsule().fill(tint).frame(width: geometry.size.width * FitnessMath.clamp(progress, 0...1))
                }
        }.frame(height: height).animation(reduceMotion ? nil : AppAnimation.reveal, value: progress).accessibilityHidden(true)
    }
}
