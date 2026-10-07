import SwiftUI

struct ELOMovement: View {
    let result: ELOResult
    @State private var value: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: 10) {
            Text("\(result.previousELO.formatted()) →").font(.caption).monospacedDigit().foregroundStyle(AppColor.muted)
            Text((value ?? (AppMotion.snapshotMode ? result.elo : result.previousELO)).formatted())
                .font(.system(size: 48, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(AppColor.eloGradient).contentTransition(.numericText(value: Double(result.elo)))
                .accessibilityLabel("\(result.previousELO) to \(result.elo) ELO")
        }.onAppear { withAnimation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.reward) { value = result.elo } }
    }
}

struct RankRewardView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let result: ELOResult
    let done: () -> Void
    @State private var appeared = false
    private var tint: Color { result.rank.rankedDown ? AppColor.negative : AppColor.rank(result.rank.rank.tier) }
    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 10)
            Text(result.rank.rankedDown ? "RANK DOWN" : "RANK UP").font(.system(.caption, weight: .semibold)).tracking(5).foregroundStyle(tint)
            RankBadgeView(rank: result.rank.rank, size: 230, animated: true)
                .scaleEffect(appeared || reduceMotion || AppMotion.snapshotMode ? 1 : 0.86)
                .opacity(appeared || AppMotion.snapshotMode ? 1 : 0)
            Text(result.rank.rank.title).font(.system(.title, design: .rounded, weight: .semibold)).foregroundStyle(tint)
            ELOMovement(result: result)
            Text("ELO RATING").font(.caption2).tracking(2).foregroundStyle(AppColor.muted)
            RankProgressView(status: result.rank).padding(.horizontal, 12)
            Spacer(minLength: 10)
            PrimaryAction(title: "Continue", symbol: "arrow.right", tint: tint, action: done).accessibilityIdentifier("rank.reward.done")
        }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                AppColor.background.ignoresSafeArea()
                RadialGradient(colors: [tint.opacity(0.19), .clear], center: .init(x: 0.5, y: 0.36), startRadius: 12, endRadius: 370).ignoresSafeArea()
            }.accessibilityIdentifier("screen.rankreward")
            .onAppear {
                withAnimation(reduceMotion || AppMotion.snapshotMode ? nil : AppAnimation.reward) { appeared = true }
                if result.rank.rankedUp { AppHaptics.reward(enabled: store.settings.hapticsEnabled) }
            }
    }
}
