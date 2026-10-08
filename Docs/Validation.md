# Validation status and Build 01.5 CI handoff

> Historical Build 01.5 record. Current repository, V1 implementation and remaining acceptance: [V1MasterUpdate.md](V1MasterUpdate.md). Counts and setup state below describe that earlier build.

## Authoring environment

Windows / PowerShell. Empty initial workspace; no Git repository, existing Xcode project, Swift compiler, Apple SDK or Xcode executable. No compilation, Swift tests, macro expansion, simulator screenshots, on-device AI inference or device visual verification can be claimed.

`tools/validate_structure.py` uses the Python standard library for static project/source/asset checks. Its success is not a Swift parse, compilation or test result. A standard-library lexical delimiter check covers all 49 Swift files, including the package manifest and UI tests; it is not a syntax or type check. All 24 infrastructure tests passed locally: 17 Python orchestration/export/report tests and seven native PowerShell command-fixture checks. These fixtures never count as real Swift or iOS execution. On macOS the seven Windows-only tests are skipped.

The workflow parses as YAML; embedded Bash/PowerShell scripts pass syntax checks. Actionlint 1.7.12 passes with only its outdated `xcode-27` label diagnostic excluded. GitHub's official runner documentation independently confirms that preview label for private repositories. No other actionlint diagnostic was excluded; optional shellcheck/pyflakes integrations were unavailable and disabled. This validates workflow configuration, not a hosted run.

| Stage | Actual local result |
|---|---|
| CORE WINDOWS | NOT RUN (Swift absent; verifier exits 2) |
| IOS COMPILE | NOT RUN (Apple tooling absent) |
| UNIT TESTS | NOT RUN |
| UI SMOKE | NOT RUN |
| SCREENSHOTS | NOT RUN |
| FOUNDATION MODELS INFERENCE | NOT TESTED |

See `../WINDOWS_SETUP.md`, `../PRIVATE_REPOSITORY_SETUP.md` and `Build01.5-Audit.md`. No GitHub repository exists yet; configuration is complete locally and remote execution remains pending.

## Automated checks to run on a Mac

```sh
swift test
bash tools/verify_on_mac.sh
```

Core test coverage includes every exact threshold and its ±1 boundaries, both transition directions at all thresholds, interval-width progress, negatives/Int.max/top rank, asset names, goal progress for gaining/losing/maintenance, fluctuation smoothing, duplicate days, sparse/stale history, signed momentum, invalid/future data, recovery/readiness bounds, cumulative decaying load, sleep influence, ELO floor/exemption/explanations, objective recurrence, DST, monotonic lifetime levels, records and deterministic AI fallback.

Hosted tests cover empty production bootstrap, isolated demo, catalog idempotency, daily evaluation idempotency and component totals, invalid profile rollback, cascading workouts and recovery-protected objective snapshots. All Swift tests are **authored but not executed here**.

The project requires a Mac with the iOS 27 SDK; device installation also requires the owner's signing team. Foundation Models API use was checked against Apple's public documentation only. Build and macro diagnostics from the installed SDK are the next authority.

## Manual acceptance checks

1. Open ASCEND Demo in an installed large iPhone simulator. Inspect hero hierarchy, badge fallback, all cards and all five tabs. Check a smaller iPhone too.
2. Open ASCEND without the demo argument. Verify no synthetic history, no rank inflation and unknown readiness/momentum. Save profile goals and then relaunch.
3. Save daily nutrition twice: second save must replace, not add. Log daily/weekly weight and retroactive entries. Confirm measured and trend values differ when weights fluctuate.
4. Log quick push-ups, full loaded sets, timed plank and distance running. Check the correct input fields, earlier performance, catalog relationship and recovery changes.
5. Create all four schedule kinds and importance levels; complete a custom habit. Check metric objectives update from actual logs. Choose a recovery alternative and verify no missed penalty.
6. With a development clock, move past midnight. Check one finalized ledger entry per recorded date, component sum = delta, unchanged history on repeat refresh and no fabricated missed offline days.
7. Change target weight and current weight in Profile. Confirm goal baseline resets only for a changed goal; historical measurements and finalized ELO stay intact. Cancel another edit and verify no mutation.
8. Try invalid inputs; check error alerts and unchanged saved values. Simulate an unavailable store and inspect the retry screen without data replacement.
9. Enable optional AI on an eligible iPhone. Check availability fallback, generated-result label, stale-result cancellation, disallowed-action rejection and no metric/history changes. Repeat with AI unavailable.
10. Enable VoiceOver, Reduce Motion and accessibility text sizes. Check tab selection, 44-point targets, scroll reachability, complete labels, contrast and number/progress transitions.
11. Profile with Instruments on a real device. Verify launch does not wait for AI, tab state persists and an extended history remains responsive.

## Actual outstanding dependencies

Mac/Xcode/iOS 27 SDK for build and runtime verification; owner-supplied rank artwork and final app icon for final branding; personal signing configuration for physical device installation. No credentials or network service are needed for core use.
