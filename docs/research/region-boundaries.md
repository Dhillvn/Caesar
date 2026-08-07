# Region boundaries: which of `skill/SKILL.md` every session needs

Ticket [#110](https://github.com/Dhillvn/Caesar/issues/110). Ruling only — `skill/SKILL.md`
keeps every byte it has. [#113](https://github.com/Dhillvn/Caesar/issues/113) applies this.

## Method

`writing-for-agents` gives the test directly: **inline what every branch needs, disclose what
only some branches reach.** A branch is a distinct case the document handles, so different
runs take different paths through it.

Caesar's branches, named in the skill itself:

| Branch | Entry | Reached by |
|---|---|---|
| `chart` | `/caesar` with a loose idea and no URL | `SKILL.md:51` |
| `drive` | `/caesar <map-url>`, primary role | `SKILL.md:39–43` |
| `grill-only` | `/caesar <map-url> grill-only` | `SKILL.md:44` |

`drive` sub-branches, each of which a real driving session can miss entirely:

| Sub-branch | Condition |
|---|---|
| `drive:dispatch` | the sweep finds an unblocked AFK ticket, so a centurion is fired |
| `drive:harvest` | a centurion lands |
| `drive:failure` | a run goes wrong |
| `drive:veto` | Raj rejects a closed decision |
| `drive:orphan` | `git worktree list` shows a worktree the session did not create |
| `drive:multi` | more than one map is held, or discovery is asked for |

A driving session that fires no centurion reaches no dispatch material; a session where
nothing fails reaches no failure material. Both are ordinary sessions, not edge cases.

**Measured against `main` at commit `ab37328` (PR #108 merged).** The file is **794 lines**
by `wc -l` / `$f.Count`. `Get-Content | Measure-Object -Line` under-reports it at 611 because
it drops blank lines. Spans below are heading-block spans: each row runs from its heading
line to the line before the next heading of any level, so `###` blocks are not counted twice
inside their `##` parent and the counts sum to the file.

Lines 1–36 are frontmatter and the preamble — no heading, and inline by construction: the
frontmatter, the role statement, and the `claude plugin list` recipe for resolving Wayfinder
by name. Every branch reads Wayfinder's own `SKILL.md` before it does anything.

## The ruling

30 headings, one row each. (`# Caesar` at line 6 is an `#` heading and out of scope.)

| # | Section | Lines | Count | Branches that reach it | Ruling |
|---|---|---|---|---|---|
| 1 | `## Invocation and roles` | 37–53 | 17 | all | **inline** |
| 2 | `## Starting a session` | 54–78 | 25 | all | **inline** |
| 3 | `### Reconciling GitHub against the disk` | 79–105 | 27 | 79–92 all; 93–105 `drive:failure` | **split** — inline 79–92 (14), disclose 93–105 (13) |
| 4 | `### Orphan worktrees` | 106–118 | 13 | `drive:orphan` | **disclose** |
| 5 | `### What the first turn says` | 119–134 | 16 | all | **inline** |
| 6 | `### Grill-only starts differently` | 135–146 | 12 | `grill-only` | **disclose** |
| 7 | `### Why this is prose and not a script` | 147–154 | 8 | none at runtime | **disclose** |
| 8 | `## Charting a new map` | 155–213 | 59 | `chart` | **disclose** |
| 9 | ``### Why this is not `/wayfinder` in charting mode`` | 214–226 | 13 | `chart` | **disclose** |
| 10 | `## The loop` | 227–243 | 17 | `drive`, `grill-only` | **inline** |
| 11 | `## Choosing what to work` | 244–251 | 8 | all | **inline** |
| 12 | `## Dispatching a centurion` | 252–277 | 26 | 252–272 `drive:dispatch`; 273–277 `drive` | **split** — disclose 252–272 (21), inline 273–277 (5) |
| 13 | `### The skill block — what the prompt says about skills` | 278–335 | 58 | `drive:dispatch` | **disclose** |
| 14 | `### The dispatch rubric — which tier` | 336–406 | 71 | `drive:dispatch` | **disclose** |
| 15 | `### The watcher — how a landing reaches you` | 407–457 | 51 | `drive:dispatch`, `drive:orphan` | **disclose** |
| 16 | `### Reporting mid-grill` | 458–468 | 11 | `drive:harvest` | **disclose** |
| 17 | `## When a centurion fails` | 469–513 | 45 | `drive:failure` | **disclose** |
| 18 | `### The timer: look, do not kill` | 514–535 | 22 | `drive:failure` | **disclose** |
| 19 | `### Retry mechanics` | 536–545 | 10 | `drive:failure` | **disclose** |
| 20 | ``### Flagging: `caesar:needs-raj` `` | 546–562 | 17 | `drive:failure`, `drive:veto` | **disclose** |
| 21 | `## Showing Raj where things stand` | 563–576 | 14 | all | **inline** |
| 22 | `## Build work and the merge gate` | 577–603 | 27 | all | **inline** |
| 23 | `## When Raj vetoes a closed decision` | 604–638 | 35 | `drive:veto` | **disclose** |
| 24 | `## Worktrees` | 639–652 | 14 | `drive:dispatch`, `drive:harvest`, `drive:orphan` | **disclose** |
| 25 | `## Holding several maps` | 653–670 | 18 | `drive:multi` | **disclose** |
| 26 | `## Writing to the map` | 671–707 | 37 | all | **inline** |
| 27 | `## Voice` | 708–749 | 42 | all | **inline** |
| 28 | `### Where the voice is on, and where it is off` | 750–763 | 14 | all | **inline** |
| 29 | `### Register` | 764–783 | 20 | all | **inline** |
| 30 | `## Out of scope for v1` | 784–794 | 11 | all | **inline** |

The two **split** rows carry both halves in one row, so the one-row-per-heading property
holds.

## Coverage check

Extract the headings from the skill and from the table above, and diff the two lists:

```bash
awk 'NR>4 && /^#{2,3} /{ gsub(/^#+ +/,""); gsub(/`/,""); print }' skill/SKILL.md |
  sort > /tmp/from-skill

awk -F'|' '/^## The ruling/{i=1} /^## Coverage check/{i=0}
  i && $1=="" && $2 ~ /^ *[0-9]+ *$/ {
    h=$3; gsub(/`/,"",h); sub(/^ *#+ */,"",h); sub(/ *$/,"",h); print h }' \
  docs/research/region-boundaries.md | sort > /tmp/from-table

diff /tmp/from-skill /tmp/from-table && wc -l < /tmp/from-table
```

Empty diff and a count of **30** is the pass. The extractor is scoped to the ruling table so
the cost table below, which repeats the same section names with their spans, cannot inflate
the count. Ran clean on this document.

## Disclose rows: what it costs if the pointer fails to fire

Ranked most to least severe, so [#113](https://github.com/Dhillvn/Caesar/issues/113) knows
which pointers must be strongest. "Fails to fire" means the session never fetches the file
and proceeds on its own inference.

| Rank | Section | Cost if the pointer does not fire |
|---|---|---|
| 1 | `### The watcher` (407–457) | No watcher is armed, so a finished centurion reaches nobody — the spawn script detaches and emits no `SubagentStop`, no background-task completion, no `claude agents` entry. A landed scout sits unreported until Raj asks. If it *is* armed from memory without the quoting rule, `-RepoPath C:\Users\...` arrives as `C:Users...` and the watcher polls a directory that does not exist; that shape looked healthy for 75 minutes across two real landings. Silent in both directions. |
| 2 | `## Dispatching a centurion` (252–272) | The `claude -p` command gets composed by hand, dropping the flag set and the deny list the spawn script carries — the guardrail heredoc every centurion's frame depends on. Exit 0 is then read as evidence of work done, when a run that silently did nothing exits 0 with `is_error: false`. A nested `bypassPermissions` is passed and auto-denied. |
| 3 | `## Charting a new map` (155–213) | Several silent failures at once: `gh issue create --label` hard-errors on a label the repo has never held and creates nothing; a multi-line body passed through argv dies at the first newline; the sub-issue and dependency endpoints are given `#number` or `node_id` instead of the database id, so the map ends up with no children and no blocking. Plus the map gets hosted somewhere that is not a git repo, or fog gets sliced into ticket-shaped pieces. |
| 4 | `## When a centurion fails` (469–513) | The one-retry ceiling is gone, so a wall gets re-rolled indefinitely; a **coherently wrong** artifact gets re-rolled instead of returned to Raj with the collision named; a non-empty `permission_denials` on a genuinely successful run reads as failure. |
| 5 | `## When Raj vetoes a closed decision` (604–638) | The reversed line in `## Decisions so far` gets struck through, appended below, or deleted instead of rewritten in place — and that section is the **session bootstrap**, so the stale line is live misinformation taught to every future Caesar. The session also reaches for `gh search issues` (12 hits of ~20 against the timeline's 5) and files noise that reads exactly like a real report. |
| 6 | `### Orphan worktrees` (106–118) | A worktree that is not `ticket-N-*` gets deleted — it could be Raj's own. `remove-worktree.ps1` is fail-closed on dirty or unpushed work, so this bites hardest on a clean folder, which is precisely the one that looks safe. |
| 7 | ``### Flagging: `caesar:needs-raj` `` (546–562) | A failed ticket is left open and unassigned, so the next session re-fires it and the retry ceiling is defeated silently — the exact failure the section exists to name. Flags also interrupt the grill instead of queueing to a break. |
| 8 | `### The dispatch rubric` (336–406) | Every dispatch guesses a tier. The Execute gate — an objective two-part test you can fail — is replaced by a feel for "well defined", and the cheap answer always looks like less work, so Execute gets called on open-ended tickets at a wasted run plus a re-fire each. Tier, model, effort and the cap stop being recorded on the run record, so no call can ever be audited against its outcome. **Frozen: the tier table's wording is fixed wherever it lands.** |
| 9 | `### The skill block` (278–335) | The retired NotebookLM expectation gets written back into a prompt; `notebooklm auth check` reports *"Authentication is valid"* on a dead session, so the centurion believes it has access and fails downstream. The retired blanket ban on "any other very large reference skill" returns and bans cheap skills for nothing. Prompts re-list inherited skills and retype the `claude-api` ban. Review tickets go out with no fixed point. **Frozen: the deny list and the ban's wording are fixed wherever they land.** |
| 10 | `### Retry mechanics` (536–545) | The retry fires with `--resume`, carrying the failed context forward, so a centurion that talked instead of acting resumes talking — the one permitted retry is spent reproducing the failure. The attempt count goes into `.claude/caesar-runs/`, which is gitignored and machine-bound and does not exist for a grill-only session on another checkout. |
| 11 | `### Reconciling GitHub against the disk` (93–105) | A claimed AFK ticket with nothing on disk is judged from the disk alone: work already done gets re-fired (duplicate branch, duplicate PR), or half-done bookkeeping is left standing forever. The one-machine assumption goes unstated, so "no worktree" is read as "nothing running" in a setup where it is not. |
| 12 | `### Grill-only starts differently` (135–146) | A grill-only session runs `git worktree list` and auto-deletes orphans, racing a sibling grill-only session on the same folders; and it surfaces PRs the primary is also surfacing, which is how a PR gets double-merged or the spot-check wears into a rubber stamp. On an AFK-only frontier it sits idle for a reason Raj cannot see instead of saying "this needs a primary". |
| 13 | `### The timer: look, do not kill` (514–535) | A legitimately slow centurion gets killed at the clock and its work binned, when `--max-budget-usd` already bounds a runaway. Or a `DIED-AT-SPAWN` gets treated as needing acknowledgement and re-alarms on a corpse, which is how a real landing gets missed. |
| 14 | `## Holding several maps` (653–670) | The discovery search gets composed without `--owner`, returning twenty strangers' public maps reported to Raj as his own. Withdrawal kills centurions in the field instead of draining, throwing away work that was about to post. |
| 15 | `## Worktrees` (639–652) | Teardown is skipped and worktrees accumulate; a leftover is reported bare — "there is a folder here" — which the section itself classifies as a bug in Caesar rather than a report. |
| 16 | ``### Why this is not `/wayfinder` in charting mode`` (214–226) | A chart session follows Wayfinder's charting mode as written: fires research **subagents** instead of dispatching centurions through `spawn-ticket-agent.ps1`, and stops at the handover instead of flowing into the drive. Behaviour change, not just lost rationale. |
| 17 | `### Reporting mid-grill` (458–468) | A landing is reported by title rather than gist, and a title cannot be judged; or the grill is interrupted for every landing; or a resolution that contradicts a locked decision passes unchallenged and silently poisons every downstream ticket. |
| 18 | `### Why this is prose and not a script` (147–154) | Nothing breaks at runtime. A future pass re-litigates `startup.ps1` and spends a ticket arriving where this section already arrived. Lowest cost in the set. |

## Inline rows: why the long ones stay

So a future pass does not re-litigate them.

- **`## Writing to the map` (37 lines).** Reached by every branch that resolves anything —
  a grill-only session appends gists too. It guards the only failure in the system that
  destroys data rather than degrading behaviour: 25 KB of decisions flattened to one line in
  #36, with **no GitHub revision history for an API body edit**, so the pre-write copy under
  `.claude/caesar-runs/map-backups/` is the only undo that exists. Everywhere else a pointer
  that fails to fire costs a bad decision; here it costs the map.
- **`## Voice` (42 lines).** Fires on every conversational turn of every branch — there is no
  branch condition a pointer could encode. Considered and rejected: splitting the Latin
  record (719–724) out as a killed-decision file. Six lines, and the split runs through the
  middle of a paragraph whose *last* sentence carries the generalising criterion — *only
  language Raj reads at full speed is eligible* — which is the part that rules out the whole
  category rather than four instances. Not worth a pointer, and the criterion is the piece
  most likely to be lost in the cut.
- **`## Build work and the merge gate` (27 lines).** The authority gate on the one
  irreversible action Caesar can take, reached from startup read 4 (`gh pr list`) on every
  primary session. It is also already cited by name from a disclosed file —
  `skill/references/prompt-shape.md:56` tells a dispatch prompt to carry "the five things the
  merge gate wants (`SKILL.md`, *Build work and the merge gate*)". Disclosing it would make
  that a pointer chained behind another pointer.
- **`## Starting a session` (25 lines) and `### Register` (20 lines).** Both fire before any
  pointer could: the four reads are the first thing a session does, and the register decides
  caveman-versus-Caesar before the first word of the first turn.
- **`### Where the voice is on, and where it is off` (14 lines).** Governs six output
  surfaces including commits, PR bodies and prompts to centurions — three of which are
  durable artifacts, where drift compounds.
- **`## Out of scope for v1` (11 lines).** Away-mode is a live refusal, and at 11 lines the
  section sits under any sensible disclosure floor. The superseded landing-notification
  record (791–794) is four lines and not worth a pointer of its own.

## Sections whose material splits

Two, and both splits are the point of this ticket — the map's first cut at #109 drew regions
from heading blocks alone, and a heading block under-determines reach.

**`### Reconciling GitHub against the disk` — split at line 93.**

- **Inline, 79–92 (14 lines):** the "a grill session never creates a worktree" frame and the
  **claimed HITL — never touch it, and say nothing** rule, including the empty-frontier
  escape. Every branch reaches this. A grill-only session in particular reaches it and
  reaches nothing else in the region, and it is the rule that stops it stealing a live
  parallel conversation.
- **Disclose, 93–105 (13 lines):** the claimed-AFK-with-nothing-on-disk bullet and the
  one-machine assumption. Only a primary that ran `git worktree list` reaches it, and it
  ends by falling into the failure rules, so it belongs with them.
- **This is the ruling most likely to be wrong.** The claimed-AFK case fires on a *common*
  primary sweep, not a rare one, and the branching test rules on reach rather than frequency.
  If #113's harness shows the pointer missing on an ordinary drive, inline the whole section.

**`## Dispatching a centurion` — split at line 273.**

- **Disclose, 252–272 (21 lines):** the spawn script, the `prompt-shape.md` pointer, the
  gist contract, "never treat an exit code as evidence", the nested-`bypassPermissions` rule.
  Only a session that actually fires reaches any of it.
- **Inline, 273–277 (5 lines):** the concurrency cap and `-BudgetUsd`. `## The loop` step 2
  says AFK work goes out "up to the cap, queue the rest" — a session must hold the number to
  queue correctly, and it makes that scheduling decision before it reaches any dispatch
  material. **Frozen: the concurrency cap's wording is fixed wherever it lands.**

## Cross-region dependencies

Where the split leaves a reference pointing across a file boundary. Each is a site #113 must
convert into a pointer or reword.

| From | To | Now |
|---|---|---|
| `SKILL.md:65` — the map body "is the entire corpus behind *you are the smell test*" | `### Reporting mid-grill` | inline → disclosed |
| `SKILL.md:69` — startup read 3, "arm the watcher before anything else" | `### The watcher` | inline → disclosed; the watcher's **second firing site**, and the reason its pointer must fire from startup as well as from dispatch |
| `SKILL.md:96` — "fall into the failure rules above" | `## When a centurion fails` | disclosed → disclosed (file to file) |
| `SKILL.md:239` — loop step 4, "the watcher below" | `### The watcher` | inline → disclosed |
| `SKILL.md:350` — Tail tier, "(see the failure table)" | `## When a centurion fails` | disclosed → disclosed |
| `SKILL.md:489`, `:501` — escalate "once at Heavy" | `### The dispatch rubric` tier vocabulary | disclosed → disclosed |
| `SKILL.md:620` — veto, "stamp `caesar:needs-raj`" | ``### Flagging: `caesar:needs-raj` `` | disclosed → disclosed |
| `references/prompt-shape.md:56` — "the five things the merge gate wants" | `## Build work and the merge gate` | disclosed → **inline** (resolved; this is why row 22 stays) |
| `references/prompt-shape.md:58` — "This part is also the Execute gate" | `### The dispatch rubric` | disclosed → disclosed |
| `SKILL.md:584` — "crossing the Rubicon (see *Voice*)" | `## Voice` | inline → inline (no action) |

## Totals

| | Lines |
|---|---|
| Preamble, lines 1–36 (no heading) | 36 |
| Inline heading material | 267 |
| **Inline subtotal** | **303** |
| Disclosed | 491 |
| **File total** | **794** |

Pointers added to the inline body: **9**, one per reference file, at roughly two lines each —
call it 18 lines. So `SKILL.md` lands near **320 lines**, down from 794, a 60% cut to what
every session carries.

## Proposed layout under `skill/references/`

| File | Source lines | Lines | Pointer fires when |
|---|---|---|---|
| `prompt-shape.md` *(exists, #104)* | — | 83 | composing a dispatch prompt |
| `dispatch.md` | 252–272, 278–406, 458–468 | 161 | the sweep hands you an unblocked AFK ticket to fire |
| `failure.md` | 93–105, 469–562 | 107 | a run errors, dies, goes quiet, or lands an artifact you will not accept |
| `charting.md` | 155–226 | 72 | `/caesar` with no map URL |
| `watcher.md` | 407–457 | 51 | your first dispatch, **and** a live `ticket-N-*` found at startup |
| `veto.md` | 604–638 | 35 | Raj rejects a decision already closed and written into the map |
| `worktrees.md` | 106–118, 639–652 | 27 | `git worktree list` returns anything |
| `multi-map.md` | 653–670 | 18 | a second map, or "which maps am I driving" |
| `grill-only.md` | 135–146 | 12 | the `grill-only` argument is present |
| `design-rationale.md` | 147–154 | 8 | a future pass proposes a `startup.ps1` |

Disclosed total **491**, matching the ruling.

Two notes for #113:

- **`grill-only.md` has the strongest possible trigger** — a literal token in Raj's own
  command — and is the one disclose row whose pointer is near-certain to fire. It is the
  cheapest place to prove the harness works, not the place to spend pointer-wording effort.
- **`design-rationale.md` at 8 lines is a file barely worth a pointer.** The honest
  alternative is deleting the section outright, since it changes no runtime behaviour. That
  is a content change and out of scope here, where `SKILL.md` keeps every byte — raising it
  as a recommendation, not a ruling.
