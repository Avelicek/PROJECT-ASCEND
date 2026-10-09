# ASCEND adaptive coach update

## Architecture audit before implementation

Baseline: `9b284e9ec70be1bc993541788f6720f378ccb797`. SwiftData has 16 existing entities. WorkoutSession → WorkoutExercise → WorkoutSet is the canonical activity graph for both formal and quick sessions. Contribution snapshots preserve old exercises. An independent atomic JSON draft preserves an unfinished workout. Owner, gym and Brain archives are versioned sidecars; structured backup already includes all three and the live draft.

Reuse: catalog/equipment filtering, contribution mapping, rank assets/thresholds, day/time-zone policy, recovery decay, conservative progression, local rest deadlines/Live Activity, optional fact-constrained Foundation Models explanations, data vault and simulator capture pipeline.

Debt: daily presentation recomputed the legacy score separately from `projectedScore`; quick load ignored individual effort; generated sessions preferred saved routines; all formal sessions today suppressed further planning while quick exposure had little influence; rest default was global; the 3D view decoded the asset on every presentation and built hundreds of collision shapes. Dashboard repeated rank, Brain, next action, daily command and large metrics.

## Data contract

Do not reset any store, change its URL, clear preferences, delete activities or materialized objectives during this update. SwiftData entity shape stays unchanged. RIR is represented losslessly on the existing RPE scale (RPE = 10 − RIR; 4+ is recorded as RPE 6). New check-ins/preferences and exercise clock are optional Codable additions, absent on old archives/drafts. Existing backup payload and store identities remain compatible. Completed sets, timestamps, measurements and legacy ledger entries remain authoritative.

The new score applies to the open day and future ledger entries. Existing closed evaluations, deltas and lifetime credits are never recalculated. New evaluations identify scoring version 2. UI history reads stored ledger values; today's UI reads one event-derived score. Tests must prove these invariants on populated stores and old JSON.

## Verification baseline

Run 37768663148: real Xcode 27 Debug/Demo/Release compilation and hosted unit tests passed; 22 simulator screenshots generated; UI smoke failed. Windows Core passed. These results describe the baseline only, not this update.

## Implemented architecture and user journeys

`AppStore.refresh` derives canonical weighted loads before day finalization, then today's score, recovery, generated workout, cached weight projection and one next action. SwiftUI reads those event-derived results. Completed activity enters the existing WorkoutSession → WorkoutExercise → WorkoutSet graph exactly once, regardless of where it was logged. Ask builds a structured Codable factual context on demand. Pure Core engines have no external dependencies.

Dashboard now presents Today, signed live ELO, a qualitative day state, objective progress and one next action with a bounded simulated ELO opportunity. Rank/detail analytics and objectives expand on demand. Workout presents the generated session, a briefing with reasons and muscle focus, quick activities, then templates and history. Existing five destinations, real licensed anatomy, saved routines and manual override remain available. Check-in explicitly records known weight/sleep, feeling and soreness and then shows the resulting plan/readiness update. Sick/Sleep navigation and notification deep links preserve the active interval/session.

Active training adds per-exercise optional effort review (RIR mapped to RPE), a full-screen absolute elapsed clock with pause/resume/finish, exercise education and bounded consentful rest/load suggestions after a comparable performance drop. Rest deadlines survive suspension/relaunch; remaining-time haptics, sound, local notification and Live Activity use the existing deadline. Completion displays actual same-day stimulus before and after the saved session, with optional native muscle activation.

## ELO 2.0 algorithm

The daily result is bounded to −30…+30 before the existing nonnegative rank floor. Training is scaled to the median actual activity-day stimulus over the previous 28 days after three usable days; a goal-dependent learning baseline is used sooner. Formal training contributes up to 14 and spontaneous activity up to 6, with the two portions separated to avoid duplicate credit. Existing safe progression and real PR facts contribute small additional amounts. Nutrition uses graded calorie/protein adherence, not binary completion. Sleep, appropriate recovery decisions, recent training rhythm, check-in, fuel consistency and importance-weighted due objectives add separate explainable components. Open-day incomplete targets do not impose closed-day missed-target penalties. Recovery-only credit remains small; training against recorded recovery limits can reduce the result.

An explicit range/floor component preserves exact component-sum/ledger arithmetic. At ELO zero a negative change is floored at zero, preserving the old rank contract. All current-day surfaces read `projectedScore`; past surfaces read stored ledger values. No past +4 is recomputed to zero. New closed days carry scoringVersion 2; original version-1 snapshots remain untouched.

## Unified stimulus and safe progression

Warm-ups and zero work are excluded. Repetitions or duration are normalized, then weighted by recorded RPE/failure proximity and a bounded load ratio against the same recent exercise/mode. Quick total repetitions use a separate total-activity normalization rather than pretending 100 reps are one ordinary set. Contributions are allocated through the exercise's saved muscle snapshot, then reused for recovery decay, weekly exposure, scoring, plan selection and visual activation. These are modeled stimulus units, not measured damage, energy expenditure or medical recovery.

A difficult 60 kg session at 10/9/7 reps holds 60 kg and prescribes 10/10/8 rather than inventing 90 kg. Increases require comparable prior performance and are additionally bounded by the available increment and 5%. Low recovery reduces rep targets. A same-load rep drop below 65% of the first set after at least three sets suggests 45 seconds more rest and an optional reduction bounded to 10%; completed sets are never rewritten. Technique breakdown or continued decline is a reason to stop, not add work.

## Generated workouts and contextual objectives

The generator respects active/Sick/Sleep/recovery gates, equipment, hidden exercises, duration/frequency/goal, real recent performance, same-day spontaneous exposure, weekly muscle balance, familiarity, favorites and explicit preference history. Selection/order is deterministic and explainable. Significant same-day overlap removes or reduces pressing work after push-ups. Generated prescriptions use actual per-set history. Saved templates are neither overwritten nor treated as the default planner. Already finished formal work is not automatically followed by another demanding session.

Objective suggestions are optional one-day rules grounded in current missing inputs, fuel, generated training or recovery support. Accepting a suggestion adds a rule; it does not replace existing occurrences. Changing/archiving future schedules preserves already-materialized current-day entries and closed snapshots. No steps/bedtime/medical constraints are invented when those inputs are unsupported.

## Brain, Ask and projections

The hybrid Brain uses factual structured state plus deterministic recommendation, generation and progression engines. Ask separates observed records, modeled estimates with confidence and actionable recommendations. It handles training, recent bench/press performance, same-day muscle work, ELO components, configured fuel, readiness and weight ETA; arbitrary bodyweight targets in a question are evaluated from real weigh-ins without editing the profile. Month deadlines explicitly state their start-of-month interpretation and compare a real date range where available. Optional on-device Foundation Models produces a constrained narrative of already calculated facts. It cannot modify stored metrics or prescribe an invented load, and no API secret/backend is added.

Projection groups same-day measurements into distinct days and fits up to 21 recent days. At least six days, a seven-day span and a recent measurement are required. Flat/wrong-direction/extreme/noisy/sparse trends do not produce a precise ETA. Estimated ranges and confidence reflect coverage and residual noise. Weight goals support gaining and losing. Weekly reports use actual saved training, productive sets, check-ins, sleep and weight/score trends and explain how the current generator responds.

## Measurement modes and education

The presentation layer describes load/reps, bodyweight reps, duration, distance, distance/duration, observed calories/duration, holds and custom quantity/duration while retaining the four historical raw TrackingMode values. Distance records retain actual elapsed time. Plank, wall sit, dead hang and other holds use the dedicated clock. Supplementary observed calories/custom values on newly logged activities use a versioned JSON annotation in the existing session notes field; old notes are untouched, backups already preserve it, and history displays the observation. Arbitrary units never become fabricated calories or muscle load.

All 150 catalog entries have movement-pattern looping illustrations, contributions, equipment, concise setup/execution instructions and cues. Distinct supported setups distinguish push-ups, bench/machine presses, carries, hip thrusts and seated lower-body work. Reduce Motion, background state and capture endpoints pause loops. The loops are schematic movement-pattern guides, not individualized technique assessment or full anatomical skeletal animation.

## Native anatomy and brand

RealityKit remains the native renderer, with one asynchronously decoded, normalized template and independently positioned clones sharing mesh/material resources. The cache preloads on Body entry, shares concurrent loading and evicts on memory warning. Renderers/cameras are not kept after dismissal. Cheap bounded collision shapes replace expensive repeated generated shapes. Orbit, two-finger pan, bounded zoom, front/back/side and reset use the same coordinator; lighting/FOV and camera starting orientation were refined. Model materials pulse at contribution-relative intensities for education, planned work and completed activity. The source USDZ, attribution, mapping and license remain intact.

A native cache test verifies a second presentation does not decode again, returns independent scene graphs and reports first/warm clone times. Physical-device FPS and memory have not been measured by this test. The existing static anatomical asset has no skeleton: contribution illumination animates, while movement demonstrations use the schematic loop. No rigged anatomical push-up is claimed.

The original three-plane ASCEND ascent mark is authored in native SwiftUI Shape, editable SVG and an opaque 1024-pixel iOS AppIcon. It appears in launch, Dashboard and coach identity. Original 18 rank images remain byte-identical. App/widget versions advance together to 1.1.0 (2).

## Notifications

Explicit Profile permission flow and per-category preferences control a seven-day local reminder horizon, default morning at 08:00 with one later follow-up, at most one contextual evening action, weekly report and rest completion. Check-in cancels today's pending morning/follow-up pair. Foreground and meaningful store revisions rebuild factual reminders; no permission prompt is fired at launch. Deep links open check-in, workout, fuel, objectives, recovery, goal progress or the active sleep interval. Future weekly messages do not embed a stale current-day score.

## Tests and verification in progress

Critical authored tests cover current-day activity/weight/objective/draft restoration, immutable legacy +4, version-2 daily backups, single-score presentation, quick activity → plan adaptation, effort-weighted stimulus, muscle allocation, bounded progression/rest/autoregulation, absolute clocks, old Codable archives, projections, arbitrary requested targets/deadlines, annotation backups and cache clone reuse. UI smoke covers the existing product plus check-in/Ask/quick activity/timed exercise journeys. Capture automation requires 29 named simulator PNGs and preserves XCTest bundles/provenance.

Local infrastructure: 37 Python tests pass. Static checks and balanced delimiters are recorded separately from native compilation. First real run 37917470326 and duplicate 37918434243 exposed stale legacy summary expectations and Apple compiler issues in optional objective navigation, explicit closure captures and notification actor isolation. Those issues were corrected; the next exact-commit run will establish native/test/capture evidence. This report does not equate static checks or old screenshots with a successful updated app.

## Known limits and remaining acceptance

Recovery/ETA/stimulus are modeled estimates. No unsupported injury/steps/body-composition metrics or precise strength-goal ETA is fabricated. Foundation Models inference requires a compatible configured physical device; deterministic fallback remains functional. The anatomical mesh is unrigged and its movement loop is schematic. Owner iPhone production storage is not available from Windows; preservation is verified through populated-store/backup tests and unchanged persistent shape, not by claiming to inspect that phone. Signed installation, notification delivery while locked and physical-device graphics performance need real-device acceptance. Native results and actual screenshot inspection remain pending until the final Actions run finishes.

## Exact modified files and commits

The final file manifest, verification run and code commit are recorded after the last implementation fix. Baseline is `9b284e9ec70be1bc993541788f6720f378ccb797`; initial implementation is `3b14bc53277408f7993f6216092cd001993973d4`.
