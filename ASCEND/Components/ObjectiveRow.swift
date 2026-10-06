import SwiftUI

struct ObjectiveRow: View {
    let occurrence: DailyObjectiveCompletion
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(occurrence.completedAt != nil ? AppColor.positive.opacity(0.12) : AppColor.elevated)
                    Image(systemName: occurrence.recoveryExempt ? "leaf" : occurrence.completedAt != nil ? "checkmark" : symbol)
                        .font(.system(.body, weight: .medium)).foregroundStyle(occurrence.completedAt != nil ? AppColor.positive : AppColor.accent)
                }.frame(width: 46, height: 46).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(occurrence.replacementTitle ?? occurrence.title).font(.system(.subheadline, weight: .medium)).foregroundStyle(AppColor.text)
                    HStack(spacing: 8) {
                        Text(occurrence.recoveryExempt ? "Recovery protected" : "\(occurrence.value.formatted(.number.precision(.fractionLength(0...1)))) / \(occurrence.target.formatted(.number.precision(.fractionLength(0...1)))) \(occurrence.unit)")
                        Text("·")
                        Text(occurrence.importanceRaw.capitalized)
                    }.font(.caption2).foregroundStyle(AppColor.muted)
                    if occurrence.completedAt == nil && !occurrence.recoveryExempt {
                        LinearProgress(progress: occurrence.value / max(1, occurrence.target), tint: AppColor.accent, height: 3)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                if occurrence.completedAt != nil {
                    Text("DONE").font(.system(.caption2, weight: .semibold)).foregroundStyle(AppColor.positive)
                } else { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(AppColor.muted) }
            }.padding(AppSpacing.md).background(AppColor.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(AppColor.separator) }
        }.buttonStyle(PremiumPressStyle()).accessibilityElement(children: .combine)
            .accessibilityHint(occurrence.kindRaw == "custom" ? "Toggle completion" : "Open the corresponding log")
    }
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
