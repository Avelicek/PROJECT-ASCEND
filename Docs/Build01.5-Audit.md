# Build 01.5 source audit and verification boundary

This revision adds verification infrastructure to Build 01. It does not start Build 02, extend anatomy or expand the 22-exercise catalog. Source inspection is complete; Apple SDK/compiler acceptance remains **NOT RUN** until the first remote run.

## Portability and target boundaries

`AscendCore` comprises the ten files under `ASCEND/Core/Domain`. They import Foundation only. Rank/ELO, weight progress and smoothing, personal baseline windows, recovery, objectives, workout calculations and provider-independent fitness interpretation are value-oriented `Sendable` contracts. SwiftPM includes only `Tests/Core`; model persistence, UI and generated Foundation Models types are excluded. The package has no external dependencies. Native Windows XCTest exercises calendar-day arithmetic, timezone/DST behavior and Foundation math rather than mocking them.

Xcode compiles all 39 app Swift files. `ASCENDTests` includes Core plus SwiftData integration tests; `ASCENDUITests` includes only `Tests/UI`. Both shared schemes build the app and test targets for testing. Demo is a Debug launch argument for the same app, and hosted unit tests do not inherit that argument. The project generator owns the checked-in project and schemes; it is not required on the hosted runner.

## Apple-only review

| Area | Source audit / change | Authoritative remaining check |
|---|---|---|
| SwiftData | All 16 entities are registered in a versioned schema; unique keys, optional inverse references, cascade workout children and nullified catalog/objective references reviewed. Schema version is now computed, removing mutable global state. | Xcode macro expansion, schema creation, saves, cascade tests and integration assertions |
| SwiftUI / Observation | App/store are MainActor; view environments, State, Bindable, Binding, ScaledMetric, result builders, previews, navigation, sheets and property wrappers reviewed. Accessibility IDs annotate existing views and tabs. | SDK type checking, actor diagnostics, launch, five visible screen checks |
| Charts | PointMark/LineMark, date and numeric plottable values, automatic y scale and interpolation reviewed. Charts stays outside Core. | Apple SDK compile and rendered Progress screenshot |
| FoundationModels | Adapter is guarded by `canImport`; guided output uses Generable/Guide and a fresh language-model session. Availability is checked before requests. Prose/action validation remains bounded and provider-independent. | SDK compile of macro expansions and API signatures; actual inference is not attempted |
| iOS availability | Deployment target 27.0; CI requires Xcode 27 and an installed iOS simulator SDK/runtime >=27. No guessed backwards-compatibility shims were added. | Actual installed SDK and simulator are the source of truth |
| Concurrency / Sendable | AppStore/model context mutations remain MainActor. Async inference takes Sendable BrainContext and returns Sendable BrainInsight; cancellation/stale-result guards precede writes. ExerciseCatalog.Definition now explicitly conforms to Sendable for immutable static catalog data. | Swift compiler with complete concurrency checking and warnings as errors |
| Error paths | Store startup errors present retry UI; deterministic insight exists before any inference. FitnessBrain catches unavailable/throwing providers and uses local interpretation. | Unit tests for absent/throwing providers, no-model launch smoke and actual unsupported-device testing |

Source changes address review findings; they are not claimed as compiler-confirmed fixes. No remote compiler diagnostics exist yet. A successful source search, Python test or delimiter check cannot establish that a Swift/Apple API exists. CI compiles SwiftData and Generable macros with the installed SDK, and any real diagnostic must be fixed and rerun before its stage is reported PASS.

Swift and Clang warnings are errors in CI. Complete concurrency diagnostics are enabled in the Swift 5 app language mode; the portable package uses Swift tools 6.0. Asset-tool warnings about the existing empty rank/app-icon slots are preserved in logs. Artwork installation remains the owner's separate Build 01 task.

## Real UI and image evidence

Smoke tests launch Demo, confirm its ELO 1084, navigate all five tab IDs, require each corresponding ScrollView to be hittable and verify foreground app state. A second smoke test launches normal storage without a model request and confirms deterministic insight. The screenshot test launches a fresh in-memory Demo store, captures each visible destination using XCUIApplication.screenshot, and stores keepAlways attachments. It does not replace the UI with test layouts or generated mockups.

The Debug-only `--ui-testing` flag freezes the clock at 2026-10-06 12:00 UTC only when combined with the in-memory Demo argument. Manual Demo retains real time; release builds ignore both arguments. This avoids midnight ledger changes during screenshots. The fixture clock is included in screenshot provenance.

The exporter reads the actual xcresulttool manifest, requires one PNG for each requested name, checks PNG headers/dimensions and rejects ambiguous, missing or escaping paths. A screenshot stage reports GENERATED only after XCTest success, a nonempty passing result summary and all five attachments. The raw manifest/xcresult/logs are retained when export fails. Test-result summaries must demonstrate executed tests, so an empty successful command cannot become PASS.

The exporter uses the modern xcresulttool export/summary commands and archives their installed help output. The attachment field layout is corroborated by [Chromium's own xcresult parser](https://chromium.googlesource.com/chromium/src/+/HEAD/ios/build/bots/scripts/xcode_log_parser.py); compatibility with Xcode 27 still requires the actual run. If Apple changes its schema, the exporter fails explicitly and preserves evidence.

## Reporting

Stage statuses are written as work proceeds, including failure before a command finishes. Windows and iOS jobs execute independently; summary collection never converts missing results into PASS. After test binaries build, unit failures do not skip smoke or screenshot attempts. A failed compile prevents test execution and leaves tests NOT RUN. Uploads are attempted on failed jobs, with no DerivedData upload. Interrupted jobs may prevent uploads entirely; their job result/logs remain relevant alongside the status table.

FOUNDATION MODELS INFERENCE stays **NOT TESTED**. Foundation Models availability or success is not inferred from a fallback, compiled macro, simulator screenshot or green unit test. Unsupported model behavior is covered through provider failure contracts, while an actual device-level availability/inference report remains future evidence.

Local Windows results are captured in `work/local-status.md`. The separately labeled Python infrastructure tests validate selection, export parsing, status merging and failure propagation with temporary fixtures. They do not count as Core, unit, UI smoke or screenshot execution. Follow `WINDOWS_SETUP.md` for real Windows Swift execution and `PRIVATE_REPOSITORY_SETUP.md` for the first real Apple run.
