# Build 05 — Premium daily experience

Build 05 refines the existing daily loop. ELO thresholds, scoring, deterministic progression and recovery rules, persistence schema, owner rank artwork, strict concurrency and warnings-as-errors remain in place.

- Semantic accents and quieter typography distinguish rank, training, recovery, nutrition, sleep, body weight and PRs. Hero, metric, action, analytics and status surfaces share restrained depth and motion that respects Reduce Motion.
- Live training has a fixed session clock and exercise/set progress, compact locked set rows, a numeric keyboard accessory, previous-value copying and a floating rest arc with pause, skip and +30 seconds. The optional rest span decodes older saved drafts.
- Dashboard Next Action uses existing logs and confidence gates. Daily evaluation distinguishes pending and finalized ELO; a real crossed threshold can reveal the full-screen rank reward.
- Workout completion shows duration, working sets, external volume, pending ELO, actual PRs and muscle load. Progress drill-downs use saved ELO, volume, estimated strength, nutrition consistency and PR records. Recovery adds Recovery/Load/Fatigue modes without replacing anatomy geometry.

## Verification

Run `python tools/generate_project.py`, `python tools/validate_structure.py`, `python tools/check_delimiters.py`, `python -m unittest discover -s Tests/Infrastructure -v` and `git diff --check` locally. Windows checks do not establish that Swift compiles or UI tests pass; the existing GitHub Actions macOS/Xcode job supplies that evidence.

Added coverage includes Next Action priority/confidence, unknown anatomy values, memory-only reward/summary fixtures, backward-compatible rest span decoding, keyboard set completion, rest resume, daily result, rank reward and recovery mode switching.

The screenshot test preserves `01_dashboard` through `05_profile` and adds `06_live_workout`, `07_workout_summary`, `08_daily_evaluation`. Export validation requires all eight authentic simulator PNGs. Extra fixtures are DEBUG-only, require demo/UI-testing arguments and use the in-memory store; summary fixtures finish through the real workout engines. Production data is never used for screenshot fixtures.

Inspect the existing run's `ascend-simulator-screenshots` artifact for images and `ios-build-and-test-results` for build logs and XCTest result bundles. No new service, backend or workflow is required.
