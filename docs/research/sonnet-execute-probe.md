# Does a Sonnet centurion finish an Execute-tier ticket, and for how much?

Ticket [#56](https://github.com/Dhillvn/caesar/issues/56). Measured 2026-08-05.

This is the measurement residual left after [#58](https://github.com/Dhillvn/caesar/issues/58)
mined the published evidence and [#51](https://github.com/Dhillvn/caesar/issues/51) settled the
dispatch rubric. #51 retracted #58's claim that published sources "flip the Sonnet prior":
Artificial Analysis compares Opus 5 at high/xhigh against **Sonnet 5 at max effort** on hard
tasks. Nothing published compares Sonnet 5 at **low or medium** effort on **easy, closed-spec**
work. That gap is where the Execute tier lives, and it is what this run measures.

## What was run

All cells come from the rig built by the halted first #56 run, preserved at
`.claude/worktrees/ticket-56-4290/.scratch/` and copied unmodified into this worktree.
Twelve cells already existed; four were added here (`taskA-opus-high`,
`taskA-sonnet-medium-rep2`, `taskB-opus-medium-rep2`, `taskB-sonnet-medium-rep2`).

Every cell was fired as:

```
claude -p --output-format json --model <model> --effort <effort> \
       --permission-mode bypassPermissions --max-budget-usd 1.00 < .prompt.txt
```

No settings file and no spawn script was changed. `--bare` was never used, so costs are
against subscription-auth reality ([#7](https://github.com/Dhillvn/caesar/issues/7)).

**The two fixtures.**

- **taskA — audit.** Read `RULE.md` (the four clauses of the PowerShell rule) and two seeded
  PowerShell scripts; write `ANSWER.md` naming each violation as `<file>:<line> | clause <N> |
  <mechanism> | <failing input>`. Five defects are seeded; correct code is present as bait and
  flagging it counts against the cell. This is a *judgement* task — the spec names the artifact
  but not the answer.
- **taskB — build.** Write `frontier.ps1` that prints the READY ticket numbers of a Wayfinder
  map, one integer per line, ascending, nothing else. The prompt names the artifact, the exact
  invocation, and five specific edge cases it must survive. It is graded by executing the script
  against `map.md` and a **held-out** `map2.md` the cell never saw. **This is the Execute-tier
  shape**: a closed spec that names the artifact and the acceptance check.

**Verification.** Model was taken from `modelUsage` and effort from the `effort` key on
assistant records in the session transcript, per cell — never a self-report. All 16 cells
matched what was asked and all terminated `completed`. Cost, turns and wall time are read from
each cell's `result.json` (`total_cost_usd`, `num_turns`, `duration_ms`), which are harness
aggregates and so are **not** affected by the transcript duplication
[#60](https://github.com/Dhillvn/caesar/issues/60) found (assistant messages written 2-4x with
an identical `usage` block, median 2.17x inflation). No number here is derived by summing
transcript records.

Run records are in `.scratch/rig/runs/<cell>/result.json`; session ids are given per row below.

---

## Probe 1 — is Haiku 4.5 dispatchable via `claude -p --model`? **Yes.**

`claude -p --model claude-haiku-4-5-20251001` completed normally:
`is_error: false`, `num_turns: 1`, `terminal_reason: completed`, `stop_reason: end_turn`,
`modelUsage` keyed on `claude-haiku-4-5-20251001` with `canonicalModel: claude-haiku-4-5`,
`provider: firstParty`. Session `79ce7ea6`. Record: `.scratch/probe/haiku.json`.

It was **not free**: `total_cost_usd: 0.0255636` for a one-word reply, on 10 input tokens,
129 output tokens, 15,546 cache-read and 11,677 cache-creation tokens. The floor cost of a
dispatch is the system prompt and tool schemas, not the task.

This is the contrast case to the already-banked `--model opus-5` probe, which failed loud and
free (HTTP 404, `is_error: true`, `total_cost_usd: 0`, empty `modelUsage`). A dispatchable
model bills; an undispatchable one 404s. n=1 each.

## Probe 2 — does Sonnet land the Execute-tier artifact? **Yes, every time. It did not cost less.**

taskB, graded by executing the produced script against the seen map and the held-out map.

| cell | passed | extra files | cost | turns | wall | session |
|---|---|---|---|---|---|---|
| taskB-sonnet-low | 2/2 | 0 | $0.2248 | 6 | 41.7s | `f167e14f` |
| taskB-sonnet-medium | 2/2 | 0 | $0.3828 | 9 | 40.4s | `237178b7` |
| taskB-sonnet-medium-rep2 | 2/2 | 0 | $0.3702 | 8 | 30.6s | `6459ca63` |
| taskB-sonnet-high | 2/2 | 0 | $0.4039 | 16 | 79.3s | `a277ba43` |
| taskB-opus-low | 2/2 | 0 | $0.4212 | 5 | 37.6s | `37db8a96` |
| taskB-opus-medium | 2/2 | 0 | $0.3279 | 7 | 33.7s | `061b56ad` |
| taskB-opus-medium-rep2 | 2/2 | 0 | $0.3213 | 7 | 29.7s | `20cbc00f` |
| taskB-opus-high | 2/2 | 0 | $0.3320 | 7 | 43.5s | `7b34a855` |

**Completion is not the discriminator.** Eight of eight cells produced a working
`frontier.ps1` that passed the held-out map, at every effort, on both models, with no stray
files. On work where the thinking is already done, Sonnet lands the artifact.

**Cost is the discriminator, and it points the wrong way.** At medium effort, n=2 each:
Sonnet mean **$0.3765** (8.5 turns), Opus mean **$0.3246** (7 turns). Sonnet was **~16% more
expensive than Opus on the same closed-spec task**, despite Sonnet's ~1.67x cheaper token
price ([#50](https://github.com/Dhillvn/caesar/issues/50)). The two reps are tight within each
model ($0.3702–$0.3828 and $0.3213–$0.3279), so this is not one noisy cell.

The mechanism is turn count, not token price: Sonnet took 8–9 turns to Opus's 7, and its
cumulative cache-read was 261–264k tokens against Opus's 140k. A weaker configuration paying
for more round trips is exactly the failure mode #55 warned the 1.67x ratio could hide. I did
not decompose `total_cost_usd` against published per-token rates, so I am reporting the
harness's own cost figure, not a reconstruction of it.

**The one place Sonnet is cheaper is low effort**: $0.2248, 6 turns, 2/2 — the cheapest
successful cell on the board, 31% under the best Opus cell. If an Execute tier is worth having,
this is the cell that justifies it, and it rests on **a single observation**.

## Probe 3 — does low effort cut turn count? **Yes, monotonically, in all four series.**

Extracted from existing run records plus the four new cells; no run was fired for this probe.

| series | low | medium | high |
|---|---|---|---|
| taskA-sonnet | 5, 5 | 6, 6 | 6 |
| taskA-opus | 6 | 6 | 6 |
| taskB-sonnet | 6 | 9, 8 | 16 |
| taskB-opus | 5 | 7, 7 | 7 |

Turn count is non-decreasing in effort in every series, and strictly increasing in three of
four. The size of the effect is model-dependent and large for Sonnet on the build task:
6 → 8.5 → 16 turns from low to high, a 2.7x spread, against Opus's flat 5 → 7 → 7. No
published source reports turns against effort; this is the first number Caesar holds on it.

Note that fewer turns did **not** mean lower cost universally — `taskB-opus-low` took the
fewest turns of any cell (5) and was the **most expensive** ($0.4212). Turns and cost are
separate axes and should not be used as proxies for each other.

## Probe 4 — medium vs high (row 6). Measured, since budget allowed.

| task | model | medium | high | grade change |
|---|---|---|---|---|
| taskA | sonnet | $0.3099 / $0.3797 | $0.4203 | 4/5, 5/5 → 5/5 |
| taskA | opus | $0.3518 | $0.4298 | 5/5 → 5/5 |
| taskB | sonnet | $0.3828 / $0.3702 | $0.4039 | 2/2 → 2/2 |
| taskB | opus | $0.3279 / $0.3213 | $0.3320 | 2/2 → 2/2 |

High costs more in all four series (+2% to +22%) and bought no measured grade improvement in
any of them. The single 4/5 in the whole 16-cell board is `taskA-sonnet-medium`; its repeat
scored 5/5, so that miss is noise at n=2, not an effort effect. This is consistent with #51's
structural decision to default to medium; it does not independently prove it, because neither
fixture is hard enough to separate the two.

## taskA, for completeness (judgement task, not Execute-tier)

| cell | found | false positives | cost | turns | wall | session |
|---|---|---|---|---|---|---|
| taskA-sonnet-low | 5/5 | 0 | $0.3606 | 5 | 47.0s | `1f67864e` |
| taskA-sonnet-low-rep2 | 5/5 | 0 | $0.2430 | 5 | 54.4s | `50537c2f` |
| taskA-sonnet-medium | 4/5 | 0 | $0.3099 | 6 | 82.7s | `f78ed6e6` |
| taskA-sonnet-medium-rep2 | 5/5 | 0 | $0.3797 | 6 | 111.9s | `6c34083f` |
| taskA-sonnet-high | 5/5 | 0 | $0.4203 | 6 | 145.2s | `bbc84899` |
| taskA-opus-low | 5/5 | 0 | $0.3221 | 6 | 40.6s | `65b30b49` |
| taskA-opus-medium | 5/5 | 0 | $0.3518 | 6 | 47.5s | `a7540d3a` |
| taskA-opus-high | 5/5 | 0 | $0.4298 | 6 | 76.7s | `79612d26` |

Zero false positives anywhere — no cell flagged the correct code planted as bait. Sonnet at
low is the cheapest 5/5 on this task too ($0.2430), but its sibling rep cost $0.3606 for the
same score, so the low-effort cost figure is unstable at n=2.

---

## What this settles, and what it does not

**Supported:** a Sonnet centurion *finishes* a closed-spec ticket. 8/8 taskB cells and 7/8
taskA cells graded clean, all `terminal_reason: completed`, all verified as the model and
effort asked for. The worry that a weaker configuration would fail and cost a retry, a flag
and Raj's attention did not materialise on either fixture at any effort.

**Contradicted:** the assumption that the Execute tier saves money by virtue of Sonnet's token
price. At the default effort (medium) Sonnet cost **more** than Opus on the Execute-shaped
task, n=2 each, reproducibly, because it spends more turns. #50's 1.67x is a token-price ratio
and this run confirms it does not survive contact with a real multi-turn run.

**Still untested — the load-bearing gaps:**

1. **Sonnet-at-low is the whole case for the tier, and it is n=1.** $0.2248 is the only
   measurement that makes an Execute tier pay. Before it is built into the rubric it needs
   reps.
2. **Nothing here ran through `spawn-ticket-agent.ps1`.** These are bare `claude -p` cells in a
   scratch directory. The end-to-end dispatch — unattended completion, self-close, PR opened,
   `git` and `gh` in hand — remains unmeasured at Sonnet, and that is the transfer this ticket
   was written to close. It was cut for budget.
3. **Both fixtures are small.** Every cell finished in under 2.5 minutes and under $0.45. A
   real Caesar ticket runs longer and holds more context, and turn-count divergence compounds
   with length — Sonnet's 2.7x turn spread on taskB is the warning sign. The cost gap measured
   here is a floor, not a ceiling.
4. **Haiku was proven dispatchable, not proven capable.** No Haiku cell was graded on either
   fixture.
