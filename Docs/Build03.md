# Build 03 — anatomy and screen hierarchy

Recovery now centers on a layered SwiftUI Canvas with 44 front and 36 back muscle compartments: curved contours, directional shading, clipped fibre lines, a central sternum/spine and recovery-driven colour. Front and back use different pectoral/abdominal versus trapezius/lat/glute/hamstring geometry. Tap a rendered compartment or use the accessible region buttons. The selected compartment receives a brighter rim and restrained glow.

`AnatomyState.swift` presents eight regions from the existing recovery engine. It uses the lowest logged muscle's recovery, the lowest logged confidence, summed load index and highest fatigue index. Unlogged regions expose no fabricated percent, load, fatigue or confidence. The detail panel includes muscle coverage and the limiting muscle. These remain estimates, not measurements.

`AnatomyPresentation` owns front/back visibility and selection. `AnatomyGeometrySource` is the replaceable asset boundary; `StylizedAnatomyAsset` supplies normalized paths, and `AnatomyCanvas` owns lighting and hit testing. An owner-supplied 3D renderer can consume the same region states and presenter, replacing or augmenting this surface without changing recovery calculations or accessible controls. This build does not include a true 3D model or a RealityKit dependency.

Dashboard adds weight, sleep and seven-day sessions; stronger rank and daily delta typography; explicit objective percentages. Workout adds key totals, weighted muscle focus from working sets and logged RPE only when available; striped numbered set rows. Progress adds a seven-day consistency snapshot, framed axes and a Start → Trend → Target relationship. Profile moves edit/objective controls forward, enlarges rank artwork and separates body direction from daily fuel/sleep targets. Cards gain differentiated elevation. Anatomy selection and surface changes use existing reduced-motion and deterministic screenshot policies.

## Badge root cause and correction

The supplied filenames `plat (2).png` and `plat (3).png` had their artwork reversed: the former had three crown spires, the latter two. Build 03 exchanges their filenames/content associations and regenerates the catalog **without editing or recompressing either PNG**. Platinum II → `plat (2).png` now displays the two-spire image. Platinum III → `plat (3).png` displays three spires. All 18 owner images were visually audited; the other 16 filename associations are unchanged.

`RankBadgeAsset.resolve` explicitly switches on tier and division. `sourceFilename` explicitly names all 18 sources. The import manifest and SHA-256 lock verify the complete filename/artwork contract before writing any catalog entry. Python tests independently name every association and pin the visually audited Platinum II/III hashes, so a regenerated lock cannot hide that regression. Hosted XCTest tests every rank boundary, compiled asset, source filename and invalid division.

## Verification

The current GitHub Actions workflow is unchanged. Project regeneration wires the new app and hosted-test files. Local Python infrastructure, structure, delimiter and whitespace checks run on Windows. Native Swift/Apple checks require the CI toolchains; local structural checks do not imply compilation.

New hosted tests cover selection visibility, distinct front/back region geometry, unknown values, limiting recovery/confidence and warm-up exclusion in the session snapshot. The recovery smoke test uses explicit `body.view.front` / `body.view.back` buttons. Its previous failure was the assumption that SwiftUI's iOS 27 segmented picker appeared as an XCUITest `segmentedControl`, despite the visible control rendering correctly. Five primary screenshot names and the export path remain intact.
