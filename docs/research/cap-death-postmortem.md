# What the 17 cap deaths actually spent the money on

Research ticket [#60](https://github.com/Dhillvn/caesar/issues/60). Read-only mining of the run
artifacts and session transcripts already on disk. Every number is parsed by script from a result
JSON or a `.jsonl` transcript; nothing is estimated or recalled.

## The headline, first

**The 17 runs that died on their budget cap were not killed by context bloat. They were killed by
being long.** Not one of the 17 contains an injected message anywhere near the scale that killed
[#58](https://github.com/Dhillvn/caesar/issues/58)'s first attempt. The largest single cache write
across all 17 is **25,040 tokens** — *smaller* than the largest single cache write in the 105
completed runs (62,128). The 897,612-character `claude-api` skill load is not a corpus phenomenon;
it happened once, on 2026-08-05, in a run that postdates #55 entirely.

So the split is: **0 of 17 injection-bloat deaths, 1 of 17 borderline context-accumulation, 16 of 17
genuine big-ticket deaths.**

**#55's `$5.00` recommendation stands** — and for a better reason than #55 had. It is not merely
that the cap was low; it is that the money the cap cut off was being spent on work. The median
cap-death produced **22,372 output tokens over 32 turns**, which is *more* output than the median
**completed** run (20,518). These runs were mid-flight, not spinning.

**But the cap is not the only lever, and #51 must not treat it as one.** #58 attempt 1 proves a
single skill load can convert a $5 cap into $5 of cache re-reads in 9 turns. That failure mode is
absent from the corpus because it is *new*. Raising the cap without a context guardrail raises the
ceiling on that failure too.

## Corpus, method and reconciliation with #55

Same corpus and method as [`caesar-run-corpus.md`](caesar-run-corpus.md) (#55): every `*.json` under
`<repo>\.claude\caesar-runs\` across the local checkouts, plus worktree-local run directories.
Scripts: `scripts/cap_deaths.py` (run measurement), `scripts/bloat_sources.py` (byte attribution).

| | count |
|---|---|
| parsed result JSONs (2026-08-05, today) | 124 |
| runs with `terminal_reason: budget_exhausted` | **19** |
| — of those, started before #55's own run (2026-08-04 14:52) | **17** |
| — started after #55 | 2 |
| transcript join rate (`session_id` → `.jsonl`) | 124/124 |

**The count is 19, not 17, and it reconciles exactly.** The 17 pre-#55 cap deaths total **$56.44** —
#55's figure to the cent. The two extra deaths are both from 2026-08-05, after #55's snapshot:
`caesar` ticket-58 attempt 1 ($5.17) and `numen-crm` ticket-202 ($3.05). Everything below reports
the 17 as the population and carries the two later runs as labelled extras.

### Deduplication method — stated, because it changes every total

Claude Code writes each assistant message to the transcript **2 to 4 times** (median inflation
factor 2.17, max 4.12 across the 124 runs), each copy carrying an identical `message.usage` block.
Summing naively doubles or triples every token figure.

**Method used: dedup on `message.id`.** Every snapshot of one assistant message shares one `id`, so
keeping the first record per `id` keeps exactly one copy per real API turn. Records with no `usage`
block are skipped entirely. Cross-check: deduped turn counts land at or just below each run's
`num_turns` from the result JSON (which counts API round-trips including tool turns), whereas the
raw counts exceed it by 2–4x — the expected signature of a correct dedup.

## The completed-run norm (n=105)

The baseline the 17 are judged against. `mean_context` = mean `cache_read_input_tokens` per deduped
assistant turn, i.e. the average size of the context being re-read every turn.

| metric | p10 | median | p90 | max |
|---|---|---|---|---|
| mean context / turn | 39,578 | 52,943 | **79,416** | 108,074 |
| peak context | 54,785 | 79,955 | 118,949 | 151,830 |
| **largest single cache write** | 15,138 | 16,671 | 28,162 | **62,128** |
| cache-read ÷ output | 31 | 62 | 104 | 166 |
| output / turn | 534 | **883** | 1,813 | 5,918 |
| turns | 10 | 22 | 46 | 65 |

## The discriminator

Stated up front, and calibrated against the two known-labelled runs from #58.

> A run is a **bloat death** if either (a) it contains a single injected message above **50,000
> tokens** — roughly 2x the completed-run p90 cache write, and above the completed-run maximum; or
> (b) its **mean context per turn exceeds the completed p90 (79,416)** *while* its **output per turn
> falls below the completed median (883)** — a run carrying an oversized context but not converting
> it into work.
> Otherwise it is a **big-ticket death**: context and injections within the corpus norm, output
> accumulating turn over turn, killed by the cap while still producing.

Limb (a) catches a single catastrophic injection; limb (b) catches slow accumulation. Both are
normalised per turn, because a raw cache-read total or a raw cache-read-to-output ratio grows with
turn count on its own — a long, healthy run and a bloated one both post large totals, so the
unnormalised ratio proposed in the ticket cannot separate them. (Proof it cannot: the completed
runs' own cr/out reaches 166, higher than 14 of the 17 deaths.)

**Calibration.** #58 attempt 1: single injection of **340,283 tokens**, mean context 192,619 — trips
limb (a) by 6.8x. Labelled bloat. ✅ #58 attempt 2 completed at $2.32 with the skill forbidden and is
not in the death set at all. ✅

## The 17, per run

Ordered by cost. `maxwrite` = largest single cache write, tokens. `ctx` = mean context per turn.
`out/t` = output tokens per turn. `biggest` = largest single transcript line, KB, and its source.

| run | repo | $ | turns | ctx | maxwrite | out | out/t | biggest | class |
|---|---|---|---|---|---|---|---|---|---|
| ticket-180-3962 | numen-crm | 6.05 | 35 | 120,758 | 24,206 | 78,166 | 2,233 | 53 KB Read | big-ticket |
| ticket-184-5157 | numen-crm | 6.04 | 59 | 109,401 | 25,040 | 45,661 | 773 | 62 KB Read | **accumulation** |
| ticket-198-8750 | numen-crm | 5.05 | 49 | 100,631 | 17,625 | 50,337 | 1,027 | 40 KB Read | big-ticket |
| ticket-24-7247 | numen-edit-smoke | 5.02 | 50 | 92,231 | 14,911 | 53,747 | 1,074 | 31 KB `gh issue` | big-ticket |
| ticket-90-110 | numen-ops | 4.04 | 62 | 71,470 | 16,002 | 37,286 | 601 | 29 KB skill (numen-books) | big-ticket |
| ticket-20-2692 | numen-vsl | 4.02 | 26 | 59,578 | 14,569 | 15,757 | 606 | 36 KB Bash | big-ticket |
| ticket-127-9146 | numen-ops | 3.20 | 11 | 51,678 | 24,454 | 16,713 | 1,519 | 45 KB `gh issue` | big-ticket |
| ticket-108-784 | numen-ops | 3.06 | 44 | 63,623 | 15,899 | 32,934 | 748 | 46 KB `gh issue` | big-ticket |
| ticket-62-7124 | numen-ops | 3.05 | 53 | 61,071 | 15,686 | 27,030 | 510 | 45 KB Bash (grep) | big-ticket |
| ticket-59-8204 | numen-ops | 2.54 | 45 | 57,509 | 15,559 | 21,886 | 486 | 18 KB attachment | big-ticket |
| ticket-6-4957 | numen-vsl | 2.21 | 4 | 24,373 | 14,569 | 6,208 | 1,552 | 63 KB Agent report | big-ticket |
| ticket-132-9931 | numen-ops | 2.05 | 16 | 57,051 | 15,179 | 15,874 | 992 | 63 KB Read | big-ticket |
| ticket-4-5570 | numen-vsl | 2.03 | 20 | 52,462 | 14,569 | 28,665 | 1,433 | 29 KB Bash | big-ticket |
| ticket-7-9050 | numen-edit-smoke | 2.03 | 23 | 64,065 | 18,290 | 22,372 | 972 | 60 KB Read | big-ticket |
| ticket-106-71 | numen-ops | 2.03 | 27 | 59,237 | 17,491 | 20,558 | 761 | 46 KB `gh issue` | big-ticket |
| ticket-87-3435 | numen-ops | 2.02 | 32 | 51,424 | 16,254 | 20,723 | 647 | 18 KB attachment | big-ticket |
| ticket-88-8203 | numen-ops | 2.01 | 29 | 57,406 | 15,313 | 17,961 | 619 | 23 KB `gh issue` | big-ticket |

*Post-#55 extras, for contrast, not counted in the 17:*

| run | repo | $ | turns | ctx | maxwrite | out | out/t | biggest | class |
|---|---|---|---|---|---|---|---|---|---|
| ticket-58-5048 (att. 1) | caesar | 5.17 | 9 | 192,619 | **340,283** | 12,699 | 1,411 | **938 KB skill load** | **bloat** |
| ticket-202-3307 | numen-crm | 3.05 | 50 | 66,290 | 15,866 | 24,348 | 486 | 33 KB Read | big-ticket |

n=17. This is a small table about a handful of runs in four repos, not a law.

## What the classification means

**16 of 17 are ordinary long runs.** Their contexts sit in or just above the completed-run band
(median mean-context 59,578 vs 52,943 for completed runs), their largest injections are
indistinguishable from a healthy run's, and they were producing output right up to the kill. Median
cap-death output (22,372 tokens) exceeds median completed output (20,518). These runs were cut off,
not stuck.

**One borderline: `numen-crm` ticket-184.** 59 turns, mean context 109,401 (above completed p90),
output/turn 773 (below completed median) — it trips limb (b). Its bytes are 123 KB of `Read` plus
55 KB of `Bash`: no single bad injection, just steady accumulation of file reads without
proportionate output. This is the accumulation failure, and it is worth one line of hygiene advice,
not a policy.

**The cheaper deaths are the more suspicious ones only in productivity terms, not context terms.**
The lowest output-per-turn runs (486–620) are grind: many small tool turns, each re-reading a
50–70 KB context. That is a ~50% context tax versus the completed median (deaths' median cr/out 85
vs completed 62) — real, modest, and nothing like the 137 that #58 attempt 1 posted on a 9-turn run.

## Named bloat sources

Total tool-result bytes injected across all 19 cap-death transcripts, attributed by tool:

| source | KB across all 19 | note |
|---|---|---|
| `Bash` output | 939 | spread across all 19; largest single results are `gh issue view` bodies (18–46 KB each) |
| **Skill load (prompt-injected)** | **931** | **876 KB of it is one bundled-skill load in #58 attempt 1** — `C:\Users\rajdh\AppData\Local\Temp\claude\bundled-skills\2.1.222\...` (`claude-api`) |
| `Read` | 601 | the accumulation channel; ticket-184 alone contributes 123 KB |
| `Agent` reports | 87 | one run (`numen-vsl` ticket-6) contributes 81 KB in 4 turns |
| `firecrawl` MCP scrape/extract | 48 | two runs |
| `Edit` / `Write` / `Grep` | 37 | negligible |

Two named recurrences worth acting on, and one non-recurrence worth recording:

1. **`gh issue view` bodies, 23–46 KB — the single largest injected line in 5 of the 17.** Wayfinder ticket bodies are long, and
   several runs re-read them. Cheap to fix: read once, or `--jq` the fields needed.
2. **Skill loads other than the one catastrophe are trivial.** `ponytail` accounts for 54 KB across
   17 runs — about 4 KB each. No routine skill is a cost problem.
3. **MCP tool schema loads do not appear as a cost driver in any of the 17.** The deferred-tool
   mechanism appears to be doing its job.

## What #51 should decide on

- **Keep the cap lever, at `$5.00`.** #55's number survives contact with the transcripts. 8 of the
  17 died at a `$2` cap, 3 at `$3`, 2 at `$4`; only **4 of 17 died at `$5` or above**. So `$5.00`
  would have let 13 of 17 keep working, and — this is the part #55 could not show — that money would
  have gone to output, not to re-reading a poisoned context.
- **Add a context guardrail, and do not conflate it with the cap.** It is not needed for the 17. It
  is needed because #58 attempt 1 demonstrated a way to convert any cap into pure cache-read spend
  in under 10 turns, and raising the cap raises that ceiling too. The cheapest sufficient version:
  ban large bundled reference skills from headless ticket prompts (the prompt guardrail already used
  by #58 attempt 2, which then did **twice the turns for 45% of the cost**), and treat any single
  injected message above ~50K tokens as a run-abort condition.
- **Do not spend design effort on per-ticket-type caps on this evidence.** n=17, four repos, and the
  deaths' cost distribution overlaps the completed distribution almost entirely.

## Reproducing

```
python scripts/cap_deaths.py runs.json     # run measurement -> runs.json
python scripts/bloat_sources.py runs.json  # byte attribution by tool and skill
```

Both are read-only, print aggregates only, and never emit transcript content.
