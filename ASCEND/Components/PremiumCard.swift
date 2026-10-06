import SwiftUI

struct PremiumCard<Content: View>: View {
    var accented = false
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [AppColor.surface, AppColor.elevated.opacity(0.52)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [accented ? AppColor.accent.opacity(0.32) : Color.white.opacity(0.13), AppColor.separator.opacity(0.25)],
                        startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
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
        Text(title).font(.system(.caption2, weight: .semibold)).tracking(0.5).lineLimit(1).minimumScaleFactor(0.75)
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
            HStack(spacing: AppSpacing.md) {
                Image(systemName: symbol).font(.title2).foregroundStyle(AppColor.accent).frame(width: 44).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.headline)
                    Text(detail).font(.caption).foregroundStyle(AppColor.muted).fixedSize(horizontal: false, vertical: true)
                }
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
            HStack(spacing: 10) {
                Image(systemName: symbol).frame(width: 20).accessibilityHidden(true)
                Text(title)
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right").font(.caption).accessibilityHidden(true)
            }.font(.system(.subheadline, weight: .semibold)).padding(.horizontal, 16).frame(minHeight: 50)
                .foregroundStyle(AppColor.text)
                .background(LinearGradient(colors: [AppColor.accent.opacity(0.35), AppColor.blue.opacity(0.12)], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(AppColor.accent.opacity(0.3)) }
        }.buttonStyle(PremiumPressStyle()).accessibilityLabel(title)
    }
}
