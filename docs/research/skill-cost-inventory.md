# Skill-cost inventory: what each skill actually costs a centurion to load

Ticket: [#73](https://github.com/Dhillvn/caesar/issues/73). Measured 2026-08-05 on Raj's
machine (Claude Code 2.1.222). Script: `scripts/skill_cost.py` (read-only, prints aggregates
only — no transcript text ever enters context).

## The headline

**Byte count does not rank skills usefully. It separates exactly one skill from all the others.**

Of 119 `SKILL.md` files on the machine, the largest is 45 KB. `claude-api` injects **897,612
characters** — 20× the largest ordinary skill, and it is the only skill on the machine that
is not bounded by its own `SKILL.md`, because it does not have one. Everything else lands
between 0.8 KB and 45 KB, a range in which the ranking is meaningless: even the worst case
costs ~5% of the $5.00 cap, less than one extra research turn.

So the deliverable is not a ranked ban list. It is: **ban `claude-api` by name, unban
everything else, and keep a structural test for the next offender.** The rank order below is
included because the ticket asked for it, and because it is the evidence for the negative result.

## Method

Two measurements, joined.

**Static.** For every `SKILL.md` under `~/.claude/skills` and `~/.claude/plugins/cache`,
record the `SKILL.md` byte size and the total byte size of its directory (SKILL.md +
`references/`, `scripts/`, assets).

**Observed.** Every skill invocation appears in a session transcript as a prompt-injected
user text block starting `Base directory for this skill: <path>`. That block *is* the
injection — its character count is the exact context cost of the load. Scanned every
`.jsonl` under `~/.claude/projects`: **24 distinct skills, several hundred real loads**
(`save-session` n=174, `ponytail` n=152, `caesar` n=76). The ticket asked for the static
proxy to be checked against at least two real invocations; this checks it against hundreds.

Characters, not tokens, are the primary unit — they are directly measurable. Conversion is
applied only in the cost arithmetic (§ Threshold), at 3.5 chars/token for prose-markdown and
at the measured 2.6 chars/token for `claude-api`'s code-heavy bundle
(897,612 chars ≈ 340K tokens, per `docs/research/published-model-evidence.md`).

## Does the static proxy work?

| Proxy | Median ratio to observed | Range | Verdict |
|---|---|---|---|
| `SKILL.md` size | **0.94** | 0.77 – 1.34 | **Accurate.** Use it. |
| Whole-directory size | 0.58 | 0.005 – 0.98 | **Useless.** Over-states by up to 200×. |

`SKILL.md` size predicts the injection to within ±25%. Directory size does not, because
**references load lazily** — and that difference is exactly what the ticket suspected:

| Skill | dir | SKILL.md | observed | observed ÷ dir |
|---|---|---|---|---|
| `brainstorming` | 75.8 KB | 10.4 KB | 10.3 KB | 0.14 |
| `numen-inbox-triage` | 60.8 KB | 8.1 KB | 7.8 KB | 0.13 |
| `systematic-debugging` | 40.8 KB | 9.5 KB | 9.7 KB | 0.24 |
| `impeccable` | **2,692 KB** | 10.5 KB | 14.0 KB | **0.005** |
| `ui-styling` | 5,758 KB | 10.4 KB | (never loaded) | — |

`impeccable` ships a 2.7 MB directory and costs 14 KB to load. Banning by directory size
would have banned it, and `ui-styling` (5.8 MB), for nothing.

**`claude-api` is the one inversion.** Its extracted bundle
(`%TEMP%\claude\bundled-skills\2.1.222\<hash>\claude-api`) contains **no `SKILL.md` at all** —
67 markdown files totalling **827 KB** across `shared/` and seven language dirs, largest single
file `shared/model-migration.md` at 176 KB. Observed injection 897,612 chars = **1.08× the whole
directory**. It inlines its entire reference tree eagerly. That structural fact, not its size, is
what makes it dangerous — size is the symptom.

## Ranked table

All 24 skills with observed loads, plus the top of the static-only list. Bytes.

| Rank | Skill | SKILL.md | dir | loads seen | observed median | observed max |
|---:|---|---:|---:|---:|---:|---:|
| — | **`claude-api`** | *(none)* | **827,608** | 2 | **848,382** | **897,612** |
| 1 | `caesar` | 38,956 | 93,494 | 76 | 33,016 | 34,385 |
| 2 | `subagent-driven-development` | 28,077 | 50,263 | 1 | 21,544 | 21,544 |
| 3 | `impeccable` | 10,464 | 2,692,179 | 6 | 14,019 | 18,853 |
| 4 | `notebooklm` | 12,208 | 17,517 | 19 | 11,799 | 12,356 |
| 5 | `wayfinder` | 11,900 | 11,900 | 50 | 11,668 | 14,717 |
| 6 | `teach` | 9,507 | 17,894 | 1 | 10,326 | 10,326 |
| 7 | `brainstorming` | 10,435 | 75,775 | 15 | 10,282 | 10,582 |
| 8 | `systematic-debugging` | 9,465 | 40,785 | 5 | 9,710 | 9,859 |
| 9 | `grill-with-docs-codex` | 9,343 | 16,034 | 19 | 8,621 | 10,338 |
| 10 | `codex-review` | 8,384 | 8,384 | 6 | 7,796 | 8,979 |
| 11 | `numen-inbox-triage` | 8,137 | 60,844 | 9 | 7,753 | 7,853 |
| 12 | `grill-me-codex` | 7,636 | 9,029 | 17 | 7,163 | 11,470 |
| 13 | `writing-plans` | 7,092 | 8,805 | 1 | 7,075 | 7,075 |
| 14 | `todo` | 6,204 | 9,084 | 62 | 5,842 | 7,112 |
| 15 | `save-session` | 5,902 | 5,902 | 174 | 5,224 | 6,269 |
| 16 | `ponytail` | 5,264 | 5,264 | 152 | 4,674 | 5,187 |
| 17 | `numen-newsletter-corpus` | 4,470 | 14,989 | 1 | 4,179 | 4,179 |
| 18 | `numen-flowchart` | 4,153 | 5,931 | 8 | 3,410 | 3,749 |
| 19 | `domain-modeling` | 3,427 | 8,492 | 1 | 3,449 | 3,449 |
| 20 | `decision-log` | 3,941 | 7,877 | 1 | 3,278 | 3,278 |
| 21 | `prototype` | 2,799 | 15,395 | 5 | 2,631 | 2,631 |
| 22 | `ponytail-help` | 2,553 | 2,553 | 3 | 2,400 | 2,400 |
| 23 | `grilling` | 843 | 843 | 24 | 754 | 935 |
| 24 | `research` | 799 | 799 | 1 | 707 | 707 |

Largest never-loaded skills by `SKILL.md` (predicted cost = the `SKILL.md` column, ±25%):
`ui-ux-pro-max` 45,434 · `skill-creator` 33,168 · `workflow` 32,980 · `writing-skills` 26,431 ·
`ai-gateway` 24,437 · `vercel-functions` 22,796. **45 KB is the ceiling of the entire ordinary
population.**

## Threshold: the arithmetic

A skill load is not a one-off charge. It enters the prompt and is re-sent on **every
subsequent turn**, so its cost scales with how early it is loaded.

Assumptions, stated: Opus 5 input **$5.00/MTok** (bundled `shared/model-migration.md`: Opus 5
is "a drop-in upgrade at Opus 4.8's pricing — $5 per million input"), cache write 1.25× =
$6.25/MTok, cache read 0.1× = $0.50/MTok. `T` = turns remaining after the load; `T = 30` is
a typical mid-run centurion. Sonnet tiers are 0.6× these numbers, so Opus is the conservative case.

> cost = tokens × ($6.25 + T × $0.50) / 1,000,000

At `T = 30`, and 3.5 chars/token, that is **$0.0062 per KB of skill text**.

| Skill size | tokens | cost @ T=30 | share of $5.00 cap |
|---|---:|---:|---:|
| 5 KB (`ponytail`, `save-session`) | 1.5K | $0.03 | 0.6% |
| 12 KB (`wayfinder`) | 3.5K | $0.07 | 1.5% |
| 33 KB (`caesar`) | 9.7K | $0.21 | 4.1% |
| 45 KB (`ui-ux-pro-max`, the ordinary max) | 13K | $0.28 | 5.6% |
| **100 KB (proposed line)** | **29K** | **$0.62** | **12%** |
| **898 KB (`claude-api`)** | **345K** | **$7.34** | **147% — kills the run** |

`claude-api` is over the cap on the cache-read term alone. Even at `T = 5` — loaded near the
very end of a run — it costs $2.16 (write) + $0.86 (reads) = **$3.02, 60% of the cap**. There
is no point in a run at which loading it is affordable. That matches the observed death: run
#58 attempt 1, 876 KB of a 931 KB skill-load total, cap-dead.

**Proposed threshold: 100 KB injected (≈29K tokens, ≈12% of the cap at T=30).**

- **< 50 KB — free.** Costs under 6% of cap. This is every skill on the machine except one.
- **50–100 KB — allowed, worth noting.** No skill currently lives here.
- **> 100 KB — banned.** Only `claude-api` (898 KB) qualifies, by a factor of 9.

The line sits at 100 KB rather than tight against the 45 KB ceiling deliberately: it must
catch a *new* offender without re-banning the existing population every time someone writes
a slightly longer skill.

## Recommended ban list

**Banned: `claude-api`. That is the whole list.**

Replace the blanket ban in the centurion dispatch prompt. Current wording bans one skill by
name and discourages the rest by implication ("Do **not** invoke the `claude-api` skill. Other
small task-relevant skills are welcome") — the word *small* is doing unmeasured work. Proposed:

> **SKILLS.** Run `ponytail` before writing code. Do **not** invoke the `claude-api` skill —
> it injects ~900 KB (~345K tokens) and will eat the whole cap; read it from disk instead
> (`%TEMP%\claude\bundled-skills\<version>\<hash>\claude-api\`). Every other skill on the
> machine costs under 45 KB to load; invoke whichever are relevant, freely.

The gain is not the cost saving; skills are cheap. It is that centurions currently decline
useful skills out of a fear the measurement does not support.

## The structural test (what to check for the next offender)

Size is the symptom; **eager reference inlining is the disease**. A skill is dangerous when
its injection is bounded by its *directory* rather than by its `SKILL.md`. Two tells, both
visible without invoking it:

1. **No `SKILL.md`** in the skill directory — nothing bounds what gets injected.
2. `observed ÷ dir` approaching 1.0 across real loads.

Re-run `python scripts/skill_cost.py` after installing new skills or after a Claude Code
upgrade replaces the bundled-skills directory (`claude-api`'s bundle changed between 2.1.215
and 2.1.222 — 799 KB → 898 KB, a 12% growth in one patch release). The script prints the
ratio columns needed for both tells and never reads a transcript into context.

## What this does not measure

Bytes are the wrong axis for value, only for risk. A skill costing 40 KB that saves 20 turns
is enormously profitable — a centurion turn with a large context costs far more than $0.28.
Nothing here ranks skills by usefulness, and nothing here should be read as a reason to skip a
relevant skill. The only actionable output is the single ban.
