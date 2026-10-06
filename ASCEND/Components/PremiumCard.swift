import SwiftUI

struct PremiumCard<Content: View>: View {
    var accented = false
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(AppSpacing.lg).frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(accented ? AppColor.accent.opacity(0.22) : AppColor.separator, lineWidth: 1)
            }
    }
}
struct SectionHeader: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.headline, weight: .semibold))
            Spacer(minLength: AppSpacing.xs)
            if let detail { Text(detail).font(.caption).foregroundStyle(AppColor.muted) }
        }.accessibilityElement(children: .combine)
    }
}
struct PillStatus: View {
    let title: String
    var tint: Color = AppColor.accent
    var body: some View {
        Text(title).font(.system(.caption2, weight: .semibold)).tracking(0.8)
            .foregroundStyle(tint).padding(.horizontal, 10).padding(.vertical, 6)
            .background(tint.opacity(0.1), in: Capsule())
    }
}
struct MetricCard: View {
    let title: String
    let value: String
    let suffix: String
    let detail: String
    var tint: Color = AppColor.text
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Eyebrow(text: title)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(AppTypography.metric).monospacedDigit().contentTransition(.numericText())
                    Text(suffix).font(.headline).foregroundStyle(AppColor.muted)
                }.foregroundStyle(tint).minimumScaleFactor(0.75)
                Text(detail).font(.caption).foregroundStyle(AppColor.muted)
            }
        }
    }
}
struct EmptyStateCard: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Image(systemName: symbol).font(.title2).foregroundStyle(AppColor.accent).accessibilityHidden(true)
                Text(title).font(.headline)
                Text(detail).font(AppTypography.body).foregroundStyle(AppColor.muted).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
struct PrimaryAction: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.system(.subheadline, weight: .semibold))
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .foregroundStyle(AppColor.text).background(AppColor.accent.opacity(0.22), in: RoundedRectangle(cornerRadius: AppRadius.small))
                .overlay { RoundedRectangle(cornerRadius: AppRadius.small).strokeBorder(AppColor.accent.opacity(0.35)) }
        }.buttonStyle(PremiumPressStyle())
    }
}
