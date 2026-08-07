# Restructure verdict: what the branch harness saw against the finished skill

Ticket [#115](https://github.com/Dhillvn/Caesar/issues/115). Verdict ticket for map
[#109](https://github.com/Dhillvn/Caesar/issues/109). Measurement only — this document
changes no skill byte.

**Observed skill:** `C:\Users\rajdh\.claude\skills\caesar`, a directory junction onto
`C:\Users\rajdh\Projects\caesar\skill`, the main checkout, on `main` at `ef628d1` — the
restructured 365-line `SKILL.md` with its 11 pointers and eleven reference files. This is the
first harness run aimed at the finished file. [#113](https://github.com/Dhillvn/Caesar/issues/113)
ran the same harness and measured the *pre*-restructure file; its result is superseded here.

**Bounded by [`docs/harness-blind-spots.md`](../harness-blind-spots.md).** Ten limits, all of
them live in what follows. The three that bite hardest on this document: §1 a read is not a
use, so nothing below proves a reference was *load-bearing*; §3 one roll is not a
distribution, so a single missing read is a lead, not a finding; §5 fixture maps carry two or
three children where real maps carry nineteen, and context pressure is the thing being
restructured, so every pointer here fired under less pressure than production applies.

## 1. Raw per-branch report

Run: **2026-08-07**, five fixtures, `claude-opus-5` / effort `medium` / `-BudgetUsd 2.0`, each
against a freshly staged disposable fixture map. All fixture issues closed after the run.

**Deviation from the ticket's step 2, stated because it changes the run id.** The harness was
driven **one fixture per invocation** (`-Fixture <id> -TimeoutMinutes 8`) rather than as a
single `-All`. Reason: this session had to block synchronously on every long operation, and
its shell tool caps a foreground call at 10 minutes, which `-All` at five sessions cannot fit
inside. Each fixture is a wholly independent session in either mode — `-All` is a loop over
exactly this call — so the observation is unchanged, but there are **five run ids, not one**.

| Fixture | Run id | Branch | Fired | Reference files read | Turns | Cost | is_error |
|---|---|---|---|---|---|---|---|
| `drive-dispatch` | `20260807-091221` | Drive, dispatch on the frontier | **YES** 2/2 | `dispatch.md`, `prompt-shape.md`, `watcher.md` | 12 | $0.60 | False |
| `failure` | `20260807-091430` | A centurion that failed | **YES** 1/1 | `dispatch.md`, `failure.md`, `prompt-shape.md`, `worktrees.md` | 29 | $1.02 | False |
| `veto` | `20260807-091821` | Raj vetoes a closed decision | **YES** 2/2 | `veto.md` | 26 | $0.95 | False |
| `grill-only` | `20260807-092219` | Grill-only, nothing takeable | **YES** 1/1 | `grill-only.md` | 12 | $0.39 | False |
| `chart` | `20260807-092406` | Chart a new map | **NO** 0/1 | *(none — skill never loaded)* | 25 | $1.14 | False |

Non-reference paths also touched, recorded for completeness and excluded from the analysis
below (frozen scripts are not part of the disclosure question): `drive-dispatch` —
`scripts/`, `scripts/frontier.ps1`; `failure` — `scripts/frontier.ps1`,
`scripts/map-body.ps1`, `scripts/spawn-ticket-agent.ps1`; `veto` — `scripts/`; `grill-only` —
`scripts/frontier.ps1`.

Every session loaded skill `caesar` except `chart`, which loaded `ponytail:ponytail` and
nothing else. No session timed out; no session errored. Total spend across the five sessions
**$4.10**. Per-run artifacts and `report.json` are under
`.claude/caesar-runs/branch-harness/<run id>/` (gitignored, machine-bound).

### `chart` did not fire, and that is the known limit

With no map URL and no mention of Caesar in the invocation, nothing matches the skill's
`description`, so the session never loads the skill and builds the thing itself. Recorded in
`scripts/branch-fixtures/01-chart.json`'s `notes` and reproduced exactly here. **This is a
harness limitation, not a finding about the restructure** — it says nothing about whether
`references/charting.md`'s pointer works, because the pointer was never in context to fire.
`charting.md` is therefore **unobserved**, not missed.

### The #113 anomaly did not reproduce

#113 reported the `chart` fixture's read list naming `references/watcher.md` at a time when
that file existed only on #113's branch. On this run `chart`'s read list is **empty**. The
anomaly is not reproducible against the junction as configured, and needs no repair ticket.

## 2. What each branch reached, set against the ruling

The predictions are [`docs/research/region-boundaries.md`](region-boundaries.md) — its
*Proposed layout* table names the trigger for every disclosed file.

| Branch | Ruling says it needs | Reached | Verdict |
|---|---|---|---|
| `drive-dispatch` | `dispatch.md` (sweep hands it an unblocked AFK ticket), `prompt-shape.md` (composing the prompt), `watcher.md` (first dispatch **and** live `ticket-N-*` at startup), `worktrees.md` (`git worktree list` returns anything) | `dispatch.md`, `prompt-shape.md`, `watcher.md` | **3 of 4.** `worktrees.md` missed — §4.1 |
| `failure` | `failure.md`, incl. the claimed-AFK-with-nothing-on-disk material | `failure.md`, `worktrees.md` | **Hit.** Plus two false reaches — §5.1 |
| `veto` | `veto.md` | `veto.md` | **Hit** |
| `grill-only` | `grill-only.md` | `grill-only.md` | **Hit.** The ruling called this the cheapest place to prove the harness works; it proved it |
| `chart` | `charting.md` | *(skill never loaded)* | **Unobservable** — known harness limit |

**The watcher, ranked #1 in the ruling's pointer-failure cost table, fired.** It has two
firing sites and `drive-dispatch` exercised both at once: the session dispatched, and
`git worktree list` from the harness cwd shows a live `ticket-115-5615` worktree, which
`SKILL.md:78` says arms the watcher before anything else. The harness cannot separate which
of the two sites pulled it, so **"the startup site fires on its own" is unproven** — a fixture
with a live `ticket-N-*` and no dispatchable frontier would be needed to settle it.

Files with **no fixture at all**, and therefore no evidence in either direction:
`multi-map.md`, `design-rationale.md`, `pointer-standard.md`, `charting.md`. Three of the four
are the ruling's own lowest-cost rows (ranks 14, 18, and a file created after the ruling);
`charting.md` is rank 3 and is the one gap that matters.

## 3. The `Reconciling GitHub against the disk` pointer — explicit finding

**REACHED.** This was the ruling's self-flagged weakest call: the split at old line 93 sends
the claimed-AFK-with-nothing-on-disk bullet and the one-machine assumption out to
`failure.md`, and the ruling asked to be overturned — the whole section inlined — if the
harness showed that pointer missing on an ordinary drive.

What shipped: the disclosed half is `skill/references/failure.md:103–120`
(*Reconciling a claimed AFK ticket against the disk*), and the pointer to it is at
`skill/SKILL.md:182–187`, which names *"the claimed-AFK-with-nothing-on-disk case"* in its own
text. The inlined half is `skill/SKILL.md:98–111`.

The `failure` fixture stages exactly that situation: `t1` is `wayfinder:research` (AFK),
assigned (claimed), carrying a resolution comment, still open — claimed on GitHub with
nothing on disk and half-done bookkeeping. The session read `failure.md` and returned the
correct call (finish the mechanical remainder, no spawn, no flag), 1/1 marker.

**Caveat, and it narrows the finding.** The pointer fired on a sweep that had a
failure-shaped row in front of it. Neither `drive-dispatch` nor `veto` — ordinary primary
sweeps with no such row — read `failure.md`. So what is proven is that the pointer fires
**when the case is present**, which is the condition the ruling's own trigger names. What is
*not* proven is the stronger version the ruling worried about: that a session correctly
recognises a claimed-AFK row it has not been steered toward. Do not inline the section on
this evidence; do not treat the question as fully closed either.

## 4. Misses

Material a branch needed and did not reach. Each names its failing pointer and the material
behind it, so a repair ticket can be written from this section alone.

### 4.1 `worktrees.md` not reached on `drive-dispatch`

- **Branch:** `drive-dispatch`, run `20260807-091221`.
- **Failing pointer:** `skill/SKILL.md:88–91` — *"**Any worktree read 3 shows** … Read it
  before you delete anything: **never delete a worktree that is not named `ticket-N-*`**"*.
- **Material behind it:** `skill/references/worktrees.md` (31 lines) — worktree ownership,
  teardown via `remove-worktree.ps1`, and the orphan rule.
- **Why it should have fired:** the session's cwd is a live worktree, so read 3
  (`git worktree list`) returns at least two entries. The pointer's trigger is *"returns
  anything"*, and it returned something. The same pointer **did** fire on the `failure`
  fixture from the same cwd, which is what makes this a real inconsistency rather than a
  trigger that is simply never met.
- **Cost if it stays missed** (ruling rank 6): a worktree that is not `ticket-N-*` gets
  deleted — it could be Raj's own. `remove-worktree.ps1` is fail-closed on dirty or unpushed
  work, so this bites hardest on a clean folder, which is precisely the one that looks safe.
- **Strength:** a **lead, not a finding** (blind spot §3 — one roll, and the same pointer fired
  on a sibling fixture). A repair ticket should first re-run `drive-dispatch` several times to
  see whether this is stochastic before rewording anything. If it reproduces, the reword is at
  the trigger clause: *"returns anything"* is being read as *"shows something you intend to
  delete"*, and the pointer text leads with the deletion rule, which invites exactly that
  narrowing.

### 4.2 No other miss was observed

Every other branch reached the file the ruling assigned it. That is a report on four
branches — see §2 for the four reference files no fixture exercises, which are **unproven in
both directions** rather than passing.

## 5. False reaches

Material a session pulled in that its branch had no use for. A pointer worded too broadly,
and the cost lands on turns that should not pay it.

### 5.1 `dispatch.md` + `prompt-shape.md` on the `failure` branch

- **Branch:** `failure`, run `20260807-091430`.
- **Over-broad pointer:** `skill/SKILL.md:162–168` — *"**Firing a centurion** … Read it before
  you fire"*.
- **What it pulled:** `references/dispatch.md` (170 lines, 10.9 KB) and, chained behind it,
  `references/prompt-shape.md` (83 lines, 5.2 KB) — **253 lines, ~16 KB**.
- **Why it is a false reach:** the fixture's correct call is the half-done row — *finish the
  mechanical remainder yourself, no spawn*. The session got that right (1/1 marker) and fired
  nothing. It paid the full dispatch corpus, plus the prompt-shape file chained behind it, to
  reach a decision **not** to dispatch. This branch is the single most expensive of the five
  at $1.02 and 29 turns, roughly double `drive-dispatch`.
- **Repair shape:** the pointer's trigger is the *presence of an AFK frontier*, but the
  material is only needed once the decision to fire has been made. Retriggering it on the
  decision rather than the situation — *read it once you have picked a ticket to fire* —
  would keep it off this turn. Note this cuts against `pointer-standard.md`'s general
  preference for situation-shaped triggers, so it is a judgement call for a repair ticket,
  not a mechanical fix.
- **Bounded:** blind spot §5 — on a fixture map of three children, 16 KB is affordable and the
  session still landed the right answer. On a nineteen-child map the same 16 KB is spent
  against a much fuller context. The harness cannot show that cost; it can only show the read.

### 5.2 Not counted as false reaches

- `watcher.md` on `drive-dispatch` — legitimate on both of its firing sites (§2).
- `worktrees.md` on `failure` — legitimate; read 3 returned worktrees.
- The frozen `scripts/` reads on every driving branch — the skill's own tooling, not
  disclosure surface.

## 6. Before and after

| | Lines | Bytes |
|---|---|---|
| `SKILL.md` before — `ab37328` | 794 | 45,852 |
| `SKILL.md` after — `main` at `ef628d1` | **365** | **20,351** |
| **Cut** | **429 (54.0%)** | **25,501 (55.6%)** |

The ruling projected ~320 lines; the file landed at 365, 14% over the projection and still a
54% cut. The overshoot is the pointers themselves plus `pointer-standard.md`'s pointer, which
the ruling's arithmetic (9 files, ~18 lines of pointer) did not include — eleven pointer sites
shipped, not nine.

Disclosed material, `skill/references/`, 11 files, 769 lines / 45,700 bytes:

| File | Lines | Bytes | Observed to fire |
|---|---|---|---|
| `dispatch.md` | 170 | 10,941 | yes (2 branches) |
| `pointer-standard.md` | 143 | 7,601 | no fixture |
| `failure.md` | 119 | 8,155 | yes |
| `prompt-shape.md` | 83 | 5,171 | yes (2 branches) |
| `charting.md` | 76 | 4,179 | unobservable (skill never loaded) |
| `watcher.md` | 57 | 3,346 | yes |
| `veto.md` | 40 | 2,333 | yes |
| `worktrees.md` | 31 | 1,621 | yes (1 of 2 eligible branches) |
| `multi-map.md` | 22 | 837 | no fixture |
| `grill-only.md` | 16 | 891 | yes |
| `design-rationale.md` | 12 | 625 | no fixture |

Six of eleven observed firing. Two unobservable by construction of the fixture set
(`charting.md`, `pointer-standard.md`); two have no fixture and are the ruling's own
lowest-cost rows; one (`worktrees.md`) fired inconsistently — §4.1.

## 7. Verdict

**The restructure holds.** `SKILL.md` is 54% shorter and every branch the harness could
observe still reached the material the ruling assigned it. Four of five fixtures fired their
markers and reached the right file; the fifth is the known harness limit and says nothing
either way. The ruling's highest-cost pointer, the watcher, fired. The ruling's self-declared
weakest call — the `Reconciling GitHub against the disk` split — fired on the branch that
needs it, so the split stands and should **not** be reverted to an inline section.

That verdict is bounded, and the boundaries are not decoration:

- **Unproven: that any reference is load-bearing.** Blind spot §1. Every "yes" above is a
  read. Whether the session would have answered differently without it, the harness cannot
  say.
- **Unproven: that the 54% cut helps.** Blind spot §5. The restructure exists to relieve
  context pressure on nineteen-child maps; every fixture here carries three. The cut is
  measured, the benefit is inferred.
- **Unproven: the watcher's startup firing site alone.** §2. It co-fired with the dispatch
  site and cannot be separated on this run.
- **Unproven in both directions: `charting.md`, `multi-map.md`, `design-rationale.md`,
  `pointer-standard.md`.** No fixture reaches them. `charting.md` is rank 3 on the
  pointer-failure cost table and is the material gap in this verdict.
- **A lead, not a finding: `worktrees.md` on `drive-dispatch`** (§4.1). One roll.

Two follow-ups this map does not yet hold, both chartable from the sections named:

1. **`worktrees.md` on an ordinary drive** — reproduce §4.1 across repeated
   `drive-dispatch` runs; reword the `SKILL.md:88–91` trigger only if it reproduces.
2. **A `chart` fixture that actually loads the skill** — the fixture's own `notes` set out
   the two routes (name Caesar in the invocation, weakening *"the branch is the situation,
   not a question"*; or teach the runner to send a slash command safely). Until one is taken,
   rank 3 of the cost table is untested.

The `dispatch.md` false reach (§5.1) is a third candidate, and the weakest of the three — it
costs context on one branch and broke nothing.

## 8. Housekeeping

- **No worktree contamination this run.** #111 and #113 saw a fixture session write
  `skill/scripts/publish-runs.ps1` and append to `skill/references/watcher.md` inside the
  live worktree. `git status --porcelain` after all five runs is empty. Not recurred.
- **Fixture issues:** every issue staged by the five runs was closed by the harness's own
  post-run cleanup path (`--reason "not planned"` with a comment), the same thing `-Cleanup`
  does. Per blind spot §10 they are closed, not deleted, and remain in the repo's issue
  history labelled `caesar:fixture`.
- **Junction and checkout untouched.** `C:\Users\rajdh\.claude\skills\caesar` still points at
  `C:\Users\rajdh\Projects\caesar\skill`; the main checkout is still on `main`.
