# Build 06 — Personal Brain / ASCEND Intelligence

Canonical SwiftData history and the existing Progress, Recovery, Progression, PR and Training engines feed a cached, Sendable `PersonalContext`. `PersonalBrainEngine` produces one `BrainDecision`; SwiftUI renders that decision. The optional Foundation Models provider receives fixed decision facts and no permitted scoring or training actions. Numeric targets, confidence, ELO and session selection remain deterministic. Unavailable inference, disabled opt-in and invalid model output use existing local prose fallback.

## Rules and limits

- Choose Train, Train light, Recover or Active recovery. Significant recorded muscle limits precede preference, exposure and progression. Unknown muscles retain unknown values; no inferred HRV, calorie burn, measured recovery or medical advice.
- Prefer an available, non-hidden saved routine. Recovery dominates ranking; movement and muscle exposure, favorites, familiar exercises, strength/general-fitness goal, duration and explicit preferences are smaller signals. A recent completed session supports active recovery; low sleep, frequent training or incomplete muscle history supports light work. Poor closed-day fuel and reported high effort hold progression.
- When no saved routine fits, build 2–5 available, distinct movement/family exercises with stable identifiers. Duration and goal affect size. The suggestion remains ephemeral; starting it saves an ordinary draft without creating a library routine or changing load targets automatically.
- Reuse `ProgressionEngine`; missing inputs or limits suppress targets. Plateau needs four distinct full exposures, comparable best reps/load and recorded high effort. Quick logs and warmups cannot establish a plateau. Progress, plateaus and prior performance are exposed in detail; live training gets only a compact relevant hint.
- Keep / Replace / Skip are explicit. Limited-focus replacements require available equipment and known suitable recovery. They never silently change a routine or remove completed sets.
- Session read uses completed sets, actual progression, PRs and muscle load. Day read uses the selected day's recorded totals and scored components; it never reconstructs historical recovery from today's estimate.
- Confidence falls with sparse recent sessions, unsupported recovery, missing enabled sleep/nutrition and unobserved session muscles. Turning off sleep/nutrition also removes their indirect support influence from Brain's recovery calculation. Existing Recovery and ELO engines remain unchanged.

## Local storage and preferences

`Application Support/ASCEND/personal-brain-v1.json` is an atomic, bounded archive: settings, at most 180 recommendation entries and 300 explicit preference events. Entries retain date, decision, routine/exercise IDs, confidence and response, never the large derived context. Unsupported/corrupt archives are preserved and cannot be overwritten by refresh. Failed writes retain existing memory state.

Accept/start (+2), reject (−2), explicit dismiss/ignored (−0.5), exercise choice/substitution acceptance (+1), skip/substitution rejection (−1) modestly rerank compatible options. Ninety-day history, the latest 12 relevant events and a ±6 cap bound influence. Default starter routines have stable identifiers for preference continuity before My Gym is edited; already saved routine IDs are preserved. Time passing creates no response. Deterministic daily wording varies repeated nutrition advice from a controlled set.

Settings expose Brain enable, Balanced style, 30/45/60/Flexible duration, sleep/nutrition inputs and optional existing Apple on-device explanation. Canonical refresh and explicit preference/equipment changes rebuild context; SwiftUI rendering and the rest-timer tick do not recompute decisions.

## Presentation and verification

Dashboard: rank → Today Brain → next action → signals → daily metrics and objectives. Detail exposes why, routine/generated session, readiness, progression/plateaus, exposure, known/missing data and explicit feedback. Profile exposes settings. Design V3 deepens obsidian/graphite surfaces, reduces border and ambient luminance, adds glass/ambient/inline surface roles, softens text and enriches ELO's metallic gradient. The eighteen original PNG rank assets stay byte-identical. Existing Reduce Motion, Dynamic Type and VoiceOver behavior is retained; new controls have descriptive labels and stable test identifiers.

Fixed demo history separates recent pressing from older pulling, with real home-gym exercises. DEBUG-only in-memory fixtures provide low-data and poor-sleep decision changes. New XCTest covers recovery/equipment constraints, confidence, routine/generation stability, balance, existing progression, plateau thresholds, explicit preferences, archive persistence/write failure, canonical refresh and fallback. New UI smoke covers hero/detail/start, unknown recovery and a settings-driven decision change without numeric keyboard editing.

Screenshot automation retains 01–11 and requires **12_brain_today**, **13_brain_detail**, **14_brain_low_confidence**, **15_post_workout_brain**. These are real simulator XCTest attachments; Windows does not generate stand-in screenshots. Infrastructure tests require all three smoke suites and all fifteen artifact names.

Local Windows checks pass: 34 Python infrastructure tests, 584 source/project checks, 100 Swift files with balanced lexical delimiters and diff hygiene. Thirty-two new native test methods are authored (23 portable Core, 6 hosted persistence, 3 UI smoke), with 142 methods in total. Swift is absent locally; the native Windows runner reports NOT RUN, so native Core XCTest, SwiftData, SwiftUI, Apple SDK compilation and simulator image review remain unverified until the new CI run. The pre-work latest-main run [37635199225](https://github.com/Avelicek/PROJECT-ASCEND/actions/runs/37635199225) passed on commit `1ac6411d68f70ec480a729f9d47255ca241875b6`. After pushing this build, check CI once; queued/running work is left to the lead, without polling.
