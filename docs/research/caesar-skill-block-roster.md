# Caesar's skill-block table, re-derived against the roster that exists now

Ticket [#100](https://github.com/Dhillvn/Caesar/issues/100). Proposal only — `skill/SKILL.md` is
untouched; a later ticket applies this.

The table lives in `skill/SKILL.md`, in **The skill block — what the prompt says about skills**,
under the third rule: *name only what the ticket needs and the agent would not reach for*. It is
governed by the two rules above it, and every row below is judged against all three:

1. **Never re-list what is inherited.** A centurion inherits both `CLAUDE.md` files, the full skill
   list and the user-level SessionStart hooks ([#72](https://github.com/Dhillvn/caesar/issues/72),
   [#76/#81](https://github.com/Dhillvn/caesar/issues/81)). The block is an **override layer**.
2. **Never retype an exclusion.** The one ban is `claude-api`, and it lives in the guardrail
   heredoc in `scripts/spawn-ticket-agent.ps1`. [#73](https://github.com/Dhillvn/caesar/issues/73)
   settled that size does not justify exclusion for anything else.
3. **Name only what the ticket needs and the agent would not reach for.**

Rule 3 is the load-bearing one here, and it has a sharp consequence that most of the verdicts below
turn on: **a skill whose own `description` fires on the words a ticket body already uses is dead
weight in the prompt.** The agent reaches for it unprompted. A row earns its place only when it
*disambiguates* — when several skills fire on the same ticket and the wrong one would win — or when
it *suppresses* a skill the agent would otherwise reach for wrongly.

`writing-for-agents` is **excluded from this ruling** and does not appear in the table below. It is
being ruled on separately by [#101](https://github.com/Dhillvn/Caesar/issues/101).

---

## 1. The current roster

### Local half — `C:\Users\rajdh\.claude\skills\`

27 directory entries, of which **26 are skills**; the 27th is `ertms-kpi-workshop.zip`, an archive,
not a skill directory. All 26 are model-invocable and all 26 appear in a session's skill list:

`agent-audit`, `banner-design`, `caesar`, `codex-review`, `dale-carnegie`, `decision-log`, `design`,
`design-system`, `grill-me-codex`, `grill-with-docs-codex`, `impeccable`, `mcp-health-check`,
`notebooklm`, `numen-bonus-builder`, `numen-flowchart`, `numen-inbox-triage`, `numen-longform-edit`,
`numen-newsletter-corpus`, `numen-repo-guard`, `numen-stack-cards`, `numen-stack-review`,
`save-session`, `todo`, `ui-styling`, `ui-ux-pro-max`, `wispr-flow-style`.

### Plugin half

`claude plugin list --json` reports 12 installed plugins, of which **three are enabled**:
`caveman@caveman`, `ponytail@ponytail`, and `mattpocock-skills@mattpocock` **1.2.2**, installed
2026-08-06. `caveman` and `ponytail` are behavioural modes already carried by the global
`CLAUDE.md`, so under rule 1 they can never be table rows.

`superpowers@claude-plugins-official` **6.2.0** is installed but **disabled** — that is the
"fourteen left". Its `skills/` directory holds exactly 14 skills (`brainstorming`,
`dispatching-parallel-agents`, `executing-plans`, `finishing-a-development-branch`,
`receiving-code-review`, `requesting-code-review`, `subagent-driven-development`,
`systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `using-superpowers`,
`verification-before-completion`, `writing-plans`, `writing-skills`), none of which a centurion can
now reach. Nothing in the current table depended on them.

**`mattpocock-skills` exposes 11 model-invocable skills.** The path from 35 to 11 runs through two
filters, and both must be checked — the count cannot be read off the directory listing:

| Layer | Count | What removes them |
|---|---|---|
| `SKILL.md` files on disk | 35 | — |
| Listed in `.claude-plugin/plugin.json` `skills[]` | 25 | 10 dirs are not registered at all: the four under `skills/misc/` (`git-guardrails-claude-code`, `migrate-to-shoehorn`, `scaffold-exercises`, `setup-pre-commit`) and six under `skills/in-progress/` (`claude-handoff`, `loop-me`, `setup-ts-deep-modules`, `writing-beats`, `writing-fragments`, `writing-shape`). None carries `disable-model-invocation`; they are simply absent from the manifest. |
| Model-invocable | **11** | 14 of the registered 25 carry `disable-model-invocation: true` in frontmatter: `ask-matt`, `grill-me`, `grill-with-docs`, `handoff`, `implement`, `improve-codebase-architecture`, `setup-matt-pocock-skills`, `teach`, `to-questionnaire`, `to-spec`, `to-tickets`, `triage`, `wait-what`, `wayfinder`. |

The 11 a centurion can actually invoke:

`code-review`, `codebase-design`, `diagnosing-bugs`, `domain-modeling`, `grilling`, `prototype`,
`research`, `resolving-merge-conflicts`, `tdd`, `wizard`, `writing-for-agents`.

Note `wayfinder` and `implement` are among the 14 disabled — the workflow Caesar orchestrates is
itself not model-invocable, which is correct: Caesar drives the map, the skill does not drive Caesar.

### MCP servers reachable from a centurion

`firecrawl`, `tavily-search`, and four `claude.ai` connectors (Gmail, Calendar, Drive, Notion), all
user-scoped. This matters to the web-retrieval row — see §3.

---

## 2. The six new arrivals — in-or-out verdicts

| Skill | Verdict | Reason |
|---|---|---|
| `code-review` | **IN**, as a corrected review row | See §3. It is the only skill on the whole roster that reviews *written code* generically. It needs a **fixed point** and its process says to *ask the user* if one is not given — a headless centurion has no one to ask, so the row must carry the fixed point or the skill stalls. |
| `writing-for-agents` | **excluded here** | Ruled by [#101](https://github.com/Dhillvn/Caesar/issues/101). No verdict taken in this ticket. |
| `tdd` | **OUT** | Its process gates on a human: *"Before writing any test, write down the seams under test and confirm them with the user. No test is written at an unconfirmed seam."* A dispatched centurion has no user and no next turn, so the skill either stalls or the agent silently breaks its central rule. Naming it into an AFK prompt would be dispatching an agent into a HITL gate. |
| `diagnosing-bugs` | **OUT** | Pure rule-3 dead weight. Its description fires on *"reports something broken/throwing/failing/slow"* — which is the literal wording of any bug ticket body. The agent reaches for it unprompted, so naming it buys nothing. Nothing competes with it on that trigger, so there is no disambiguation to do either. |
| `resolving-merge-conflicts` | **OUT** | No centurion can reach the state it applies to. A centurion works one branch, opens a **draft PR and stops** — it cannot merge, so an in-progress merge/rebase conflict never exists in its worktree. Its step 5 ("finish the merge/rebase") would also push past the branch-write boundary the spawn prompt sets. |
| `wizard` | **OUT** | It generates a bash script that walks **a human** through steps only a human can perform. A ticket that genuinely needs one is HITL by definition and is never dispatched AFK, so the skill can only be named into a prompt where its output has no audience. |

### The other five model-invocable plugin skills — considered and rejected

Not among the six the ticket names, but they are on the roster now, so they were ruled on too:

| Skill | Verdict | Reason |
|---|---|---|
| `grilling` | **OUT** | `wayfinder:grilling` tickets are HITL, worked by Caesar and Raj in session. They never reach a dispatch, so they never reach the table. |
| `prototype` | **OUT** | Same — `wayfinder:prototype` is a HITL ticket type by the dispatch rubric. |
| `research` | **OUT, with a caution worth carrying elsewhere** | It matches Caesar research tickets closely (investigate, write findings to a Markdown file in the repo) and the agent will reach for it unprompted, so it fails rule 3 on its own. Worse, its description offers to delegate *"reading legwork to a background agent"* — a centurion that backgrounds work and ends its turn has killed its ticket. That is a **guardrail** concern, not a table row; if it ever bites, it belongs in the spawn heredoc alongside the `claude-api` ban, not here. |
| `codebase-design` | **OUT** | Self-describes as *"a reference to consult, not a session to run"*, and `tdd` and `code-review` pull it in themselves when they need the vocabulary. Naming it directly adds nothing. |
| `domain-modeling` | **OUT** | Overlaps the Caesar repo's own documented convention — `CONTEXT.md` + `docs/adr/` per the root `CLAUDE.md`, which every centurion already inherits. Rule 1. |

---

## 3. The existing rows — kept, changed, removed

### Row 1 — design or interface work → `impeccable`

**KEEP, with the parenthetical stripped.**

Current: `` `impeccable` (2.7 MB on disk, 14 KB to load — #73; directory size is not cost) ``

Proposed: `` `impeccable` ``

The row survives, but not for the reason it looks like it survives on. `impeccable`'s description is
enormous and trigger-rich (*design, redesign, shape, critique, audit, polish…*), so the agent would
reach for *a* design skill on its own. What it would not reliably do is reach for **this** one: five
skills on the local roster fire on the same ticket — `design`, `design-system`, `ui-styling`,
`ui-ux-pro-max`, `banner-design`. The row's job is **disambiguation among look-alikes**, which is a
valid rule-3 justification; discovery is not.

The parenthetical must go. Rule 3 says *one line, no rationale*, and the row currently carries a
cost argument in violation of it. The #73 finding it cites is already settled in rule 2's prose two
paragraphs above, so deleting it loses nothing.

### Row 2 — review ticket → `numen-stack-review`, `codex-review`

**CHANGE — split into three rows. The row as written is wrong.**

It calls both named skills "the code-review skills". Neither is one:

- **`codex-review` reviews plans, not code.** [#89](https://github.com/Dhillvn/Caesar/issues/89)
  established this, and the skill's own frontmatter confirms it in terms:
  *"Adversarial plan review… **NOT for reviewing already-written code.**"* Its name reads as a
  code-review skill and the current row cements the misread. This is exactly the collision rule 3
  exists to resolve — but the current row resolves it the wrong way.
- **`numen-stack-review` is stack-scoped, not general.** Its lenses are Supabase RLS/multi-tenant,
  Next.js Server Actions/RSC and TypeScript. Caesar's own repo is PowerShell and Markdown; on a
  Caesar ticket every lens misses. It also declares *"run PROACTIVELY"* and fires on "review my
  code", so on a ticket where it *does* apply the agent reaches for it anyway.

Proposed replacement rows:

| Ticket shape | Name in the prompt |
|---|---|
| review ticket — written code | `mattpocock-skills:code-review`, with the fixed point in the prompt |
| review ticket — a plan, not code | `codex-review` |
| review ticket on the Numen stack (Supabase / Next.js / TS) | also `numen-stack-review` |

Three notes on the first row. Namespace it: `code-review` collides by name with Claude Code's own
built-in `/code-review`, and an unqualified mention picks the wrong one. Carry the fixed point:
the skill's step 1 is *"If they didn't specify one, ask for it"*, and a headless agent that asks a
question stalls the ticket — this is operational necessity, not rationale, so it belongs in the row.
And it is the one review skill that earns discovery as well as disambiguation, because it arrived
today and nothing on the previous roster did its job.

The third row stays because `numen-stack-review` is genuinely the right tool on a Numen-stack
ticket, but it is now conditional rather than unconditional, and "also" marks it as a layer over the
first row rather than a replacement for it.

### Row 3 — web retrieval → Firecrawl

**KEEP, with a retrieval note added.**

Proposed: `` Firecrawl — `ToolSearch` for its tools first, they arrive deferred ``

Firecrawl remains the right pick, and there is now a second web MCP on the machine
(`tavily-search`), which makes naming one of them more useful than it was, not less. The added
clause fixes a real headless failure: **MCP tools are deferred**, listed by name only, and calling
one without `ToolSearch` fails with `InputValidationError`. Both servers also connect *after* the
session starts. A centurion that checks its tool list once and finds nothing callable concludes it
has no web access and reports a blocked ticket — an exit-0 silent failure of exactly the family the
`skill/SKILL.md` verification rule warns about. This is a tool-availability instruction, not
rationale, so it survives the one-line rule.

### Row 4 — research past ~5 sources → **nothing, read the sources directly**

**KEEP unchanged.** This row is a suppression, not a naming, which is the strongest form a rule-3
row can take. It is backed by [#74](https://github.com/Dhillvn/caesar/issues/74): `notebooklm` is on
the local roster and would be reached for, but its auth dies on server-expired cookies and
`auth check` reports *"Authentication is valid"* on a dead session. Nothing on the new roster
changes this, and `research`'s arrival strengthens it — that skill would also happily be reached for
on the same tickets (see §2).

### Any row now dead weight?

**No row is removed outright.** Every one of the four either disambiguates among skills that fire on
the same ticket (rows 1, 2, 3) or suppresses one the agent would reach for wrongly (row 4). What was
dead weight was *inside* rows, not whole rows: row 1's cost parenthetical, and row 2's claim that
`codex-review` reviews code.

---

## 4. Proposed table in full

Replacing the table at `skill/SKILL.md`, under rule 3:

| Ticket shape | Name in the prompt |
|---|---|
| design or interface work | `impeccable` |
| review ticket — written code | `mattpocock-skills:code-review`, with the fixed point in the prompt |
| review ticket — a plan, not code | `codex-review` |
| review ticket on the Numen stack (Supabase / Next.js / TS) | also `numen-stack-review` |
| web retrieval | Firecrawl — `ToolSearch` for its tools first, they arrive deferred |
| research past ~5 sources | **nothing — read the sources directly** |

Four rows became six. Net additions: one genuinely new skill (`mattpocock-skills:code-review`) and
two splits of a row that was conflating three different review jobs. Of the six new arrivals, one is
in, four are out, and one is #101's to rule.

## 5. What this ticket did not change

- `skill/SKILL.md` is untouched. A later ticket applies the table above.
- Rules 1 and 2 above the table are unchanged; the override-layer ruling
  (#72, #76/#81) is settled and was not reopened.
- The `claude-api` ban stays in the guardrail heredoc in `scripts/spawn-ticket-agent.ps1`.
  Nothing here proposes a new ban — the one caution raised (`research` backgrounding work) is
  flagged for a future guardrail ticket, not acted on.
