import SwiftUI
import UIKit

struct BadgeOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let points: [CGPoint] = [
            .init(x: rect.midX, y: rect.minY), .init(x: rect.maxX * 0.91, y: rect.height * 0.24),
            .init(x: rect.maxX * 0.83, y: rect.height * 0.73), .init(x: rect.midX, y: rect.maxY),
            .init(x: rect.maxX * 0.17, y: rect.height * 0.73), .init(x: rect.maxX * 0.09, y: rect.height * 0.24)
        ]
        path.addLines(points); path.closeSubpath(); return path
    }
}
struct RankBadgeView: View {
    let rank: Rank
    var size: CGFloat = 124
    var animated = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var auraExpanded = false
    private var artwork: UIImage? { RankBadgeAsset.resolve(rank).flatMap { UIImage(named: $0.rawValue) } }
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [AppColor.rank(rank.tier).opacity(auraExpanded ? 0.25 : 0.14), .clear],
                center: .center, startRadius: 5, endRadius: size * 0.65))
                .frame(width: size * 1.4, height: size * 1.4).scaleEffect(auraExpanded ? 1.06 : 0.96)
                .accessibilityHidden(true)
            if let artwork {
                Image(uiImage: artwork).resizable().scaledToFit()
                    .shadow(color: AppColor.rank(rank.tier).opacity(0.18), radius: 12, y: 5)
            } else {
                ZStack {
                    BadgeOutline().fill(LinearGradient(colors: [AppColor.rank(rank.tier).opacity(0.20), AppColor.background], startPoint: .topLeading, endPoint: .bottomTrailing))
                    BadgeOutline().stroke(AppColor.rank(rank.tier).opacity(0.7), lineWidth: 1.5)
                    BadgeOutline().stroke(AppColor.rank(rank.tier).opacity(0.2), lineWidth: 1).padding(9)
                    VStack(spacing: 6) {
                        Image(systemName: rank.tier == .unranked ? "mountain.2" : "sparkle")
                            .font(.system(size: size * 0.22, weight: .light))
                        Text(rank.division == 0 ? "A" : ["", "I", "II", "III"][rank.division])
                            .font(.system(size: size * 0.24, weight: .semibold, design: .serif)).tracking(3)
                    }.foregroundStyle(AppColor.rank(rank.tier))
                }.padding(4)
            }
        }.frame(width: size, height: size * 1.12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(rank.title) rank badge")
            .accessibilityValue(artwork == nil ? "fallback" : RankBadgeAsset.resolve(rank)?.rawValue ?? "fallback")
            .onAppear {
                guard animated && !reduceMotion && !AppMotion.snapshotMode else { return }
                // A bounded ambient pulse settles to idle for accessibility, energy use and UI automation.
                withAnimation(.easeInOut(duration: 1.4).repeatCount(2, autoreverses: true)) { auraExpanded = true }
            }
    }
}
struct RankProgressView: View {
    let status: RankStatus
    var body: some View {
        VStack(spacing: 9) {
            HStack {
                Text(nextTitle).font(.caption2.weight(.medium)).foregroundStyle(AppColor.muted)
                Spacer()
                if let amount = status.amountToNext {
                    Text("\(amount) ELO to go").font(.caption2.weight(.semibold)).foregroundStyle(AppColor.text).monospacedDigit()
                } else { Text("MAX RANK").font(.caption2).foregroundStyle(AppColor.text) }
            }
            LinearProgress(progress: status.progress, tint: AppColor.rank(status.rank.tier), height: 6)
        }.accessibilityElement(children: .combine)
            .accessibilityValue("\(Int(status.progress * 100)) percent toward next rank")
    }
    private var nextTitle: String {
        guard let next = status.nextThreshold, let rank = RankEngine.ranks.first(where: { $0.threshold == next }) else { return "CONQUEROR III" }
        return "NEXT / \(rank.title)"
    }
}
