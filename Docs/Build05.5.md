# Build 05.5 — Personal home gym training

My Gym edits environment, goal, preferred session length and 19 equipment choices. A real new profile starts with bodyweight only. Adjustable dumbbells satisfy dumbbell requirements; compound requirements such as barbell + bench must all be present.

The catalog contains 149 stable exercise IDs. Search, muscle/equipment/bodyweight/availability filters, favorites, hidden entries and recent history feed both the library and live picker. Muscle contributions are reviewed movement-role load heuristics, not measured activation percentages. Existing exercise rows and logged contribution snapshots are preserved.

Routines support creation, editing, order, sets, optional reps, rest, duplication and deletion. Four editable starter routines are supplied. Unavailable exercises stay visible and block starting; deterministic substitutes consider pattern, focus, anatomical roles, family, tracking and actual equipment. Finished sets cannot be overwritten by a live replacement.

Bodyweight inputs show reps first, with optional added load. Records distinguish comparable reps, total session reps, most added weight and added-load × reps. Body mass is never invented as external load or a loaded 1RM. Optional rep/set/variation suggestions require comparable history and respect recovery limits.

Personal preferences and routines use atomic `Application Support/ASCEND/personal-training-v1.json` writes. Missing files and absent fields receive safe defaults; an explicitly empty routine list stays empty. Unreadable/unsupported files are preserved. SwiftData V1 remains unchanged; old history and active drafts remain valid. Demo stores keep all personal state in memory.

Home-gym demo sessions use chest press, lat pulldown, dumbbell row, lateral raises and push-ups. Screenshot scenarios 01–08 are retained; live training now shows lat pulldown. Added scenarios: `09_exercise_library`, `10_routine`, `11_exercise_history`. All images must come from real simulator XCTest attachments.

Verification: project generation, structure/delimiter checks, infrastructure unittest suite and `git diff --check` run locally. New portable/core and hosted persistence tests cover metadata, availability/filtering, substitutions/families, bodyweight progression/records, routine start, safe persistence and retained history. Two UI smoke tests cover My Gym, favorites, routine start, adding/replacing a bodyweight exercise and completing its set. The existing CI retains strict concurrency and warnings-as-errors. After push, inspect CI once and leave a queued/running job for the lead; Windows checks do not establish Apple compilation or simulator behavior.
