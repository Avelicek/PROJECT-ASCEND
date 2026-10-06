# Owner-supplied rank artwork

No rank images have been generated. Each tier/division has an empty universal image set in `ASCEND/Resources/Assets.xcassets`:

```text
rank_bronze_1       rank_bronze_2       rank_bronze_3
rank_silver_1       rank_silver_2       rank_silver_3
rank_gold_1         rank_gold_2         rank_gold_3
rank_platinum_1     rank_platinum_2     rank_platinum_3
rank_diamond_1      rank_diamond_2      rank_diamond_3
rank_conqueror_1    rank_conqueror_2    rank_conqueror_3
```

In Xcode, drag the owner's corresponding image into each named image set. Preserve transparency and choose an appropriate resolution for the 118-point dashboard badge. Do not rename the sets or bake glow/particles into the source images.

`RankBadgeView` detects actual named images. Until supplied, a neutral vector outline, tier color and division glyph render in code; this is a graceful placeholder, not replacement rank artwork. Ambient depth and glow surround either path in SwiftUI. No code change is needed when artwork arrives.

The AppIcon set is also empty because no final application icon was supplied. Add a 1024×1024 app icon before distribution; an empty slot is intentional for local Build 01 development. Empty image sets may produce asset-catalog warnings until populated.
