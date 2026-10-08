# ASCEND V1 master update — implementation and acceptance

This is the last major feature scope before physical-device QA and V1 freeze. It is **Gold Master preparation**, not a claim that the current commit has passed Apple compilation or device acceptance. Historical CI/artifacts do not prove this commit.

## Architecture and migration

Recorded personal data → existing deterministic fitness engines → PersonalContext → PersonalBrainEngine → optional on-device explanation → SwiftUI presentation. Unknown inputs remain unknown. No invented sleep stages, HRV, calories burned, illness severity, biological readiness or medical advice.

The existing sixteen-entity SwiftData SchemaV1 and migration plan remain unchanged. Versioned `owner-system-v1.json` adds onboarding completion, height/birth-date metadata, circumference history, active sleep timestamp, Sick intervals, per-exercise rest preferences and last seen evaluation. Existing owners without that file skip first-use onboarding; empty/reset owners start setup. Training, Brain and unfinished-workout JSON remain versioned and keep their existing filenames. A populated Build 06 migration fixture verifies existing profile, logs, training preferences, sessions and Brain settings.

After a restore/reset, a generation pointer selects a freshly saved SwiftData store plus all sidecars. Without the pointer, the original SwiftData/default path and ASCEND sidecars are used. A corrupt pointer/store produces the existing safe startup error; it never silently creates an empty owner database. Demo and screenshot fixtures use in-memory storage. The restart UI fixture uses a unique cache folder and cannot replace the production owner store.

## Data vault: export, restore and reset

Profile → System → Data exports `.ascendbackup`: Codable envelope schema 1, export date, app version, complete payload and SHA-256 integrity metadata. Fifteen source entity record types use explicit scalar DTOs and relationship IDs; derived MuscleState is rebuilt. Owner metadata, all logs, sessions/sets/snapshots, PRs, objective definitions/occurrences, evaluation/ELO history, lifetime credits, exercise metadata, routines/equipment/favorites/hidden, Brain configuration/history/preferences/explanations and the active workout/rest are included.

The digest canonicalizes the three unordered training sets, so encode/decode does not fail on arbitrary Set order. This detects accidental corruption, not cryptographic authentication. The file is not encrypted by ASCEND and only leaves the device through an explicit Files export.

Restore decodes and validates size/version/digest, unique keys, references, enum cases, contributions, dates and numeric bounds **before preview**. Explicit “Replace & restore” is required. A new UUID staging folder receives a reconstructed database and sidecars; services are suppressed while preparing it. The atomic `active-generation.json` write is the single commit point. Before that point, failures preserve the original database, files and rest notifications. On success the observable store is replaced, derived data rebuilt, restored rest services synchronized and retired stores/sidecars cleaned after replacement or on next launch. Failed staging generations are ignored and cleaned during subsequent startup. Exported copies in Files are intentionally under the user's control.

Reset requires both the full deletion-consent checkbox and exact `RESET ASCEND` phrase. It selects a clean generation, clears all owner history/modes/preferences/active training, cancels/replaces rest services and returns to onboarding. Only the standard exercise catalog/editable empty-owner defaults remain. Reset does not operate on externally exported backups. A selected store's retirement manifest is internal housekeeping, never an imported backup field.

## Onboarding and measurements

Seven steps: identity/height, optional weight/target/circumferences, supported training goal, editable fuel, sleep target, equipment/session duration, optional daily fuel/sleep objectives. The eighth Ready screen enters ASCEND and persists completion. Existing owners skip it. Measurements are dated optional chest/waist/hips/biceps/thigh entries, separate from Dashboard and available in Profile. No advanced circumference inference is added.

## Global modes

**Sleep Mode** saves only a start timestamp; no overnight timer. End Sleep shows a recorded interval, editable start/end and quality 1–5. It accepts 6 minutes to 24 hours, rejects future ends, supports cancellation and requires explicit replacement of an existing wake-day sleep entry. Absolute elapsed time handles midnight and DST; day assignment uses the owner's configured calendar/time zone. Mode survives process death through the owner sidecar. It pauses Brain pressure and makes the sleep hero dominant; navigation and fuel remain usable.

**Sick Mode** is a user declaration with optional personal note. It pauses Brain recommendations without altering numeric muscle recovery. Incomplete workout/exercise occurrences on intersecting days are marked protected, not completed. Fuel, sleep and weigh-ins remain available; no illness nutrition prescription is applied. Protected missed training cannot lose ELO or earn the ordinary recovery-choice bonus. Actual performance/fuel keep their established scoring. Even while protected, exercise progress continues to derive from real manual logs; actual completion earns normal completion and clears the unperformed protection marker. Ending is confirmed and records an end timestamp; protected history remains protected and is not retroactively penalized. Training/objective streaks bridge protected dates without increasing their count for protected-only dates. Nutrition/perfect-day streaks retain their original policy.

## Daily Objectives 2.0

Custom checkbox, manual count/duration, linked exercise, workout, calories, protein, recorded sleep and weigh-in use existing recurrence/importance rules. Today rows route to their actual logging actions; recurring definitions can be edited/archived. Manual habits do not fabricate workout history.

Exercise progress derives solely from completed non-warmup canonical sets across full workouts and Quick Logs. Four sets of twenty push-ups plus twenty Quick Log reps produce 100/100 once. Duration exercises derive seconds. Quick Log creates one real working set/session and therefore enters history, recovery load, weekly muscle/movement exposure and Brain context. It remains excluded from progression/PR comparisons under the existing conservative policy. No separate objective-generated load is added.

Recovery limitation offers explicit Keep, Reduce Today or Protect Today. Reduction changes only today's target; closed-day snapshots and recurring definitions stay intact. Sick protection shows Paused/Protected text and never uses completed styling for an unperformed objective.

## Brain fixed scenarios

`Tests/Core/PersonalBrainTests.swift` has 33 meaningful test methods, with additional branches/scenarios. Fixed dates and explicit expected decisions replace long paragraph matching. `OwnerSystemPersistenceTests` covers integration, including partially complete real objectives.

| Required scenario | Expected evidence/assertion |
|---|---|
| All known muscles ready | Normal training, no imaginary inputs |
| Chest low, back ready | Recovered Pull wins |
| Poor sleep / very low sleep | Lower intensity / recovery |
| Missing sleep | Lower confidence, no invented duration |
| No recovery history | Unknown/low confidence |
| Several hard days | Reduced work/intensity |
| Five days away | Actual gap and sensible return |
| Pull underexposed | Pull wins among equal known candidates |
| Legs underexposed | Legs win among equal known candidates |
| Saved routine fits | Saved routine selected |
| Routine conflicts | Severe/recovery limits override preference |
| Equipment unavailable | Unavailable exercises excluded |
| Progression opportunity | Existing progression target |
| Plateau | Comparable exposures and effort required |
| Real daily push-up load | Push limited, no Quick Log progression |
| Partial objective | 80/100 before final 20; no duplicate load |
| Sick | Recovery protection, no session or fabricated measurements |
| Low calories | Hold load |
| Low protein | Hold load |
| New low-data owner | Limited confidence and honest missing facts |
| Brain disabled | No recommendation session |
| Active workout | Resume context, no second session |
| Recently completed workout | Reduced further work |
| Repeated acceptance | Modest bounded preference reranking |
| Repeated rejection | Modest bounded preference reranking |
| Sleep Mode | Sleep context, no pressure |
| Near-maximum reported effort | Hold load and optional targets |
| Future/expired preferences | Ignored |

Store recommendations are cached by relevant raw facts/settings, mode, equipment/preferences and foreground time bucket. Identical input skips recommendation/progression computation and duplicate history. The bucket has a one-minute tolerance and creates no timer. Foundation Models remains optional, off by default, facts-bound and independent of metric/scoring decisions.

## Semantic presentation, motion and UX

Global status colors stay exact: Excellent `#BB14F5 → #FC67E6`, Good `#57F514 → #75FC67`, Watch `#F58114 → #FCA367`, Low `#F51414 → #FC6767`; Unknown is graphite/blue-gray. Status includes text. Brain purple requires excellent known recovery and high confidence; Sleep/Sick/unknown context stays neutral. Objective percentages describe completion, not biological quality.

Progress/number transitions run on appearance or value change, then stop. Objective completion gets one bounded pulse and existing success haptic. Reduce Motion and snapshot mode use stable endpoints. Native back/cancel controls remain visible in new data/mode/objective screens; keyboard Done actions keep onboarding/reset/logging controls reachable. Identity/rank artwork and thresholds remain intact, with no new scoring system or unrelated feature scope.

## Real anatomy and energy architecture

See [ThirdPartyAnatomy.md](ThirdPartyAnatomy.md) for source, legal notices, conversion, logical mappings and exact package measurements. RealityKit loads the real 463-mesh, 345,735-triangle USDZ (8,186,398 bytes) on explicit demand. Accessible 2D fallback remains available. It is removed when offscreen/background, with no model animation, camera/motion sensors, AR tracking or networking. Unchanged material states are reused.

Sleep stores timestamps. Rest uses its absolute deadline; one foreground sleep task wakes at the deadline, canceled on background/changed state. Timeline UI ticks only while relevant and visible, with no engine recomputation per second. Local notifications schedule on deadline events; system Live Activity countdown renders exercise and next target without periodic app updates, push server or App Groups. App foreground refresh and one midnight wake replace periodic Dashboard polling. Charts/motion settle; no permanent glow loops.

The Live Activity extension is embedded and compiled with the app. Permission-denied notifications do not prevent saved rest. Physical-device notification timing, stale/rest-complete display, widget signing and force-close behavior need actual device acceptance. Instruments measurements are outstanding; architectural limits are not an energy benchmark.

## Journeys and regression acceptance

| Journey | Automated authored coverage / remaining manual acceptance |
|---|---|
| A: fresh setup → goals/equipment → Dashboard | Owner UI wizard/reset, fresh/legacy persistence; small display/Dynamic Type manual |
| B: start sleep → kill → reopen → record | Disk-backed isolated UI restart, interval/DST/replace tests; phone lock manual |
| C: recommendation → sets/rest → summary → recovery/progress | Existing Brain/training/live persistence/UI tests; full physical workout manual |
| D: full sets + Quick Log → objective completion | 80+20 and duration integration; UI 60+20 partial; verify final 40 UX on device |
| E: Sick → protected objectives/ELO → exit | Core/store mode/scoring/history assertions; device tone/navigation manual |
| F: export → hard reset → import | Codable roundtrip, malformed/unsupported/tampered/empty safety and reset/restore hosted tests; real Files picker journey manual |

Existing active workout tests retain force-close drafts, absolute rest, bodyweight/added-weight/machine/dumbbell sessions, additions/removals/substitutions, warmups, incomplete/invalid sets, discarded workouts and pending PRs. New draft validation bounds unsafe values; backup keeps the same active-workout ID and rest state.

## Verification and screenshots

Windows local result: Python infrastructure **37 passed**; static structure/delimiter/project/asset checks pass. Tree-sitter review is supplementary syntax inspection, not Swift type checking or macro validation. Native Core verifier reports **NOT RUN — Swift absent from PATH**. IOS COMPILE, native UNIT TESTS, UI SMOKE, SCREENSHOTS and FOUNDATION MODELS INFERENCE are unverified for this change until its hosted Apple run. The prior baseline's concrete Brain-settings UI navigation failure was addressed with explicit navigation and an actual settings-control readiness check; only a new Xcode run can confirm it.

The screenshot suite retains original 01–15, and adds 16_onboarding, 17_sleep_mode, 18_end_sleep, 19_daily_objectives, 20_sick_mode, 21_data_management, 22_anatomy_3d. All are actual `XCUIApplication.screenshot()` attachments; scenario 22 requires native asset load readiness. No local fake images replace them. Native current-commit clipping/safe-area/contrast/framing review is still pending those real PNGs.

Run local infrastructure with `python -m unittest discover -s Tests/Infrastructure -v`, `python tools/validate_structure.py` and `python tools/check_delimiters.py`. On compatible Mac run `bash tools/verify_on_mac.sh`; Actions also builds an unsigned device archive. Artifacts: ios-status, ios-build-and-test-results (logs/xcresults), ascend-simulator-screenshots, ascend-unsigned-device-archive, windows-core-results and verification-summary. Status stages remain distinct; an archive has its own status.

CI discipline: after pushing, check once. If queued/running, stop; do not poll or fetch screenshots repeatedly. A completed concrete failure can be fixed. Follow [iPhoneInstall.md](iPhoneInstall.md) for legitimate signing/install paths.

## Before V1 freeze

Require a green current-commit Xcode 27 run, executed native tests, all 22 real PNGs visually reviewed, signed app+extension on iPhone, full A–F journeys, live workout/restart/rest notifications/Live Activity, VoiceOver/Reduce Motion/accessibility sizes and Instruments energy/memory checks. Validate backup restore and reset using sacrificial owner data, export a recoverable owner backup, then perform only bug fixes and pixel polish. No signed IPA or successful physical-device acceptance is claimed here.
