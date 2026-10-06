import Foundation

public enum RankTier: String, Codable, Sendable { case unranked, bronze, silver, gold, platinum, diamond, conqueror }
public struct Rank: Equatable, Sendable, Identifiable {
    public let tier: RankTier
    public let division: Int
    public let threshold: Int
    public var id: String { "\(tier.rawValue)_\(division)" }
    public var title: String {
        tier == .unranked ? "UNRANKED" : "\(tier.rawValue.uppercased()) \(["", "I", "II", "III"][division])"
    }
    public var assetName: String? { tier == .unranked ? nil : "rank_\(tier.rawValue)_\(division)" }
}
public struct RankStatus: Sendable {
    public let rank: Rank
    public let elo: Int
    public let lowerThreshold: Int
    public let nextThreshold: Int?
    public let progress: Double
    public let amountToNext: Int?
    public let rankedUp: Bool
    public let rankedDown: Bool
}
public struct RankEngine: Sendable {
    public static let ranks: [Rank] = [
        Rank(tier: .unranked, division: 0, threshold: 0),
        Rank(tier: .bronze, division: 1, threshold: 100),
        Rank(tier: .bronze, division: 2, threshold: 150),
        Rank(tier: .bronze, division: 3, threshold: 250),
        Rank(tier: .silver, division: 1, threshold: 350),
        Rank(tier: .silver, division: 2, threshold: 450),
        Rank(tier: .silver, division: 3, threshold: 550),
        Rank(tier: .gold, division: 1, threshold: 650),
        Rank(tier: .gold, division: 2, threshold: 750),
        Rank(tier: .gold, division: 3, threshold: 850),
        Rank(tier: .platinum, division: 1, threshold: 950),
        Rank(tier: .platinum, division: 2, threshold: 1050),
        Rank(tier: .platinum, division: 3, threshold: 1200),
        Rank(tier: .diamond, division: 1, threshold: 1350),
        Rank(tier: .diamond, division: 2, threshold: 1500),
        Rank(tier: .diamond, division: 3, threshold: 1700),
        Rank(tier: .conqueror, division: 1, threshold: 2000),
        Rank(tier: .conqueror, division: 2, threshold: 2150),
        Rank(tier: .conqueror, division: 3, threshold: 2400)
    ]
    public init() {}
    public func status(elo: Int, previousELO: Int? = nil) -> RankStatus {
        let value = max(0, elo)
        let index = Self.ranks.lastIndex(where: { value >= $0.threshold }) ?? 0
        let current = Self.ranks[index]
        let next = index + 1 < Self.ranks.count ? Self.ranks[index + 1].threshold : nil
        let oldIndex = Self.ranks.lastIndex(where: { max(0, previousELO ?? value) >= $0.threshold }) ?? 0
        let progress = next.map { Double(value - current.threshold) / Double($0 - current.threshold) } ?? 1
        return RankStatus(rank: current, elo: value, lowerThreshold: current.threshold, nextThreshold: next,
                          progress: progress, amountToNext: next.map { $0 - value },
                          rankedUp: index > oldIndex, rankedDown: index < oldIndex)
    }
}
