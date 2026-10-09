# ASCEND 1.1 — Adaptive coach

Private native personal fitness for iPhone / iOS 27. Local first: SwiftUI, SwiftData, deterministic engines, optional on-device Foundation Models explanations, RealityKit anatomy and a small ActivityKit widget. No account, analytics, backend, CloudKit or HealthKit.

## Run

1. On a Mac with Xcode 27 and iOS 27 SDK/runtime, open `ASCEND.xcodeproj`.
2. **ASCEND Demo** previews deterministic in-memory data. Release ignores demo/test arguments.
3. **ASCEND** uses real local storage. A fresh/reset owner completes seven setup steps; existing owners keep their history and skip setup.
4. Physical-device installation requires signing both the app and its embedded widget. See [iPhone install instructions](Docs/iPhoneInstall.md).

## Adaptive coach systems

The new Dashboard leads with today's live ELO, one explained next action, compact recovery inputs and a cautious weight ETA. Today's generated workout is the default; templates and manual sessions remain available. Morning check-ins, quick activities, optional RIR effort review, absolute exercise clocks and bounded live autoregulation feed the same activity/recovery/scoring graph. Ask ASCEND separates facts, estimates and recommendations. See [adaptive update architecture, preservation contract and verification](Docs/AdaptiveCoachUpdate.md).

- Five accessible dark navigation destinations, original 18 rank PNGs/thresholds and existing ELO/lifetime progression.
- Live workouts and absolute persistent rest, local rest-complete notification and system-rendered Live Activity countdown.
- Versioned structured backup, validated preview/atomic restore and hard-gated full reset in Profile → System → Data.
- First-use onboarding, persistent dated circumference measurements, global timestamp-only Sleep Mode and user-declared Sick protection.
- Exercise/count/duration/workout/fuel/sleep/weigh-in objectives, with real sets and Quick Logs counted once across history, recovery, exposure and Brain.
- Catalog of 150 exercises, equipment/favorites/hidden preferences, saved routines, progression and PRs.
- Real licensed Z-Anatomy muscle USDZ, native orbit/zoom/select, logical muscle mapping and accessible deterministic 2D fallback.
- Central semantic labels/gradients, event-driven motion/haptics, Reduce Motion/snapshot endpoints and cached deterministic Brain decisions.

Details, protection/scoring policy, migrations, scenario coverage and freeze gates: [V1 master update](Docs/V1MasterUpdate.md). Asset source, license, measured package size and conversion: [third-party anatomy](Docs/ThirdPartyAnatomy.md).

## Structure and verification

`ASCEND/Core/Domain` is the dependency-free SwiftPM engine library; `ASCEND/App` owns storage and derivation; `Features`/`Components` present it. `WidgetExtension` contains the embedded Live Activity. Tests are divided into Core, hosted App, UI and infrastructure; the checked-in project generator wires all four Xcode targets.

```sh
python -m unittest discover -s Tests/Infrastructure -v
python tools/validate_structure.py
python tools/check_delimiters.py
```

Windows Core, after installing official Swift: `pwsh -File tools/verify-windows.ps1` ([setup](WINDOWS_SETUP.md)). Mac: `swift test` and `bash tools/verify_on_mac.sh`.

The private [GitHub repository](https://github.com/Avelicek/PROJECT-ASCEND) runs Windows Core and Xcode 27 on main pushes, PRs and manual dispatch. See [repository/Actions setup](PRIVATE_REPOSITORY_SETUP.md). Apple verification builds Debug, Demo and Release, executes hosted tests and five smoke suites, exports **29 real simulator screenshots**, and attempts an **unsigned device archive**. Find logs/xcresults, PNGs and signing status in run artifacts.

Local Windows checks verify infrastructure, structure, encoding and assets. Native compilation, XCTest and simulator captures run in Actions for an exact commit; their latest outcomes are recorded in the adaptive update report. Foundation Models inference, signed iPhone installation and physical-device frame rate require a compatible real device. Earlier V1 reports describe historical builds.

After adding Swift files, run `python tools/generate_project.py`; review project customizations first because it owns build settings/schemes and local signing selections. Raw anatomy downloads, runtimes and generated build/QA output must remain outside tracked source. `Docs/Build*.md` and the older validation audit are historical records.
