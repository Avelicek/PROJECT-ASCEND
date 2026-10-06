# Architecture and data ownership

## Five layers

1. **Raw data** lives in small SwiftData entities. Workout catalog definitions and logged muscle contributions are separated; logs retain a contribution snapshot.
2. **Deterministic engines** live in `Core/Domain`, independent of SwiftUI and SwiftData. Values crossing this boundary are immutable Sendable structs.
3. **Personal adaptation** computes observed coverage and rolling baselines. No day-one metabolic estimate or personalized muscle tolerance is invented. Recovery tolerance remains a documented neutral calibration until comparable outcome data exists.
4. **Intelligence** receives a sanitized facts-only `BrainContext` without identity or historical-write access. `BrainProvider`, `FitnessBrain`, `BrainInsight` and `BrainRecommendation` keep UI independent of the model vendor.
5. **Presentation** consumes engine reports through `AppStore`. Views own local form drafts and interaction state, not scoring or recovery calculations.

## Persistence

V1 has sixteen entities: UserProfile, BodyWeightEntry, NutritionEntry, SleepEntry, Exercise, WorkoutSession, WorkoutExercise, WorkoutSet, DailyObjective, DailyObjectiveCompletion, DailyEvaluation, ELOHistoryEntry, PersonalRecord, MuscleState, BrainInsightRecord and UserSettings.

Sessions cascade-delete exercises and sets. Catalog deletion nullifies log links while snapshots retain historical names and muscle mappings. Objectives nullify occurrence links; occurrence snapshots retain the title, importance and target. Evaluations own their ELO ledger entry. MuscleState is a reserved cache entity; reports currently derive directly from raw history.

The container explicitly disables CloudKit. Disk-open failures produce a retry screen rather than silently creating an empty replacement database. Ordinary edits validate first, then save on the main actor. Failed saves roll back and reload derived state. ModelContext autosave is disabled. Migration is prepared through a versioned V1 schema; V2 must preserve this V1 definition before changing persistent types.

## Dates and historical edits

Events retain their actual timestamp. Daily totals and objective occurrences use one Gregorian `DayPolicy` with the store's captured time zone. Keys are local `YYYY-MM-DD`; date arithmetic uses Calendar so DST does not become a 24-hour assumption. Sleep belongs to the day of waking. Bed/wake times, if supplied, determine duration.

Today is synchronized against actual logs. After midnight, recorded closed days are scored once in chronological order. There is no fabricated penalty for unrecorded days while the app is closed. A completed/missed objective is scored only when an occurrence actually exists. Weekly recurrence means the weekday of the start date, rather than a floating week-long counter.

Before settings or input changes, elapsed days are finalized under the existing configuration. Later retroactive logging updates trends and recovery but does not rewrite a finalized ELO ledger. A date earlier than the last scored date is never inserted into the ledger out of order. A future Build 02 explicit reevaluation flow would need to rebuild dependent ledger entries transparently.

Changing a target starts a new goal baseline at current recorded weight. Raw measurements remain intact. Nutrition captures its contemporaneous calorie/protein targets; editing today's profile updates today's targets, but not previous days. Current-day objective edits may update their snapshot; prior days retain theirs.

## Brain behavior

Fallback insight is available immediately. Model work runs asynchronously and is cancelled when context or preferences change. Results are accepted only for the still-current encoded context. Unavailable-model fallback may retry after a cooldown; successful responses are reused while context stays unchanged.

The Foundation Models adapter uses `SystemLanguageModel.default.availability`, `LanguageModelSession`, `@Generable`, `@Guide` and `respond(to:generating:)`. Confidence is engine-owned. Numeric fields are absent from the generated result; advisory text is length-checked, rejects decimal digits and unexpected links/markup, and action IDs must belong to the context allowlist. A model cannot change goals, objective occurrences, raw logs or ELO. Free prose remains advisory and still needs on-device quality evaluation.

API references checked online, **not against an installed Apple SDK**:

- [SystemLanguageModel](https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel)
- [Language generation](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models)
- [Generable and guided schema annotations](https://developer.apple.com/documentation/foundationmodels/generable)
- [ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- [Versioned schema](https://developer.apple.com/documentation/swiftdata/schema)

## Intentional limitations

Recovery is a heuristic, not a measured physiological state. Low confidence never causes automatic exercise replacement. The user can explicitly opt for recovery protection. Readiness stays unknown without observed sleep or training; nutrition refines those observations; a never-trained muscle is labeled “No load logged.”

The small personal store is refreshed on the main actor. Larger history should introduce bounded fetches and background snapshots after profiling on a device. Learned physiology, export/backup UI, broad catalog coverage and the anatomy artwork remain later work.
