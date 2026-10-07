import SwiftUI

struct RankHeroView: View {
    @Environment(AppStore.self) private var store
    @Binding var showScore: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var eloSize: CGFloat = 54
    @Environment(\.dynamicTypeSize) private var typeSize
    private var tint: Color { AppColor.rank(store.rank.rank.tier) }
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 6) { Circle().fill(tint).frame(width: 5, height: 5); Eyebrow(text: "CURRENT RANK") }
                Spacer()
                PillStatus(title: "LEVEL \(store.lifetimeLevel)", tint: tint)
            }
            Group {
                if typeSize.isAccessibilitySize { VStack(spacing: 10) { emblem; standing } }
                else { HStack(spacing: 24) { emblem; standing } }
            }
            RankProgressView(status: store.rank)
        }.padding(20)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous).fill(AppColor.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.hero, style: .continuous)
                            .fill(RadialGradient(colors: [tint.opacity(0.10), .clear],
                                center: .init(x: 0.22, y: 0.45), startRadius: 4, endRadius: 280))
                    }
            }
            .overlay { RoundedRectangle(cornerRadius: AppRadius.hero).strokeBorder(LinearGradient(colors: [tint.opacity(0.16), tint.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing)) }
            .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
    }
    private var emblem: some View {
        RankBadgeView(rank: store.rank.rank, size: 144, animated: true)
            .accessibilityIdentifier("dashboard.rank.badge")
    }
    private var standing: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.rank.rank.title).font(.system(.headline, design: .rounded, weight: .semibold)).tracking(0.6).foregroundStyle(tint)
            CountUpText(value: Double(store.currentELO)).font(.system(size: eloSize, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColor.eloGradient)
                .shadow(color: AppColor.elo.opacity(0.12), radius: 12)
                .tracking(-2).lineLimit(1).minimumScaleFactor(0.65)
                .accessibilityIdentifier("dashboard.elo").accessibilityValue(String(store.currentELO))
            Text("ELO RATING").font(.system(.caption2, weight: .medium)).tracking(1.5).foregroundStyle(AppColor.muted)
            Button { showScore = true } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Label("\(store.projectedScore.delta.formatted(.number.sign(strategy: .always()))) ELO today",
                        systemImage: store.projectedScore.delta == 0 ? "minus" : store.projectedScore.delta < 0 ? "arrow.down.right" : "arrow.up.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(SemanticStatus.momentum(Double(store.projectedScore.delta)).tint)
                    PillStatus(title: "PENDING", tint: AppColor.muted)
                }.padding(.vertical, 5).frame(minHeight: 44, alignment: .leading)
            }.buttonStyle(PremiumPressStyle()).accessibilityHint("Show score components and finalized history")
        }.frame(maxWidth: .infinity, alignment: .leading)
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
