import Foundation

enum RankBadgeAsset: String, CaseIterable, Sendable {
    case bronzeI = "rank_bronze_1", bronzeII = "rank_bronze_2", bronzeIII = "rank_bronze_3"
    case silverI = "rank_silver_1", silverII = "rank_silver_2", silverIII = "rank_silver_3"
    case goldI = "rank_gold_1", goldII = "rank_gold_2", goldIII = "rank_gold_3"
    case platinumI = "rank_platinum_1", platinumII = "rank_platinum_2", platinumIII = "rank_platinum_3"
    case diamondI = "rank_diamond_1", diamondII = "rank_diamond_2", diamondIII = "rank_diamond_3"
    case conquerorI = "rank_conqueror_1", conquerorII = "rank_conqueror_2", conquerorIII = "rank_conqueror_3"

    static func resolve(_ rank: Rank) -> RankBadgeAsset? {
        switch (rank.tier, rank.division) {
        case (.bronze, 1): .bronzeI
        case (.bronze, 2): .bronzeII
        case (.bronze, 3): .bronzeIII
        case (.silver, 1): .silverI
        case (.silver, 2): .silverII
        case (.silver, 3): .silverIII
        case (.gold, 1): .goldI
        case (.gold, 2): .goldII
        case (.gold, 3): .goldIII
        case (.platinum, 1): .platinumI
        case (.platinum, 2): .platinumII
        case (.platinum, 3): .platinumIII
        case (.diamond, 1): .diamondI
        case (.diamond, 2): .diamondII
        case (.diamond, 3): .diamondIII
        case (.conqueror, 1): .conquerorI
        case (.conqueror, 2): .conquerorII
        case (.conqueror, 3): .conquerorIII
        default: nil
        }
    }

    var sourceFilename: String {
        switch self {
        case .bronzeI: "bronze (1).png"
        case .bronzeII: "bronze (2).png"
        case .bronzeIII: "bronze (3).png"
        case .silverI: "silver (1).png"
        case .silverII: "silver (2).png"
        case .silverIII: "silver (3).png"
        case .goldI: "gold (1).png"
        case .goldII: "gold (2).png"
        case .goldIII: "gold (3).png"
        case .platinumI: "plat (1).png"
        case .platinumII: "plat (2).png"
        case .platinumIII: "plat (3).png"
        case .diamondI: "diamond (1).png"
        case .diamondII: "diamond (2).png"
        case .diamondIII: "diamond (3).png"
        case .conquerorI: "conq1.png"
        case .conquerorII: "conq2.png"
        case .conquerorIII: "conq3.png"
        }
    }
}
