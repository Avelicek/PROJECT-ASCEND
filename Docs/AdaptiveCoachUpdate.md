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

Implementation and final verification details are added below as work completes.
