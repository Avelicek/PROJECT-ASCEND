import SwiftUI

struct ObjectiveRow: View {
    let occurrence: DailyObjectiveCompletion
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                ZStack {
                    Circle().fill(tint.opacity(0.10))
                    ProgressRing(progress: complete ? 1 : occurrence.value / max(1, occurrence.target), tint: tint, lineWidth: 2).padding(2)
                    Image(systemName: occurrence.recoveryExempt ? "leaf" : occurrence.completedAt != nil ? "checkmark" : symbol)
                        .font(.system(.caption, weight: .medium)).foregroundStyle(tint)
                }.frame(width: 36, height: 36).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(occurrence.title).font(.system(.subheadline, weight: .medium)).foregroundStyle(AppColor.text)
                    HStack(spacing: 8) {
                        Text(occurrence.recoveryExempt ? "Protected · paused, not completed" : "\(occurrence.value.formatted(.number.precision(.fractionLength(0...1)))) / \(occurrence.target.formatted(.number.precision(.fractionLength(0...1)))) \(occurrence.unit)")
                    }.font(.caption2).foregroundStyle(AppColor.muted)
                    if occurrence.completedAt == nil && !occurrence.recoveryExempt {
                        LinearProgress(progress: occurrence.value / max(1, occurrence.target), tint: tint, height: 3)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if complete {
                    Image(systemName: occurrence.recoveryExempt ? "leaf.fill" : "checkmark").font(.caption.weight(.semibold)).foregroundStyle(tint)
                } else {
                    Text("\(Int(min(1, max(0, occurrence.value / max(1, occurrence.target))) * 100))%")
                        .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(tint)
                }
            }.padding(AppSpacing.md).background(AppColor.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(tint.opacity(0.15)) }
        }.completionMotion(complete).buttonStyle(PremiumPressStyle()).accessibilityElement(children: .combine)
            .accessibilityHint(occurrence.kindRaw == "custom" ? "Toggle completion" : "Open the corresponding log")
    }
    private var complete: Bool { occurrence.completedAt != nil }
    private var tint: Color { occurrence.recoveryExempt ? AppColor.muted : SemanticStatus.dailyCompletion(occurrence.value / max(1, occurrence.target)).tint }
    private var symbol: String {
        switch ObjectiveKind(rawValue: occurrence.kindRaw) {
        case .calories: "flame"
        case .protein: "fork.knife"
        case .bodyWeight: "scalemass"
        case .workout, .exercise: "dumbbell"
        default: "scope"
        }
    }
}
