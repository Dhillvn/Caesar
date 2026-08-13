# Dispatching a centurion

Disclosed from `SKILL.md` ([#113](https://github.com/Dhillvn/Caesar/issues/113)): everything a
session reads once the sweep hands it an unblocked AFK ticket to fire. The tier vocabulary —
Heavy, Execute, Tail — is defined here and used by [`failure.md`](failure.md).

## Dispatching a centurion

`scripts/spawn-ticket-agent.ps1` — one headless `claude -p` process per ticket, each in
its own git worktree. The script carries the flag set and the deny list; fire every dispatch
through it, and do not compose that command by hand.

Right after the dispatch returns, run `scripts/publish-runs.ps1` — the new run's `RUNNING`
row is what makes the gist worth reading from a phone mid-run, and the render is a pull
over the run directories, not a push the spawn needed to make.

**Composing a dispatch prompt** — the ordered shape it takes, and what the guardrail frame
already carries. Read it before you write one; a prompt shaped from memory restates the frame
and leaves the centurion with no bound of its own:
[`references/prompt-shape.md`](references/prompt-shape.md).

The centurion **posts its own resolution comment and closes its own ticket**, then prints a
`GIST:` line. You read only the gist and append it to the map. This keeps your context
cheap and, more importantly, makes verification real.

**Never treat an exit code as evidence of work done.** A run that silently did nothing
exits 0 with `is_error: false` and an empty `permission_denials`. Verify against the
artifact: is the issue closed, does it carry a resolution comment.

**A nested `claude -p --permission-mode bypassPermissions` is auto-denied** by the
parent session's own permission layer. Dropping the flag lets the nested call through.
Any ticket whose method spawns sub-agents of its own hits this.

### The skill block — what the prompt says about skills

A centurion inherits everything an interactive session has: both `CLAUDE.md` files, the
full skill list, the user-level SessionStart hooks. `--worktree` changes only the working
directory ([#72](https://github.com/Dhillvn/caesar/blob/main/docs/research/headless-inheritance.md), four probes through the real
spawn path). So the skill block is an **override layer, not a re-listing** — naming a
skill the agent already holds is dead weight in every dispatch. Three rules, in order:

**1. Write the block as an override of what the centurion already holds; never re-list what
is inherited.** Everything in the global `CLAUDE.md` reaches the
centurion already, including "run `ponytail` before writing code" and caveman mode — #72
caught a probe writing its own refusal in caveman style, which is that hook acting on a
headless agent. Retyping those buys nothing, and repetition is not a strengthener:
whether `ponytail` changes a headless agent's output at all has never been measured.

**2. Never retype an exclusion — the spawn script carries them.** The one banned skill is
`claude-api`, and the ban lives in the guardrail heredoc in
`scripts/spawn-ticket-agent.ps1`, where it reaches every centurion and cannot be
forgotten. **Ban nothing else — every other skill on the machine stays available to the
centurion.** [#73](https://github.com/Dhillvn/caesar/blob/main/docs/research/skill-cost-inventory.md) measured
all 119 `SKILL.md` files on the machine against several hundred real loads: `SKILL.md`
size predicts injection at 0.94×, directory size does not predict it at all, and the
largest ordinary skill is 45 KB — about 6% of the $5.00 cap. `claude-api` injects 898 KB
(~345K tokens, 147% of the cap) only because its bundle has no `SKILL.md` and inlines its
whole reference tree. Cost separates that one skill from the population and cannot rank
the rest against each other, so the old blanket ban on "any other very large reference
skill" banned cheap skills for nothing and is retired.

For a *new* skill, the test is structural, not size: no `SKILL.md` in its directory, or
observed injection ≈ its whole directory size. Threshold **100 KB injected**. Re-run
[`scripts/skill_cost.py`](https://github.com/Dhillvn/caesar/blob/main/scripts/skill_cost.py)
(the Caesar repo's own `scripts/`, not this skill's) after a Claude Code upgrade:
`claude-api`'s bundle grew 799 KB → 898 KB in one patch release. Only Raj adds to the ban; a centurion that wants a banned
skill reads its files off disk.

**3. Name only what the ticket needs and the agent would not reach for.** This is the
per-ticket judgment and the only part you write by hand — one line, no rationale:

| Ticket shape | Name in the prompt |
|---|---|
| design or interface work | `impeccable` |
| review ticket — written code | `mattpocock-skills:code-review`, with the fixed point in the prompt |
| review ticket — a plan, not code | `codex-review` (reviews plans, not code, despite the name — [#89](https://github.com/Dhillvn/caesar/issues/89)) |
| review ticket on the Numen stack (Supabase / Next.js / TS) | also `numen-stack-review` |
| web retrieval | Firecrawl — `ToolSearch` for its tools first, they arrive deferred |
| research past ~5 sources | **nothing — read the sources directly** |

**The NotebookLM expectation is retired, not forgotten.** Never write "have NotebookLM
ingest the sources" into a prompt. If a ticket wants the notebook anyway, its preflight is
`auth check --test` or the real query, and failure is a fallback to reading the sources
directly, not a ticket-ending error.

What paid for that rule:
[#74](https://github.com/Dhillvn/caesar/blob/main/docs/research/notebooklm-headless.md) measured it from inside a real centurion.
Query and ingest are both programmatically capable and neither is blocked by the deny
list, but both ride browser cookies Google expires server-side (~10 days observed),
renewable only by a human signing into a Chromium window — `auth refresh` cannot do it
headless. Worse, `notebooklm auth check` reports *"Authentication is valid"* on a dead
session, so a centurion believes it has access and fails downstream.

### The dispatch rubric — which tier

Every dispatch picks a **tier**, passed as `-Tier` to `spawn-ticket-agent.ps1`. The rubric
governs **dispatched agents only** — `wayfinder:research` tickets and AFK `wayfinder:task`
tickets. Grilling and prototype tickets are HITL, worked by you and Raj in session, and
never reach it.

Tiers are **named pairs**, not a model dial crossed with an effort dial. Independent dials
would be twelve combinations and an argument at every dispatch.

| Tier | Model | Effort | When |
|---|---|---|---|
| **Heavy** | `claude-opus-5` | `medium` | The ticket says *figure out*. Design, forensics, research whose method is open. The thinking is the deliverable. |
| **Execute** | `claude-sonnet-5` | `medium` | The spec is closed. Opus already decided; what remains is carrying it out. |
| **Tail** | `claude-opus-5` | `high` | Never a dispatch choice. Retry-only (see the failure table in [`failure.md`](failure.md)) or an explicit per-map override in the map's **Notes**. |

**Default when in doubt: Heavy.** A wrong Heavy call costs the token-price difference. A
wrong Execute call costs a wasted run plus a re-fire.

**The Execute gate — objective, not a judgment of "well defined".** A ticket is Execute
**only if its prompt states both**:

1. the files or artifact to produce, by name; and
2. the check that proves it is done.

If you cannot write both, it is Heavy. This is deliberately a test you can fail, because
you both write the spec and pick the tier, and the cheap answer is always the one that
looks like less work.

Why a rubric at all, and why this one: you always run on Opus. You read the map, pick the
ticket and write the spec — so the *planning* half of the classic Opus-plans /
Sonnet-executes split is already done, on Opus, before any centurion starts. The centurion
is the executor. The discriminator is therefore not ticket *type* (which predicts nothing)
and not a difficulty rating (unfalsifiable), but **whether the thinking has already
happened**.

**Effort stays `medium` in two tiers of three.** Effort is the larger cost lever — an ~8x
output-token span low→max against Opus's 1.67x over Sonnet — and it acts on all response
tokens including tool calls, so higher effort inflates every turn's cache write. Raj runs
Caesar itself, the hardest role on the machine, at Opus medium and finds it sufficient.
Published high-effort wins are measured on hard benchmark tasks, not on deliberately
bite-sized tickets. Holding effort at medium also keeps the rubric to one live dial.

[#64](https://github.com/Dhillvn/caesar/blob/main/docs/research/sonnet-low-reps.md) measured Sonnet-low as 8.8–15.4% cheaper than
Opus-low at identical (100%) grade, and proposed dropping Execute to `low`. **Raj held it
at `medium`** on 2026-08-05: the fixtures were sub-$0.45 toy cells against real tickets at
$1.58–$2.85, so the saving is unproven at working length, and one live dial is worth more
than a measured single-digit discount. The measurement stands as evidence; the tier does
not move on it.

**The budget cap does not vary by tier.** Flat **$5.00** for every tier. Sonnet's cheaper
tokens mean the cap bites less often, not that it should be set lower.

**The tier is written down, not applied silently.** Every dispatch records tier, model,
effort and the cap actually in force on the run record. A rubric applied silently cannot be
audited, and a call that cannot be checked against its outcome can never be improved.

Worked examples, from this skill's own map:

| Ticket | Tier | Why |
|---|---|---|
| #50 — how does model/effort resolution work | Heavy | Had to design its own probes |
| #55 — corpus cost analysis | Heavy | Chose its own statistics; found the duplicate-record trap |
| #58 — published-evidence survey | Heavy | Contradictory sources; the transfer judgment *was* the deliverable |
| #60 — cap-death forensics | Heavy | Refuted the hypothesis it was handed and rejected the proposed discriminator |
| #56 — run the remaining probes | Execute | Fixtures and graders already exist; test list enumerated |
| #52 — build the flags and write the rubric in | Execute | Named script, named parameters, named text |
| #53 — dogfood two models concurrently | Execute | Acceptance is mechanical |

Note the pattern: **every Execute ticket sits downstream of a resolved decision.**

### Reporting mid-grill

Default: **one gist line, then straight back to the grill question.** The gist, never
the title — a title cannot be judged; the gist is the sentence that will represent that
decision forever, so it is the right unit of review.

Stop the grill only when: the resolution contradicts a locked decision, it drifts
outside the destination, or the centurion errored. **You are the smell test, not Raj** — you
hold the whole map and are far better placed to catch a contradiction, which is the
failure that actually hurts because it silently poisons every downstream ticket.
