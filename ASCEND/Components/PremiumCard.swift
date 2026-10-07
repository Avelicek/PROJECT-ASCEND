import SwiftUI

enum CardRole: Equatable { case hero, metric, action, analytics, status, ambient, glass, inline }

struct PremiumCard<Content: View>: View {
    var accented = false
    var role: CardRole = .analytics
    var tint: Color = AppColor.elo
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(role == .metric ? 14 : 18).frame(maxWidth: .infinity, alignment: .leading)
            .background {
                if role != .ambient && role != .inline {
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).fill(AppColor.surface.opacity(role == .analytics ? 0.75 : 1))
                }
                if role == .glass { RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous).fill(.ultraThinMaterial).opacity(0.35) }
                if accented || role == .hero || role == .action || role == .status {
                    RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        .fill(RadialGradient(colors: [tint.opacity(role == .status ? 0.04 : 0.075), .clear], center: .topLeading, startRadius: 0, endRadius: 360))
                }
            }
            .overlay {
                if role == .hero || role == .glass || role == .metric || accented { RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [accented || role == .hero ? tint.opacity(0.12) : Color.white.opacity(0.035), AppColor.separator.opacity(0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
            }
            .shadow(color: .black.opacity(accented || role == .hero ? 0.28 : 0.10), radius: accented || role == .hero ? 18 : 5, y: accented || role == .hero ? 9 : 2)
    }
}
struct SectionHeader: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.subheadline, weight: .semibold)).foregroundStyle(AppColor.secondary)
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
        PremiumCard(role: .metric) {
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
    var tint: Color = AppColor.elo
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
                .background(LinearGradient(colors: [tint.opacity(0.25), tint.opacity(0.08)], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(tint.opacity(0.18)) }
        }.buttonStyle(PremiumPressStyle()).accessibilityLabel(title)
    }
}
