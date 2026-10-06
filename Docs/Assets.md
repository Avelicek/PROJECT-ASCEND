# Owner-supplied rank artwork

All 18 original 1254 × 1254 PNGs live in `ASCEND/Resources/RankBadges`. Their bytes, colors and transparency are preserved. No replacement badges are generated.

`tools/rank_badges.json` is the import manifest. Bronze/silver/gold/diamond filenames map to their corresponding divisions; `plat (1–3).png` maps to Platinum I–III and `conq1–3.png` maps to Conqueror I–III. Stable asset names are `rank_<tier>_<division>`.

After replacing owner artwork, run:

```sh
python tools/import_rank_badges.py
python -m unittest discover -s Tests/Infrastructure -v
```

The importer validates all source PNG chunks/checksums before writing any asset. It copies original bytes into universal image sets with original rendering intent. Commit both originals and image sets. Source originals are not bundled separately in the app; the Xcode resource phase compiles only the asset catalog.

`RankBadgeAsset` centralizes the 18 valid asset names. `RankBadgeView` resolves the domain rank through that enum, loads the compiled UIImage and adds tier-colored aura/shadow in SwiftUI. Dashboard, Profile and the compact ELO-history entry use this component. Unranked or missing artwork retains a vector fallback.

Python checks verify the complete mapping, PNG integrity and byte identity. Hosted XCTest loads every compiled asset. UI tests assert Platinum II artwork loads on the seeded Dashboard and Profile.

The AppIcon remains an empty slot because no final app icon was supplied. Add the owner's icon before distribution.
# Build 03 artwork audit

The Platinum II/III source filenames were reversed in the original owner pack (three versus two crown spires). Build 03 corrects those two filename associations, preserving both PNG byte streams, and reimports the catalog. The expected mapping remains Platinum II → `plat (2).png`, Platinum III → `plat (3).png`. `tools/rank_badges.lock.json` records the visually audited SHA-256 identity of all 18 images; import validates it before any writes. Update this lock intentionally when replacing artwork and re-audit its division markers.
