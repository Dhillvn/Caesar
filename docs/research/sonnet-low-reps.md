# Sonnet-low vs Opus-low, repped (#64)

Follow-up to #56/#60. #56 found the Execute tier's economics backwards at
**medium**: Sonnet medium ($0.3765, n=2) cost *more* than Opus medium
($0.3246, n=2) on the same task, while capability held everywhere. The one
cheap cell — `taskB-sonnet-low` at $0.2248 — was **n=1**. This ticket reps
`*-sonnet-low` and adds matching `*-opus-low` cells to check whether low
effort, not medium, is where Sonnet's discount actually shows up.

Rig, fixtures and graders reused unmodified from
`ticket-64-1852/.scratch/` (itself descended from `ticket-56-4290`). Model
and effort verified per cell off `modelUsage` and the transcript `effort`
key — never a self-report (script output below). Cost/turns read from each
cell's own `result.json` aggregate, not summed from transcript records.

## Per-cell table

All cells: effort=low, model/effort verified match, `terminal_reason=completed`.

### Task A — defect-finding (grade = defects found / 5, false positives noted)

| Cell | Model | Cost | Turns | Grade |
|---|---|---|---|---|
| taskA-opus-low | opus | $0.3221 | 6 | 5/5 |
| taskA-opus-low-rep2 | opus | $0.3221 | 6 | 5/5 |
| taskA-opus-low-rep3 | opus | $0.3013 | 5 | 5/5 |
| taskA-sonnet-low | sonnet | $0.3606 | 5 | 5/5 |
| taskA-sonnet-low-rep2 | sonnet | $0.2430 | 5 | 5/5 |
| taskA-sonnet-low-rep3 | sonnet | $0.2730 | 6 | 5/5 |
| taskA-sonnet-low-rep4 | sonnet | $0.2734 | 6 | 5/5 |

n=3 opus, n=4 sonnet. Zero false positives on any cell, either model.

### Task B — frontier-finding (grade = maps passed / 2, seen + held-out)

| Cell | Model | Cost | Turns | Grade |
|---|---|---|---|---|
| taskB-opus-low | opus | $0.4212 | 5 | 2/2 |
| taskB-opus-low-rep2 | opus | $0.3146 | 5 | 2/2 |
| taskB-opus-low-rep3 | opus | $0.3167 | 7 | 2/2 |
| taskB-sonnet-low | sonnet | $0.2248 | 6 | 2/2 |
| taskB-sonnet-low-rep2 | sonnet | $0.4594 | 12 | 2/2 |
| taskB-sonnet-low-rep3 | sonnet | $0.2525 | 8 | 2/2 |
| taskB-sonnet-low-rep4 | sonnet | $0.2503 | 8 | 2/2 |

n=3 opus, n=4 sonnet.

One `taskA-opus-low-rep2` attempt from the prior session died with an empty
`result.json` (no `session_id`, nothing billed) and is excluded, not counted
toward n. It was replaced by a fresh synchronous rep (labelled `-rep2b` on
disk, `-rep2` above) to reach n=3.

## Means (n≥3 every cell, grade held at 100% throughout)

| Config | n | Mean cost | Mean turns |
|---|---|---|---|
| Task A, opus-low | 3 | **$0.3152** | 5.7 |
| Task A, sonnet-low | 4 | **$0.2875** | 5.5 |
| Task B, opus-low | 3 | **$0.3508** | 5.7 |
| Task B, sonnet-low | 4 | **$0.2968** | 8.5 |

Sonnet-low beats opus-low on cost on **both** fixtures: 8.8% cheaper on
Task A, 15.4% cheaper on Task B. Grade is identical (100%, zero false
positives) at every n on both models. Sonnet-low is also cheaper than the
Sonnet-*medium* cell #56 measured ($0.3765) — the discount #56 predicted
but couldn't find at medium shows up once effort drops to low, at no
capability cost across 7 graded sonnet-low cells and two independent tasks.

Turns tell the other half: sonnet-low takes visibly more round trips on
Task B (mean 8.5 vs opus's 5.7, one cell ran to 12 turns) and still lands
cheaper per-turn cost is low enough that the extra turns don't erase the
per-token discount, at this effort. That headroom is worth watching if
Task B-style work gets harder — more turns at medium is exactly what put
Sonnet behind Opus in #56.

## Verdict

**Yes — Sonnet at low effort beats Opus at low effort on cost, at equal
(100%) grade, n≥3 on both fixtures for both models (n=4 for sonnet, meeting
the ticket's n≥4 bar).** The Execute row in `skill/SKILL.md` should move
from `medium` to `low`: `low` is cheaper than `medium` on the same model
*and* cheaper than Opus at the same effort, with no grade cost measured
anywhere in 14 cells across #56 and this ticket.

**Not adopted.** Raj held Execute at `medium` on 2026-08-05. The cells here
are sub-$0.45 toy fixtures; real tickets on this map ran $1.58–$2.85, so the
discount is unproven at working length, and the rubric keeps one live dial.
The measurement stands; the tier did not move.
