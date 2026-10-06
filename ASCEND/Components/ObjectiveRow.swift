import SwiftUI

struct ObjectiveRow: View {
    let occurrence: DailyObjectiveCompletion
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                ZStack {
                    Circle().fill(complete ? AppColor.positive.opacity(0.12) : AppColor.elevated)
                    ProgressRing(progress: complete ? 1 : occurrence.value / max(1, occurrence.target), tint: complete ? AppColor.positive : AppColor.accent, lineWidth: 2).padding(2)
                    Image(systemName: occurrence.recoveryExempt ? "leaf" : occurrence.completedAt != nil ? "checkmark" : symbol)
                        .font(.system(.caption, weight: .medium)).foregroundStyle(complete ? AppColor.positive : AppColor.accent)
                }.frame(width: 36, height: 36).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(occurrence.replacementTitle ?? occurrence.title).font(.system(.subheadline, weight: .medium)).foregroundStyle(AppColor.text)
                    HStack(spacing: 8) {
                        Text(occurrence.recoveryExempt ? "Recovery protected" : "\(occurrence.value.formatted(.number.precision(.fractionLength(0...1)))) / \(occurrence.target.formatted(.number.precision(.fractionLength(0...1)))) \(occurrence.unit)")
                    }.font(.caption2).foregroundStyle(AppColor.muted)
                    if occurrence.completedAt == nil && !occurrence.recoveryExempt {
                        LinearProgress(progress: occurrence.value / max(1, occurrence.target), tint: AppColor.accent, height: 3)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if complete {
                    Image(systemName: occurrence.recoveryExempt ? "leaf.fill" : "checkmark").font(.caption.weight(.semibold)).foregroundStyle(AppColor.positive)
                } else {
                    Text("\(Int(min(1, max(0, occurrence.value / max(1, occurrence.target))) * 100))%")
                        .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(AppColor.accent)
                }
            }.padding(AppSpacing.md).background(AppColor.surface, in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(complete ? AppColor.positive.opacity(0.18) : AppColor.separator) }
        }.buttonStyle(PremiumPressStyle()).accessibilityElement(children: .combine)
            .accessibilityHint(occurrence.kindRaw == "custom" ? "Toggle completion" : "Open the corresponding log")
    }
    private var complete: Bool { occurrence.completedAt != nil || occurrence.recoveryExempt }
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
