import SwiftUI

struct CompactRankIdentity: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let details: () -> Void
    var body: some View {
        Button(action: details) {
            HStack(spacing: 14) {
                RankBadgeView(rank: store.rank.rank, size: 58).accessibilityIdentifier("dashboard.rank.badge")
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(store.rank.rank.title).font(.subheadline.weight(.semibold)); Spacer(); Text("\(store.rank.elo) ELO").font(.subheadline).monospacedDigit().contentTransition(.numericText()) }
                    LinearProgress(progress: store.rank.progress, tint: AppColor.elo)
                    Text(store.rank.amountToNext.map { "\($0) ELO to the next rank" } ?? "Highest rank reached").font(.caption).foregroundStyle(AppColor.muted)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(AppColor.muted)
            }.padding(14).background(AppColor.surface, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(PremiumPressStyle()).foregroundStyle(AppColor.text).accessibilityIdentifier("dashboard.rank")
            .animation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.interaction, value: store.rank.elo)
    }
}
