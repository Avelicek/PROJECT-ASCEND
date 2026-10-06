import Foundation

enum RankBadgeAsset: String, CaseIterable, Sendable {
    case bronzeI = "rank_bronze_1", bronzeII = "rank_bronze_2", bronzeIII = "rank_bronze_3"
    case silverI = "rank_silver_1", silverII = "rank_silver_2", silverIII = "rank_silver_3"
    case goldI = "rank_gold_1", goldII = "rank_gold_2", goldIII = "rank_gold_3"
    case platinumI = "rank_platinum_1", platinumII = "rank_platinum_2", platinumIII = "rank_platinum_3"
    case diamondI = "rank_diamond_1", diamondII = "rank_diamond_2", diamondIII = "rank_diamond_3"
    case conquerorI = "rank_conqueror_1", conquerorII = "rank_conqueror_2", conquerorIII = "rank_conqueror_3"

    static func resolve(_ rank: Rank) -> RankBadgeAsset? {
        rank.assetName.flatMap { RankBadgeAsset(rawValue: $0) }
    }
}
