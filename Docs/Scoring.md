# Explainable progression — version 1

ELO represents recent consistency and progress. Build 01 scoring is a configurable baseline, not a final calibrated fitness formula. Constants live in `ELOConfiguration`, not views.

| Input | Baseline points |
| --- | ---: |
| Calories within 90–110% of stored daily target | +3 |
| Protein at least 90% of stored daily target | +3 |
| Completed workout | +5 |
| Training progression (a comparable PR in Build 01) | +2 |
| Personal records | +2 each; at most three per day |
| Nutrition logged on at least three of the trailing four days | +2 |
| Positive smoothed weight momentum toward target | +3 |
| Completed objective | +2 × importance |
| Missed closed-day objective | −2 × importance |
| Explicit recovery-safe alternative | +1 for the day |

Importance factors: minor 0.5, standard 1, major 1.5. Recovery-exempt occurrences never produce a missed penalty. Missing nutrition is unknown; it is not treated as a failed target. Today's provisional score excludes still-pending objectives. ELO is clamped at zero and bounded by machine integer capacity; floor/overflow protection is included as an explanatory component so components always sum to the displayed delta.

First exercise logging establishes a performance baseline. PRs require an earlier comparable session. Volume is external load × reps, not inferred total bodyweight load. Estimated 1RM is an Epley estimate for positive loaded sets of at most 12 reps; not measured strength. Exercise catalog weights and perceived-exertion defaults are heuristic inputs to recovery.

Rank thresholds: 100/150/250 bronze; 350/450/550 silver; 650/750/850 gold; 950/1050/1200 platinum; 1350/1500/1700 diamond; 2000/2150/2400 conqueror. Divisions increase I → II → III. 0–99 is unranked. Above 2400 the rank stays Conqueror III and ELO continues increasing within integer capacity.

Goal progress is the fraction of the directed interval between goal-start weight and target, clamped to 0–100%. Equal start/target is treated as maintenance. Momentum is signed movement of seven-day-smoothed weight relative to desired pace, bounded to −100…100%; the UI's Day/Week/Month windows select 1/7/28 calendar days. This is a momentum indicator, not an adherence probability. Sparse or stale data returns no momentum. Smoothing averages each day's measurements before averaging the trailing seven calendar days. Missing measurements are never imputed.

Lifetime credits accumulate only positive finalized deltas. The lifetime level starts at one and increases per 100 credits. Negative ELO never removes lifetime progress.
