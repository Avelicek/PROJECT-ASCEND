# PROJECT ASCEND — Build 01 + Build 01.5 verification

Native, local-first personal fitness for iPhone / iOS 27. SwiftUI, SwiftData, Swift Charts and optional on-device Foundation Models. No account, backend, CloudKit, HealthKit or third-party UI dependencies.

## Open and run

1. On a Mac with Xcode and the iOS 27 SDK, open `ASCEND.xcodeproj`.
2. Select **ASCEND Demo** and an installed iPhone simulator to inspect the populated dashboard immediately. This Debug scheme passes `--demo` and uses **only an in-memory store**.
3. Select **ASCEND** for production storage. It starts unranked, with no weight, nutrition, sleep, workout or rank history. Only the built-in exercise catalog and editable preference defaults are seeded.
4. For a physical iPhone, set your personal signing team under Signing & Capabilities. No team or provisioning identity is supplied.
5. Open Profile to set current/target weight and goals. Configure your own objectives. Optional on-device AI defaults off; deterministic insights always work.

Release builds ignore `--demo`. Demo data never enters the production store.

## Implemented

- Dashboard with rank badge fallback, ELO, provisional daily delta, rank progress, readiness, signed momentum, interactive objectives, nutrition and contextual insight.
- Five native navigation destinations with a custom accessible tab bar, dark reusable components, number/progress transitions, reduced-motion handling and contextual haptics.
- Editable goals, timestamped weight entries, daily calorie/protein totals and sleep with optional bed/wake times.
- Built-in catalog of 22 exercises, quick/full set logging, retroactive timestamps, previous performance, volume and PR engine.
- Detailed muscle model, cumulative decaying load, confidence-aware readiness and a replaceable anatomy preview.
- Exact 18-rank ladder; no XP. Lifetime level accumulates positive finalized ELO without decreasing.
- Rolling personal baselines for 7/14/28/90 days, weight smoothing, distinct goal progress and signed momentum.
- User-defined one-time, daily, weekly or weekday objectives with three importance weights and explicit recovery exemption.
- Versioned SwiftData schema with all 16 requested entities, relationship deletion rules, safe startup errors and transactional editing.
- Provider-independent fitness brain, immediate local fallback and optional guided on-device interpretation with output validation.

## Structure

```text
ASCEND.xcodeproj/          App + hosted XCTest + XCUITest targets; normal and demo schemes
ASCEND/
  App/                    Lifecycle, observable store, editing and daily evaluation services
  Core/
    Domain/               Platform-independent facts, engines and brain contracts
    Persistence/          SwiftData entities and V1 migration plan
    Intelligence/         Foundation Models adapter
    DesignSystem/         Color, typography, spacing, animation and haptic tokens
  Components/             Cards, rank badges, progress indicators, editors and objective rows
  Features/               Dashboard, Workout, Recovery, Progress, Profile, Logging, Objectives
  Resources/              Exercise catalog, isolated previews, assets, Info.plist
Tests/Core/               Engine tests shared by SwiftPM and Xcode
Tests/App/                SwiftData/store integration tests (Xcode only)
Tests/UI/                 Real launch/tab smoke and seeded screenshot tests (Xcode only)
Tests/Infrastructure/     Python CI failure/selection/export tests; no Swift execution
Package.swift             AscendCore library + engine tests; no external dependencies
tools/                    Windows SwiftPM, Apple CI, result export, summaries and project wiring
.github/workflows/        Windows + Xcode 27 jobs and combined six-stage report
Docs/                     Architecture, scoring contract, asset installation, validation and Build 02
```

## Verification

Build 01.5 is prepared locally for a future **private** repository. Read [PRIVATE_REPOSITORY_SETUP.md](PRIVATE_REPOSITORY_SETUP.md) for exact repository creation, push, Actions activation, first-run and artifact-download steps. Read [WINDOWS_SETUP.md](WINDOWS_SETUP.md) to install official Swift for native Core tests.

| Stage | Actual local result |
|---|---|
| CORE WINDOWS | NOT RUN — Swift absent from PATH |
| IOS COMPILE | NOT RUN — Windows has no Apple SDK/Xcode |
| UNIT TESTS | NOT RUN |
| UI SMOKE | NOT RUN |
| SCREENSHOTS | NOT RUN |
| FOUNDATION MODELS INFERENCE | NOT TESTED |

The local Python infrastructure suite and source/project checks are separate from these results. They cannot validate Swift types, macro expansion, simulator behavior or appearance. No real screenshot has been produced locally.

On a Mac:

```sh
swift test
bash tools/verify_on_mac.sh
```

The script requires Xcode 27 and an iOS 27+ SDK/runtime. It builds both shared schemes/test targets, runs unit and UI suites separately, exports five real screenshot attachments, preserves logs/result bundles and records stage statuses under `work/verification/ios`. Use `--output work/verification/ios-another-run` for another local run because a reused output directory is rejected. Manual device and accessibility checks remain necessary; see `Docs/Validation.md` and [the Build 01.5 audit](Docs/Build01.5-Audit.md).

On Windows, after installing Swift:

```powershell
& .\tools\verify-windows.ps1
```

To verify CI infrastructure without claiming app execution:

```sh
python -m unittest discover -s Tests/Infrastructure -v
python tools/validate_structure.py
python tools/check_delimiters.py
```

To add files, run `python3 tools/generate_project.py`. It updates file references and preserves existing artwork metadata. Review any project customization before regenerating: the script owns the project and shared schemes.

See `Docs/Build02.md` for intentionally deferred features and `Docs/Assets.md` for the owner's rank artwork slots.
