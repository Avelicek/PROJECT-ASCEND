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
struct GlowContainer<Content: View>: View {
    let tint: Color
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            Ellipse().fill(tint.opacity(0.12)).blur(radius: 32).padding(-16)
            content
        }
    }
}
struct RankBadgeView: View {
    let rank: Rank
    var size: CGFloat = 124
    var body: some View {
        GlowContainer(tint: AppColor.rank(rank.tier)) {
            if let asset = rank.assetName, UIImage(named: asset) != nil {
                Image(asset).resizable().scaledToFit().padding(4)
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
            .accessibilityLabel("\(rank.title) rank badge")
    }
}
struct RankProgressView: View {
    let status: RankStatus
    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            LinearProgress(progress: status.progress, tint: AppColor.rank(status.rank.tier))
            HStack {
                Text(status.rank.title).font(.caption2).foregroundStyle(AppColor.muted)
                Spacer()
                if let amount = status.amountToNext {
                    Text("\(amount) ELO to next rank").font(.caption2).foregroundStyle(AppColor.text)
                } else { Text("Beyond the summit").font(.caption2).foregroundStyle(AppColor.text) }
            }
        }.accessibilityElement(children: .combine)
            .accessibilityValue("\(Int(status.progress * 100)) percent toward next rank")
    }
}
