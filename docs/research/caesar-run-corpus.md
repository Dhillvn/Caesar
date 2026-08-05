# What Caesar's real tickets have actually cost

Research ticket [#55](https://github.com/Dhillvn/caesar/issues/55). Read-only mining of the
headless run artifacts already on disk. Every number below is parsed from a result JSON; nothing
here is estimated, modelled, or reconstructed from memory.

## The headline, first

**Caesar's own repo does not have a corpus.** The premise of #55 — "roughly 40 issues' worth of
dispatches from the map that built Caesar" — is not true on disk. `C:\Users\rajdh\Projects\caesar\.claude\caesar-runs\`
holds **five** result JSONs, of which **two** parse and **one** is a real ticket. Most of the Caesar
map was driven by hand, not through `spawn-ticket-agent.ps1`, so it left no artifact. **A cost table
for Caesar ticket types built on n=1 would be worthless, and this document does not build one.**

What *does* exist is a much larger corpus of headless runs from the same spawn script, the same
harness and the same Wayfinder guardrail prompt, dispatched against Wayfinder maps in five sibling
repos: **119 parseable runs, 101 of them completed.** That is a different population — different
codebases, different domains — and it is labelled as such throughout. It is, however, the only real
evidence available for the budget question, and it answers that question decisively.

The budget answer, up front: **the `-BudgetUsd 2.0` default sits at the 55th percentile of real
completed-run cost. It would have truncated 46 of 101 completed runs mid-work.** 17 runs in the
corpus already died on a cap, burning **$56.44 — 20% of all spend — for zero artifact.**
**Recommended cap: `$5.00`** (p97 of completed cost; would have killed 3 of 101).

## Corpus and method

Parsed every `*.json` under `<repo>\.claude\caesar-runs\` for all eight local project checkouts.
Each run was joined to its ticket by extracting the issue URL from the sibling `*.prompt.txt`
(the filename's ticket number is unreliable — several runs were spawned from a worktree in a
*different* repo than the issue they targeted), then to the issue's `wayfinder:*` label via
`gh issue list --json number,title,labels`. **URL resolution: 119/119. Label join: 119/119.**

| | count |
|---|---|
| result JSONs on disk | 127 |
| zero-byte (run killed or still in flight) | 8 |
| unparseable / malformed | 0 |
| **parsed** | **119** |
| — `terminal_reason: completed` | 101 |
| — `terminal_reason: budget_exhausted` | 17 |
| — `terminal_reason: api_error` (HTTP 429) | 1 |
| throwaway-titled tickets | 1 (`caesar#21`) |
| distinct tickets covered | 112 |

Runs by source repo of the *ticket* (not the worktree): numen-ops 82, numen-vsl 17,
numen-edit-smoke 11, dan-claude-course 7, **caesar 2**.

The 8 zero-byte files are not corruption: they are runs whose process died before writing, plus
this ticket's own in-flight run. One is a genuine failure with a recoverable cause — `caesar`'s
`ticket-21-9740` stderr reads `error: unknown option '---\nThis'`, the argv-shredding bug the
spawn script's stdin fix later cured. Nothing was silently dropped from the analysis.

## Cost distribution

All figures USD, `total_cost_usd`, subscription auth.

| population | n | min | p25 | median | p75 | p90 | p95 | max | mean | total |
|---|---|---|---|---|---|---|---|---|---|---|
| all parsed | 119 | 0.27 | 1.58 | 2.03 | 2.94 | 3.87 | 5.02 | 6.41 | 2.38 | $282.83 |
| **completed** | **101** | **0.27** | **1.49** | **1.91** | **2.77** | **3.62** | **4.28** | **6.41** | **2.23** | **$224.99** |
| budget_exhausted | 17 | 2.01 | 2.03 | 3.05 | 4.04 | 5.45 | 6.04 | 6.05 | 3.32 | $56.44 |

Completed-run wall clock: median 6.5 min, p90 12.6 min, max 112 min. Completed-run turns:
median 29, max 77.

**The completed distribution is right-censored.** Every run that would have cost more than its cap
appears in the *exhausted* row instead, so the true cost of a hard ticket is higher than p90 = $3.62
suggests. Treat the completed percentiles as a floor on the tail, not a description of it.

## Cost by ticket type — and why the table should not be split by type

Completed runs only, `wayfinder:*` label from the issue.

| type | n | min | median | IQR | p90 | max | median turns |
|---|---|---|---|---|---|---|---|
| task | 76 | 0.55 | 1.96 | 1.64 – 2.93 | 3.81 | 6.41 | 34 |
| research | 23 | 0.87 | 1.58 | 1.39 – 2.54 | 2.97 | 3.59 | 24 |
| grilling | 1 | 2.63 | — | — | — | 2.63 | 10 |
| (no label) | 1 | 0.27 | — | — | — | 0.27 | 5 |

Budget-exhaustion rate by type, all runs: task **12/89**, research **5/28**. Statistically
indistinguishable at these n.

**Finding: type does not predict cost usefully.** `task` runs a little dearer than `research`
(median $1.96 vs $1.58) but the interquartile ranges overlap across almost their whole width
($1.64–$2.93 against $1.39–$2.54), and research's max ($3.59) sits inside task's IQR-to-max span
rather than below it. The variation *within* a type dwarfs the variation *between* types. Per #55's
own framing, this is the finding that argues **against** splitting a frozen dispatch table by ticket
type: one default, applied to every AFK type, loses nothing the data can detect. `grilling` and
`prototype` are effectively unmeasured (n=1 and n=0) — they interrupt the human anyway, so they are not on the AFK dispatch path.

## The budget cap

### What the artifacts can and cannot tell you about the cap in force

`spawn-ticket-agent.ps1` returns `BudgetUsd` on its output object but **never writes it to disk**,
and `--max-budget-usd` does not appear in the result JSON. **The cap in force on any historical run
is not directly recoverable.** For completed runs it is only lower-bounded by the observed cost.

For *exhausted* runs it can be inferred, because cost lands just above the cap. The 17 exhausted
costs are:

```
2.0054 2.0165 2.0253 2.0320 2.0344 2.0536 2.2064 2.5424 3.0500
3.0613 3.2007 4.0157 4.0383 5.0195 5.0472 6.0429 6.0452
```

Flooring each to the nearest plausible cap gives **$2.00 × 7, $2.50 × 1, $3.00 × 3, $4.00 × 2,
$5.00 × 2, $6.00 × 2** — confirming #55's suspicion that caps varied, and that the $2.00 default was
in force for at least 7 of them. **The cap is soft: overshoot ran up to 10.3%** (a $2.00 cap billed
$2.2064), because the budget check fires between turns, not mid-turn. Any cap you set, budget for
~10% more.

### What a cap costs you when it fires

**All 17 exhausted runs have an empty `result` string.** A killed run produces no resolution
comment, no GIST, and no reviewable artifact. The $56.44 spent on them bought nothing —
**20.0% of all headless spend in this corpus.**

Only 4 of the 17 were retried; all 4 succeeded on the retry, at a combined ticket cost of
$3.03 / $5.40 / $7.22 / $7.61 for what one adequately-capped run would have delivered once. The
other 13 were abandoned. So a too-low cap does not save money — it pays full price for nothing,
and then pays again.

### Candidate caps

Percentile is of the 101 completed-run costs; "kills" counts completed runs whose actual cost
exceeded the cap and which would therefore have been truncated instead of delivering.

| cap | percentile of completed cost | completed runs it would have killed |
|---|---|---|
| $2.00 *(current default)* | p54.5 | **46 / 101 (45.5%)** |
| $2.50 | p64.4 | 36 / 101 (35.6%) |
| $3.00 | p81.2 | 19 / 101 (18.8%) |
| $3.50 | p88.1 | 12 / 101 (11.9%) |
| $4.00 | p94.1 | 6 / 101 (5.9%) |
| $4.50 | p96.0 | 4 / 101 (4.0%) |
| **$5.00** | **p97.0** | **3 / 101 (3.0%)** |
| $6.00 | p99.0 | 1 / 101 (1.0%) |
| $6.50 | p100 | 0 / 101 |

This is a counterfactual in one specific way: it assumes a run truncated at $X would still have
cost what it actually cost. That holds for the completed runs (their cost is observed) but the
101 are themselves censored, so the real kill rate at every cap is **at least** the figure shown.

### Recommendation

**Set `-BudgetUsd` to `5.00`.** It is p97 of observed completed-run cost, would have killed 3 of
101 historical completed runs, and — allowing the measured 10.3% overshoot — bounds worst-case real
spend at about $5.50 per ticket.

The reasoning is asymmetric, not conservative: a cap that fires costs its *full* value and returns
nothing, so the loss from a too-low cap is the whole budget plus a retry, while the loss from a
too-high cap is only the tail runs' genuine extra cost. At $5.00, median spend is unaffected — the
median run still costs $1.91, and 97% of runs never touch the cap. **The cap's job is to stop a
runaway, not to shape normal spend.** $2.00 is not a runaway guard; at p54.5 it is a coin flip on
every ticket.

If Raj wants a tighter number, $4.00 (p94.1, 6 kills) is the defensible floor. Anything at or below
$3.00 puts one ticket in five into the "paid full price, got nothing" bucket.

## Failure correlated with cost or model

- **There is no independent failure signal in this corpus.** All 18 `is_error: true` runs are
  accounted for by budget (17) and one HTTP 429 (`numen-ops#150`, `api_error_status: 429`, $1.41,
  24 turns). No run failed on its own merits while completing. So "did expensive runs fail more?"
  reduces to "did expensive runs hit the cap?" — tautologically yes, and it is the cap doing the
  killing, not the expense.
- **Model billed:** opus-5 alone in 97 runs; opus-5 + sonnet-5 in 14; with haiku-4.5 in 8. Every
  run was billed Opus as the driver — the corpus contains **zero** Sonnet-driven ticket runs, so it
  cannot speak to the model question at all. The secondary models are subagent spend.
- **Subagent use is not the cost driver.** Completed opus-only runs: n=83, median $1.86. Completed
  multi-model runs: n=18, median $2.33. Overlapping, and the multi-model set has the *lower* max
  outside one outlier.
- **`num_turns` is unreliable on aborted runs.** Two exhausted runs report `num_turns: 1` while
  billing $3.20 and $4.02. Do not use turn count as a proxy for work done on a run that did not
  complete.

## What this corpus cannot answer

Named explicitly, because a gap stated is a result and a gap papered over is a trap.

1. **Anything about Caesar's own ticket types.** n=1 real Caesar run (#50, research, $1.44). The
   per-type table above is borrowed from sibling repos and should be read as "Wayfinder tickets in
   general", never as "Caesar tickets".
2. **The effect of `--effort`.** No historical run varied it, and #50 established effort is not
   recorded in the result JSON at all. **Only a controlled experiment can settle this** — two
   ticket-sized runs on identical work at different effort levels.
3. **The effect of `--model`.** Every run in the corpus was Opus-driven. There is no Sonnet ticket
   run anywhere on disk, so the corpus cannot compare quality or cost by model on real work. #50's
   flat 1.67× Opus:Sonnet rate is an arithmetic ratio on token prices, not an observation that
   Sonnet finishes real tickets more cheaply — a Sonnet run that needs more turns could cost more.
   Also needs an experiment.
4. **The cap actually in force on the 101 completed runs.** Not persisted anywhere. Fixable going
   forward: have the spawn script write `BudgetUsd` into the caesar-runs record (this is the same
   gap #50 flagged for effort, and one change closes both).
5. **Whether a killed run was close to done.** Empty `result`, unreliable `num_turns`. The 13
   abandoned exhausted runs cannot be assessed for how much was lost.
6. **Prototype and grilling cost.** n=0 and n=1. Not on the AFK dispatch path, so this is a gap
   that likely never needs closing.
7. **Whether cost transfers across codebases.** The 117 non-Caesar runs come from repos with their
   own CLAUDE.md, skills and context size — and #50 showed context loading alone sets a $0.24–$0.40
   floor before any work. The budget recommendation is robust to this (it is a tail guard, and the
   tail is driven by turn count, not startup context) but a per-type median is not.

## Appendix: full run table

119 parsed runs, sorted by ticket. `min` is wall-clock duration.

| ticket | type | model(s) billed | cost USD | turns | min | terminal_reason | subtype |
|---|---|---|---|---|---|---|---|
| Dhillvn/caesar#21 | (no wayfinder label) | opus-5 | 0.2709 | 5 | 0.5 | completed | success |
| Dhillvn/caesar#50 | research | haiku-4.5,opus-5 | 1.4391 | 33 | 6.6 | completed | success |
| Dhillvn/dan-claude-course#2 | research | haiku-4.5,opus-5 | 1.7231 | 28 | 4.3 | completed | success |
| Dhillvn/dan-claude-course#3 | research | opus-5 | 1.2638 | 24 | 4.0 | completed | success |
| Dhillvn/dan-claude-course#7 | task | opus-5 | 1.6660 | 28 | 5.3 | completed | success |
| Dhillvn/dan-claude-course#8 | task | opus-5 | 1.3146 | 23 | 4.3 | completed | success |
| Dhillvn/dan-claude-course#9 | task | opus-5 | 1.4668 | 25 | 4.9 | completed | success |
| Dhillvn/dan-claude-course#10 | task | opus-5 | 1.6545 | 29 | 5.6 | completed | success |
| Dhillvn/dan-claude-course#11 | task | opus-5 | 1.9131 | 23 | 5.7 | completed | success |
| Dhillvn/numen-edit-smoke#6 | research | opus-5 | 1.5111 | 24 | 5.3 | completed | success |
| Dhillvn/numen-edit-smoke#7 | task | opus-5 | 0.9948 | 19 | 2.3 | completed | success |
| Dhillvn/numen-edit-smoke#7 | task | opus-5 | 2.0320 | 32 | 16.4 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-edit-smoke#8 | task | opus-5 | 2.7155 | 39 | 9.8 | completed | success |
| Dhillvn/numen-edit-smoke#9 | task | opus-5 | 3.2489 | 50 | 10.6 | completed | success |
| Dhillvn/numen-edit-smoke#10 | task | opus-5 | 2.3849 | 34 | 8.9 | completed | success |
| Dhillvn/numen-edit-smoke#22 | task | opus-5 | 2.6337 | 20 | 8.5 | completed | success |
| Dhillvn/numen-edit-smoke#23 | task | opus-5,sonnet-5 | 2.0831 | 16 | 4.1 | completed | success |
| Dhillvn/numen-edit-smoke#24 | task | opus-5 | 5.0195 | 56 | 37.5 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-edit-smoke#27 | task | opus-5 | 3.0224 | 43 | 12.6 | completed | success |
| Dhillvn/numen-edit-smoke#28 | task | opus-5 | 2.2772 | 37 | 6.5 | completed | success |
| Dhillvn/numen-ops#2 | task | opus-5 | 0.8100 | 17 | 2.5 | completed | success |
| Dhillvn/numen-ops#3 | task | opus-5 | 0.9316 | 18 | 2.8 | completed | success |
| Dhillvn/numen-ops#4 | task | opus-5 | 1.6189 | 22 | 4.7 | completed | success |
| Dhillvn/numen-ops#5 | task | opus-5 | 0.5536 | 16 | 1.9 | completed | success |
| Dhillvn/numen-ops#7 | task | opus-5 | 1.4311 | 31 | 3.9 | completed | success |
| Dhillvn/numen-ops#9 | task | opus-5 | 1.6752 | 10 | 4.3 | completed | success |
| Dhillvn/numen-ops#9 | task | opus-5 | 2.5654 | 46 | 6.7 | completed | success |
| Dhillvn/numen-ops#10 | task | opus-5 | 1.2214 | 24 | 4.2 | completed | success |
| Dhillvn/numen-ops#11 | research | opus-5 | 1.6147 | 40 | 5.4 | completed | success |
| Dhillvn/numen-ops#18 | task | opus-5,sonnet-5 | 1.9561 | 20 | 8.2 | completed | success |
| Dhillvn/numen-ops#26 | task | opus-5,sonnet-5 | 2.9402 | 41 | 8.6 | completed | success |
| Dhillvn/numen-ops#37 | task | opus-5 | 2.9330 | 43 | 112.3 | completed | success |
| Dhillvn/numen-ops#38 | task | opus-5 | 2.7653 | 45 | 15.3 | completed | success |
| Dhillvn/numen-ops#43 | task | opus-5 | 1.6847 | 29 | 4.6 | completed | success |
| Dhillvn/numen-ops#54 | task | opus-5 | 2.1607 | 40 | 7.1 | completed | success |
| Dhillvn/numen-ops#55 | task | opus-5 | 1.4631 | 32 | 16.5 | completed | success |
| Dhillvn/numen-ops#57 | task | opus-5 | 1.7944 | 34 | 6.6 | completed | success |
| Dhillvn/numen-ops#58 | task | opus-5 | 1.9650 | 42 | 7.3 | completed | success |
| Dhillvn/numen-ops#59 | task | opus-5 | 2.5424 | 56 | 18.0 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-ops#61 | task | opus-5 | 4.3647 | 63 | 15.6 | completed | success |
| Dhillvn/numen-ops#62 | task | opus-5,sonnet-5 | 2.3491 | 28 | 9.6 | completed | success |
| Dhillvn/numen-ops#62 | task | opus-5 | 3.0500 | 63 | 9.5 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-ops#64 | task | opus-5 | 2.7603 | 35 | 8.1 | completed | success |
| Dhillvn/numen-ops#66 | task | opus-5 | 1.1076 | 17 | 2.5 | completed | success |
| Dhillvn/numen-ops#69 | task | opus-5 | 1.8583 | 35 | 7.0 | completed | success |
| Dhillvn/numen-ops#75 | task | opus-5 | 1.6770 | 33 | 5.7 | completed | success |
| Dhillvn/numen-ops#76 | task | opus-5 | 1.9072 | 41 | 6.1 | completed | success |
| Dhillvn/numen-ops#80 | task | opus-5 | 2.7926 | 65 | 11.9 | completed | success |
| Dhillvn/numen-ops#80 | task | opus-5 | 2.2803 | 48 | 6.5 | completed | success |
| Dhillvn/numen-ops#86 | task | opus-5 | 3.7926 | 57 | 17.3 | completed | success |
| Dhillvn/numen-ops#87 | task | opus-5 | 2.0165 | 42 | 7.7 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-ops#88 | task | opus-5 | 2.0054 | 40 | 6.6 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-ops#90 | task | opus-5 | 4.0383 | 72 | 11.2 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-ops#90 | task | opus-5 | 3.1833 | 54 | 10.1 | completed | success |
| Dhillvn/numen-ops#95 | task | opus-5,sonnet-5 | 5.8140 | 39 | 10.5 | completed | success |
| Dhillvn/numen-ops#101 | task | opus-5 | 2.5485 | 50 | 8.3 | completed | success |
| Dhillvn/numen-ops#104 | task | opus-5 | 1.0163 | 23 | 6.4 | completed | success |
| Dhillvn/numen-ops#105 | research | haiku-4.5,opus-5,sonnet-5 | 2.9221 | 33 | 10.7 | completed | success |
| Dhillvn/numen-ops#106 | task | opus-5 | 2.0253 | 31 | 6.0 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-ops#108 | research | opus-5 | 3.0613 | 48 | 16.1 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-ops#112 | task | opus-5 | 6.4077 | 77 | 17.8 | completed | success |
| Dhillvn/numen-ops#114 | task | opus-5 | 3.8251 | 52 | 11.1 | completed | success |
| Dhillvn/numen-ops#115 | research | opus-5,sonnet-5 | 2.5448 | 12 | 6.2 | completed | success |
| Dhillvn/numen-ops#122 | research | opus-5 | 1.4891 | 26 | 4.2 | completed | success |
| Dhillvn/numen-ops#123 | research | opus-5 | 0.9495 | 20 | 11.4 | completed | success |
| Dhillvn/numen-ops#126 | research | opus-5,sonnet-5 | 2.3012 | 10 | 6.0 | completed | success |
| Dhillvn/numen-ops#127 | research | opus-5,sonnet-5 | 3.2007 | 1 | 0.0 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-ops#132 | research | opus-5,sonnet-5 | 2.0536 | 20 | 5.8 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-ops#133 | task | opus-5 | 1.5821 | 24 | 15.7 | completed | success |
| Dhillvn/numen-ops#134 | research | opus-5 | 1.0401 | 14 | 3.1 | completed | success |
| Dhillvn/numen-ops#137 | research | opus-5 | 1.9035 | 38 | 5.1 | completed | success |
| Dhillvn/numen-ops#142 | research | haiku-4.5,opus-5 | 1.3904 | 22 | 3.7 | completed | success |
| Dhillvn/numen-ops#143 | research | haiku-4.5,opus-5 | 1.5766 | 18 | 2.9 | completed | success |
| Dhillvn/numen-ops#145 | task | opus-5 | 0.9053 | 11 | 2.7 | completed | success |
| Dhillvn/numen-ops#146 | task | haiku-4.5,opus-5 | 1.6412 | 36 | 8.6 | completed | success |
| Dhillvn/numen-ops#147 | task | opus-5 | 3.0362 | 43 | 21.6 | completed | success |
| Dhillvn/numen-ops#148 | task | opus-5 | 1.8427 | 29 | 8.2 | completed | success |
| Dhillvn/numen-ops#150 | task | opus-5 | 1.4056 | 24 | 5.9 | api_error | success |
| Dhillvn/numen-ops#165 | research | haiku-4.5,opus-5 | 2.0051 | 31 | 5.5 | completed | success |
| Dhillvn/numen-ops#166 | research | haiku-4.5,opus-5,sonnet-5 | 2.5984 | 8 | 3.9 | completed | success |
| Dhillvn/numen-ops#167 | task | opus-5,sonnet-5 | 2.8205 | 23 | 7.0 | completed | success |
| Dhillvn/numen-ops#171 | task | opus-5 | 2.4902 | 49 | 11.6 | completed | success |
| Dhillvn/numen-ops#173 | task | opus-5 | 1.5257 | 37 | 4.6 | completed | success |
| Dhillvn/numen-ops#178 | task | opus-5 | 1.8186 | 47 | 5.7 | completed | success |
| Dhillvn/numen-ops#179 | task | opus-5 | 1.8196 | 42 | 7.3 | completed | success |
| Dhillvn/numen-ops#180 | task | opus-5 | 6.0452 | 47 | 15.6 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-ops#181 | task | opus-5 | 5.2725 | 68 | 11.9 | completed | success |
| Dhillvn/numen-ops#184 | task | opus-5 | 6.0429 | 69 | 11.5 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-ops#185 | task | opus-5 | 1.4592 | 30 | 4.4 | completed | success |
| Dhillvn/numen-ops#187 | task | opus-5 | 3.0126 | 48 | 8.5 | completed | success |
| Dhillvn/numen-ops#188 | task | opus-5 | 3.8309 | 68 | 10.4 | completed | success |
| Dhillvn/numen-ops#189 | task | opus-5 | 2.6397 | 37 | 8.1 | completed | success |
| Dhillvn/numen-ops#190 | research | opus-5,sonnet-5 | 3.3923 | 43 | 15.5 | completed | success |
| Dhillvn/numen-ops#192 | task | opus-5 | 3.7823 | 61 | 12.4 | completed | success |
| Dhillvn/numen-ops#194 | task | opus-5 | 3.6168 | 49 | 9.1 | completed | success |
| Dhillvn/numen-ops#195 | research | opus-5 | 0.8749 | 10 | 2.6 | completed | success |
| Dhillvn/numen-ops#196 | research | opus-5 | 1.4442 | 18 | 4.2 | completed | success |
| Dhillvn/numen-ops#197 | research | opus-5 | 2.9769 | 38 | 9.6 | completed | success |
| Dhillvn/numen-ops#198 | task | opus-5 | 5.0472 | 54 | 14.3 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-ops#199 | task | opus-5 | 4.2803 | 72 | 8.2 | completed | success |
| Dhillvn/numen-ops#200 | research | opus-5 | 1.4788 | 21 | 4.0 | completed | success |
| Dhillvn/numen-ops#201 | task | opus-5 | 4.5248 | 70 | 9.8 | completed | success |
| Dhillvn/numen-vsl#3 | research | opus-5 | 1.3295 | 26 | 5.8 | completed | success |
| Dhillvn/numen-vsl#4 | research | opus-5 | 2.0344 | 29 | 11.4 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-vsl#5 | task | opus-5 | 1.8964 | 22 | 5.5 | completed | success |
| Dhillvn/numen-vsl#6 | task | opus-5,sonnet-5 | 2.2064 | 10 | 3.8 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-vsl#7 | task | opus-5 | 1.7558 | 22 | 5.4 | completed | success |
| Dhillvn/numen-vsl#8 | task | opus-5 | 1.9155 | 16 | 5.9 | completed | success |
| Dhillvn/numen-vsl#10 | grilling | opus-5 | 2.6295 | 10 | 9.1 | completed | success |
| Dhillvn/numen-vsl#13 | task | opus-5 | 1.4478 | 10 | 3.1 | completed | success |
| Dhillvn/numen-vsl#20 | research | opus-5,sonnet-5 | 4.0157 | 1 | 0.0 | budget_exhausted | error_max_budget_usd |
| Dhillvn/numen-vsl#20 | research | opus-5 | 3.5933 | 65 | 20.2 | completed | success |
| Dhillvn/numen-vsl#22 | task | opus-5 | 1.8897 | 14 | 6.2 | completed | success |
| Dhillvn/numen-vsl#23 | task | opus-5 | 1.7084 | 14 | 5.6 | completed | success |
| Dhillvn/numen-vsl#24 | task | opus-5,sonnet-5 | 2.6624 | 10 | 8.2 | completed | success |
| Dhillvn/numen-vsl#25 | task | opus-5 | 3.3018 | 12 | 11.4 | completed | success |
| Dhillvn/numen-vsl#28 | task | opus-5 | 0.9472 | 12 | 3.5 | completed | success |
| Dhillvn/numen-vsl#35 | task | opus-5 | 2.1387 | 22 | 5.1 | completed | success |
| Dhillvn/numen-vsl#35 | task | opus-5 | 1.6293 | 20 | 3.8 | completed | success |

