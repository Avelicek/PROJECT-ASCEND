import SwiftUI

struct RankHeroView: View {
    @Environment(AppStore.self) private var store
    @Binding var showScore: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var eloSize: CGFloat = 66
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Eyebrow(text: "CURRENT STANDING")
                Spacer()
                Text("LVL \(store.lifetimeLevel)").font(.system(.caption2, weight: .medium)).foregroundStyle(AppColor.muted)
            }
            RankBadgeView(rank: store.rank.rank, size: 118).padding(.top, AppSpacing.md).padding(.bottom, 10)
            Text(store.rank.rank.title).font(.system(.subheadline, design: .rounded, weight: .semibold))
                .tracking(3).foregroundStyle(AppColor.rank(store.rank.rank.tier))
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(store.currentELO.formatted()).font(.system(size: eloSize, weight: .semibold, design: .rounded))
                    .accessibilityIdentifier("dashboard.elo").accessibilityValue(String(store.currentELO))
                    .tracking(-3).monospacedDigit().contentTransition(.numericText())
                Text("ELO").font(.system(.caption, weight: .semibold)).tracking(2).foregroundStyle(AppColor.muted)
            }.padding(.top, 6).minimumScaleFactor(0.65).lineLimit(1)
            Button { showScore = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right").font(.caption2)
                    Text("\(store.projectedScore.delta.formatted(.number.sign(strategy: .always()))) ELO today · provisional")
                        .font(.system(.caption, weight: .medium))
                    Image(systemName: "info.circle").font(.caption2)
                }.foregroundStyle(store.projectedScore.delta < 0 ? AppColor.warning : AppColor.positive)
                    .padding(.horizontal, 14).frame(minHeight: 44)
            }.buttonStyle(PremiumPressStyle()).accessibilityHint("Show score components and finalized history")
            RankProgressView(status: store.rank).padding(.top, AppSpacing.lg)
        }.padding(AppSpacing.lg)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous).fill(AppColor.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                            .fill(RadialGradient(colors: [AppColor.rank(store.rank.rank.tier).opacity(0.10), .clear],
                                center: .init(x: 0.5, y: 0.3), startRadius: 4, endRadius: 230))
                    }
            }
            .overlay { RoundedRectangle(cornerRadius: AppRadius.hero).strokeBorder(AppColor.rank(store.rank.rank.tier).opacity(0.17)) }
            .shadow(color: AppShadow.color, radius: AppShadow.radius, y: 12)
    }
}
struct ScoreBreakdownView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        List {
            Section {
                LabeledContent("Today's provisional ELO", value: store.projectedScore.delta.formatted(.number.sign(strategy: .always())))
                ForEach(store.projectedScore.components) { component in
                    LabeledContent(component.label, value: component.points.formatted(.number.sign(strategy: .always())))
                }
            } footer: { Text("Today's score is a preview. Incomplete objectives receive no final penalty until the day closes. Scores are finalized on the next launch or refresh after midnight.") }
            Section("Finalized evaluations") {
                ForEach(store.evaluations.reversed(), id: \.dayKey) { evaluation in
                    DisclosureGroup {
                        let components = (try? JSONDecoder().decode([ScoreComponent].self, from: evaluation.componentData)) ?? []
                        ForEach(components) { component in LabeledContent(component.label, value: component.points.formatted(.number.sign(strategy: .always()))) }
                    } label: { LabeledContent(evaluation.dayKey, value: evaluation.eloDelta.formatted(.number.sign(strategy: .always()))) }
                }
            }
        }.navigationTitle("Your ELO, explained").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}
