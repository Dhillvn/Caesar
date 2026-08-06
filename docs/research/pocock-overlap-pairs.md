# Pocock overlap pairs — decision-grade comparison

Ticket: [#89](https://github.com/Dhillvn/Caesar/issues/89). Follows the collision inventory in
[#85](https://github.com/Dhillvn/Caesar/issues/85), whose one-line notes are **not** the basis for
anything below — every judgement here comes from reading the files.

**Sources read (every file in each folder, not just `SKILL.md`):**

- Plugin side: `github.com/mattpocock/skills`, cloned at tag `v1.2.2` (resolves to commit `8b36d4f`)
  into a scratch dir. Skills at `skills/<category>/<name>/`.
- Local side: `C:\Users\rajdh\.claude\skills\<name>\`.
- Superpowers side: `C:\Users\rajdh\.claude\plugins\cache\claude-plugins-official\superpowers\6.1.1\skills\<name>\`.
- Caveman side: `C:\Users\rajdh\.claude\plugins\cache\caveman\caveman\655b7d9c5431\skills\caveman-review\`.

Nothing outside this repo was created, moved, edited or deleted.

---

## Summary table

| # | Plugin skill | Local counterpart | Deletable side | Recommendation |
|---|---|---|---|---|
| 1 | `tdd` (Pocock) | `superpowers:test-driven-development` | Neither (both plugins) | **Coexist, with one real conflict** — Pocock says refactoring is *not* in the loop; Superpowers makes REFACTOR a loop phase. Also Pocock gates tests on user-confirmed seams; Superpowers forbids any production code without a test. Pick one as canonical in `CLAUDE.md`. |
| 2 | `diagnosing-bugs` (Pocock) | `superpowers:systematic-debugging` | Neither (both plugins) | **Coexist, no hard conflict** — different orderings of the same discipline (loop-first vs root-cause-first), and they contradict on hypothesis count (3–5 ranked vs a single hypothesis). Prefer `diagnosing-bugs` for hard/perf bugs, `systematic-debugging` for multi-component/CI failures. |
| 3a | `code-review` (Pocock) | `numen-stack-review` (local folder) | Yes | **Keep.** Not redundant — it is a stack-lens layer (Supabase RLS, RSC/Server Actions, write-path data integrity, an explicit false-positive gate) that Pocock's two-axis review has no equivalent for. Fix its stale reference to Claude Code's native `/code-review`. |
| 3b | `code-review` (Pocock) | `codex-review` (local folder) | Yes | **Keep — and the #85 note is wrong.** `codex-review` reviews *plans*, not code, via an adversarial Codex loop. Zero overlap with `code-review`. |
| 3c | `code-review` (Pocock) | `superpowers:requesting-` / `receiving-code-review` | No (plugins) | **Coexist.** Requesting is a thinner version of the same dispatch job; receiving is a different job entirely (how to respond to feedback). |
| 3d | `code-review` (Pocock) | `caveman:caveman-review` | No (plugin) | **Coexist.** It is an output-format skill, not a review procedure. |
| 4 | `grill-me` | `grill-me-codex` | Yes (local) | **Keep.** Act 1 duplicates `grill-me`, but Act 2 (bounded, read-only, cross-model Codex adversarial loop) exists nowhere in the plugin. |
| 5 | `grill-with-docs` | `grill-with-docs-codex` | Yes (local) | **Keep, but re-point Act 1.** Act 2 is unique; Act 1 is an inlined copy of an *older* `grill-with-docs` and should delegate to the plugin's `/grilling` + `/domain-modeling` instead. |
| 6 | `handoff` | `save-session` | Yes (local) | **Keep.** `handoff` is a 9-line prose instruction with no fixed schema, one file, no resume side. `save-session` is a named-workstream store with a mandatory WHAT-NOT-TO-RETRY section and RESUME / RESUME-ALL / CLEAR modes. |

**Net: nothing on the deletable side should be retired.** All four deletable local skills
(`numen-stack-review`, `codex-review`, `grill-me-codex`, `grill-with-docs-codex`, `save-session`)
carry procedure the plugin does not have.

---

## Pair 1 — `tdd` (Pocock, plugin) vs `superpowers:test-driven-development` (plugin)

Neither is deletable; both are plugin skills. So the question is conflict vs coexistence.

### 1. What each one actually does

**Pocock `tdd`** (`SKILL.md` + `tests.md` + `mocking.md`, ~7.4 KB) is a *reference*, not a loop
driver. It states up front: "TDD is the red → green loop. This skill is the reference that makes
that loop produce tests worth keeping." Its four sections are: what a good test is (behaviour
through public interfaces); **seams** — "Test only at pre-agreed seams… No test is written at an
unconfirmed seam", with an instruction to ask the user "What's the public interface, and which
seams should we test?"; three named anti-patterns (implementation-coupled, tautological,
horizontal slicing → work in vertical slices / tracer bullets); and three rules of the loop.
`tests.md` gives good/bad TypeScript pairs including the tautological case; `mocking.md` says mock
only at system boundaries and prescribes DI + SDK-style interfaces over generic fetchers. It also
tells you to read `CONTEXT.md` so test names use the project's domain language, and defers
interface-shape questions to `/codebase-design`.

**`superpowers:test-driven-development`** (`SKILL.md` + `testing-anti-patterns.md`, ~18 KB) is a
*compliance loop*. It states an Iron Law — "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST" — and
"Write code before the test? Delete it. Start over… Delete means delete." It walks
RED → verify-red → GREEN → verify-green → REFACTOR as mandatory gated steps (a Graphviz diagram of
the cycle), with "Verify RED — Watch It Fail. **MANDATORY. Never skip.**" Roughly half the file is
anti-rationalisation material: a "Why Order Matters" essay, an 11-row Common Rationalizations
table, a 13-item Red Flags list, a "When Stuck" table, and an 8-box Verification Checklist ending
"Can't check all boxes? You skipped TDD. Start over."

### 2. What Superpowers has that Pocock does not

- The Iron Law and the delete-and-restart rule. Pocock never says to delete existing code.
- Mandatory *verify* steps between phases (watch it fail; watch it pass; output pristine).
- The whole rationalization-defence apparatus (Common Rationalizations, Red Flags, Why Order Matters).
- An explicit REFACTOR phase inside the cycle.
- A completion checklist ("every new function/method has a test").

### 3. What Pocock has that Superpowers does not

- **Seams as a gated, user-confirmed concept** — "No test is written at an unconfirmed seam", plus
  the acknowledgement "You can't test everything". Superpowers has no seam vocabulary and demands
  a test for every new function.
- The **tautological test** anti-pattern with a worked example (expected value recomputed the way
  the code computes it). Superpowers does not name this failure.
- **Horizontal slicing** named as an anti-pattern, with the vertical-slice / tracer-bullet remedy.
- Domain-language integration: read `CONTEXT.md`, respect ADRs, hand interface-shape questions to
  `/codebase-design`.
- Explicit statement that **refactoring is not part of the loop** — it belongs to review.

### 4. Is the local one strictly redundant?

**No.** Each carries material the other lacks: Superpowers owns discipline enforcement, Pocock owns
test-quality judgement (seams, tautology, slicing).

### 5. Is there a real conflict when both load?

**Yes, two.**

1. **Refactoring.** Pocock: "Refactoring is not part of the loop. It belongs to the review stage."
   Superpowers: REFACTOR is a phase of the cycle, entered after every green. An agent holding both
   gets contradictory instructions about what to do after a test passes.
2. **Coverage scope.** Pocock gates every test on a seam the *user* has confirmed and concedes you
   cannot test everything. Superpowers' checklist requires "Every new function/method has a test"
   and treats any exception as rationalization. On a change touching unconfirmed seams these give
   opposite answers.

Otherwise they agree (behaviour over implementation, mock only at boundaries, real code over mocks)
and are complementary. Recommendation: name one as canonical in `CLAUDE.md` — Superpowers for the
loop rules, Pocock for what to test and where — and explicitly state that refactoring happens at
review, so the conflict resolves in one direction.

---

## Pair 2 — `diagnosing-bugs` (Pocock, plugin) vs `superpowers:systematic-debugging` (plugin)

Neither is deletable.

### 1. What each one actually does

**Pocock `diagnosing-bugs`** (8.7 KB `SKILL.md` + `scripts/hitl-loop.template.sh`) is a six-phase
discipline whose thesis is that the *feedback loop is the skill*: "Phase 1 — Build a feedback loop.
**This is the skill.** Everything else is mechanical." It gives ten ranked ways to build one
(failing test → curl → CLI+snapshot → headless browser → replay a captured trace → throwaway
harness → property/fuzz → bisection harness → differential loop → HITL bash script), then a
"tighten the loop" section (faster, sharper signal, more deterministic) and a non-determinism
section (raise the repro *rate*, don't chase a clean repro). Phase 1 has a hard completion gate:
one named command you have already run and pasted output for, which is red-capable, deterministic,
fast and agent-runnable — "No red-capable command, no Phase 2." Phase 2 reproduces then **minimises**
(cut one element at a time until every remaining element is load-bearing). Phase 3 requires **3–5
ranked falsifiable hypotheses** shown to the user before testing any. Phase 4 instruments with
tagged `[DEBUG-a4f2]` logs (so cleanup is one grep) and a separate perf branch (measure, then
bisect). Phase 5 writes the regression test first *only if a correct seam exists* — and if none
does, "that itself is the finding". Phase 6 is a cleanup checklist plus a post-mortem that hands
architectural findings to `/improve-codebase-architecture`. The shipped `hitl-loop.template.sh` is
a real bash harness with `step`/`capture` helpers that drives a human through a manual repro and
prints `KEY=VALUE` back for the agent.

**`superpowers:systematic-debugging`** (9.9 KB `SKILL.md` plus `root-cause-tracing.md`,
`defense-in-depth.md`, `condition-based-waiting.md` + example, `find-polluter.sh`, and three
test-pressure scenario files) is a four-phase discipline whose thesis is root cause first: "NO
FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST". Phase 1 is read errors → reproduce → check recent
changes → **gather evidence at every component boundary in multi-component systems** (a worked
CI→build→signing→codesign example that localises which layer fails) → trace data flow backward.
Phase 2 is pattern analysis (find working examples, read the reference implementation completely,
list every difference). Phase 3 is a **single** clearly-stated hypothesis, tested minimally. Phase 4
implements one fix, and carries a distinctive escalation: **after 3 failed fixes, stop and question
the architecture** rather than attempting fix #4. It also lists user signals that you're doing it
wrong ("Stop guessing", "Is that not happening?").

### 2. What Superpowers has that Pocock does not

- The **multi-component boundary instrumentation** recipe — log what enters/exits each layer, run
  once, find the failing layer. Pocock's Phase 4 instruments *hypotheses*, not layers.
- The **3-failed-fixes → question the architecture** circuit breaker.
- `find-polluter.sh` (test-pollution bisection) and `condition-based-waiting.md` (replace arbitrary
  timeouts with condition polling) — concrete techniques for flaky-test and timing bugs.
- `root-cause-tracing.md` (backward call-stack tracing) and `defense-in-depth.md`.
- A "your human partner's signals you're doing it wrong" section.

### 3. What Pocock has that Superpowers does not

- The **entire feedback-loop-construction discipline**: ten ranked loop types, the tighten step, and
  the hard red-capable/deterministic/fast/agent-runnable gate with pasted evidence. Superpowers says
  "reproduce consistently" in four bullets and moves on.
- The **minimisation** phase (shrink until every element is load-bearing).
- **3–5 ranked falsifiable hypotheses shown to the user before testing**, each stating its prediction.
- Non-deterministic strategy framed as *raising the reproduction rate* (50% is debuggable, 1% is not).
- Tagged-prefix debug logs for one-grep cleanup.
- The **perf branch** — for regressions, logs are wrong; baseline-measure then bisect.
- The "no correct seam is itself the finding" rule in Phase 5.
- `hitl-loop.template.sh` — a runnable human-in-the-loop harness.

### 4. Is the local one strictly redundant?

**No.** They overlap on the shared spine (don't guess, reproduce, one variable at a time, test the
fix) but each holds a large body the other lacks.

### 5. Is there a real conflict when both load?

**No hard conflict, one soft contradiction.** Pocock demands 3–5 ranked hypotheses *before* testing
any; Superpowers Phase 3 says "Form Single Hypothesis". Both then test minimally and one variable at
a time, so the practical divergence is small — generate several, test one. Ordering also differs
(Pocock builds the loop before theorising; Superpowers reads errors and traces data flow first), but
neither forbids the other's step, so they compose: build the Pocock loop, use the Superpowers
boundary instrumentation inside it. Recommendation: reach for `diagnosing-bugs` on hard,
intermittent or performance bugs where the repro is the problem, and `systematic-debugging` on
multi-component / CI / integration failures where locating the failing layer is the problem.

---

## Pair 3 — `code-review` (Pocock, plugin) vs four local/plugin counterparts

### 3.0 What the plugin `code-review` actually does

Two-axis review of `git diff <fixed-point>...HEAD`, run as **two parallel `general-purpose`
sub-agents** so the axes do not pollute each other's context:

- **Standards** — repo-documented standards (`CODING_STANDARDS.md`, `CONTRIBUTING.md`) *plus* a fixed
  **smell baseline** of 12 Fowler smells pasted verbatim into the sub-agent prompt (Mysterious Name,
  Duplicated Code, Feature Envy, Data Clumps, Primitive Obsession, Repeated Switches, Shotgun
  Surgery, Divergent Change, Speculative Generality, Message Chains, Middle Man, Refused Bequest),
  each with a fix. Two binding rules: the repo overrides the baseline, and every smell is a
  judgement call, never a hard violation.
- **Spec** — does the diff faithfully implement the originating issue/spec? Finds missing
  requirements, scope creep, and wrong implementations, quoting the spec line for each.

It pins and validates the fixed point first (`git rev-parse`, non-empty diff) so a bad ref fails
before two sub-agents spawn, resolves the spec via `docs/agents/issue-tracker.md`, and then
**aggregates without reranking** — the two axes are reported separately by design, "so one axis
can't mask the other". No security axis, no stack awareness, no severity scale.

### 3a — `numen-stack-review` (local folder, **deletable**)

**1. What it does.** A conditional lens layer, explicitly *not* a generic reviewer: "This skill does
NOT re-implement generic correctness/security review — that's the native skills' job." Workflow:
scope the diff (`git diff --staged` → `git diff` → `git show HEAD`), run a baseline review first,
then apply only the lenses whose triggering code is present — write path → `data-integrity.md`
("always run if a write path exists. This is Raj's top risk"); any `try`/`catch` →
`silent-failure.md`; `.sql`/Supabase migration/`.from(`/`.rpc(` → `rls-supabase.md`; `.tsx`/
`"use client"`/`"use server"` → `rsc-server-actions.md`; any TS/JS → `typescript.md`; test files →
`test-quality.md` (MEDIUM ceiling). Every finding must then clear `reference/fp-gate.md` — a
false-positive catalogue plus a 4-question pre-report gate — and "Zero findings is a valid, expected
outcome; don't invent filler". Output is `path:line — [LENS] SEVERITY: problem. Fix:` grouped
CRITICAL→LOW with a count table and a **PASS / WARN / FAIL verdict** (FAIL on any CRITICAL). Strictly
READ-ONLY.

**2. What the local one has that the plugin does not.** Everything stack-specific: Supabase RLS and
multi-tenant isolation, the Next.js Server-Action/RSC trust boundary, write-path data integrity as a
named top risk, the silent-failure lens (which is exactly the failure family this Caesar repo's own
`CLAUDE.md` documents), a severity scale with a ship/no-ship verdict, and the false-positive gate
requiring snippet + concrete failure scenario + why existing guards miss it before a HIGH/CRITICAL is
allowed. Pocock's review has no severity, no verdict, no FP gate, and no stack knowledge.

**3. What the plugin has that the local one does not.** The Fowler smell baseline as a portable
standard; the Spec axis (does the diff match the originating issue?) — `numen-stack-review` never
compares against a spec; parallel sub-agent isolation; and the explicit fixed-point/merge-base
discipline (`numen-stack-review` reviews staged/unstaged/HEAD, not an arbitrary range).

**4. Strictly redundant?** **No.** The two barely intersect: one asks "does this diff follow this
repo's standards and its spec", the other asks "does this write path corrupt data / does this RLS
policy leak tenants".

**5. Retire?** **Keep** — the Supabase/RSC/data-integrity lenses and the false-positive gate have no
counterpart anywhere in the plugin. One repair worth making at cutover: step 2 tells it to "run the
native `/code-review` and `security-review` skills" as its baseline, and `/code-review` now resolves
to Pocock's two-axis skill rather than whatever it meant when written — worth re-pointing explicitly
so the baseline it composes over is the one intended.

### 3b — `codex-review` (local folder, **deletable**)

**1. What it does.** **It does not review code.** Its own first rule of "What NOT to do" is "Don't
use this to review existing code". It is an adversarial *plan*-review loop: Claude writes `PLAN.md`
(Goal / Approach / Key decisions & tradeoffs / Risks / Out of scope), then hands it to OpenAI Codex
as a read-only critic across up to `MAX_ROUNDS` (default 5) rounds, resuming the same Codex session
each round so it remembers its earlier critiques. Each round appends the full critique to
`PLAN-REVIEW-LOG.md` plus Claude's response (what changed, what was rejected and why); the loop ends
on `VERDICT: APPROVED` or at the cap, where deadlock is surfaced honestly rather than faked. Two
human gates only: kickoff and final sign-off. No code is written during the loop.

**2. What the local one has that the plugin does not.** All of it — cross-model review, and in
particular the safety detail it calls "the single most important safety detail in this skill":
`codex exec` accepts `-s read-only`, but `codex exec resume` *rejects* `-s`, so resume must force
`-c sandbox_mode="read-only"` or Codex inherits a `config.toml` that may be `danger-full-access` and
could write files mid-loop. Also the version floor (`codex --version` ≥ 0.130), the do-not-pin-`-m`
rule (pinning `gpt-5.x-codex` 400s on ChatGPT-account auth), the append-only argument transcript as
the deliverable, and a Drive-workspace rule that `PLAN.md`/`PLAN-REVIEW-LOG.md` must be written into
`Numen/Operations/<workstream>/` and never the Drive root, where they would overwrite the previous
pair.

**3. What the plugin has that the local one does not.** Everything about reviewing actual code — a
diff, standards, smells, spec conformance.

**4. Strictly redundant?** **No — the #85 pairing is wrong.** These skills share a word, not a job:
one reviews a written diff, the other argues about a plan before any code exists. The plugin's
nearest relative to `codex-review` is `grilling`/`grill-me`, not `code-review`.

**5. Retire?** **Keep.** Retiring it would delete the only cross-model adversarial review Raj has,
including the verified Codex sandbox-flag safety rule that exists nowhere else.

### 3c — `superpowers:requesting-code-review` / `receiving-code-review` (plugins, not deletable)

**1. What they do.** `requesting-code-review` captures `BASE_SHA`/`HEAD_SHA` and dispatches one
`general-purpose` sub-agent filled from the `code-reviewer.md` template with four placeholders
(description, plan/requirements, base, head), deliberately withholding session history so the
reviewer judges the work product and the caller's context is preserved. It states when review is
mandatory (after each task in subagent-driven development, after a major feature, before merge) and
a Critical/Important/Minor triage. `receiving-code-review` is the other half of the transaction —
how to *respond* to feedback: read → understand → verify against codebase reality → evaluate →
respond → implement one at a time; forbidden responses ("You're absolutely right!", any gratitude);
clarify *all* unclear items before implementing any; be more skeptical of external reviewers than of
your human partner; a YAGNI check (grep for actual usage before "implementing properly"); and how to
concede gracefully when your pushback was wrong.

**2/3. Difference.** `requesting-code-review` is a thinner version of the same dispatch job Pocock's
`code-review` does: one sub-agent vs two, plan-conformance only vs an explicit Standards axis, no
smell baseline, no fixed-point validation. What it adds is the *when* (mandatory review points in
the Superpowers workflow) and the deliberate context-isolation rationale. `receiving-code-review`
overlaps with nothing in Pocock's skill at all.

**4. Strictly redundant?** `requesting-code-review`: **partly** — Pocock's `code-review` is a
strictly richer version of the same dispatch, but it is user-invoked around a fixed point while
`requesting-code-review` is the automatic checkpoint inside Superpowers' plan-execution workflow.
`receiving-code-review`: **no**, different job.

**5. Conflict?** None. Neither is deletable anyway. They compose: request review with Pocock's
two-axis skill, respond to it with `receiving-code-review`.

### 3d — `caveman:caveman-review` (plugin, not deletable)

**1. What it does.** A *format* skill, not a procedure. It prescribes one line per finding —
`L<line>: <problem>. <fix>.` or `<file>:L<line>: …` — with optional severity prefixes
(`🔴 bug:` / `🟡 risk:` / `🔵 nit:` / `❓ q:`), a drop-list (no "I noticed that…", no hedging, no
restating the diff) and a keep-list (exact line numbers, symbol names in backticks, a concrete fix,
the *why* when non-obvious). It has an Auto-Clarity carve-out — drop terse mode for security
findings, architectural disagreements, and onboarding — and a Boundaries section: reviews only,
never writes the fix, never approves, never runs linters.

**2/3. Difference.** It contains no instruction about *what* to look for, no diff-scoping, no axes.
Pocock's skill contains no output-format rules beyond "under 400 words".

**4. Strictly redundant?** **No** — orthogonal layers: one decides what to report, the other how to
phrase it.

**5. Conflict?** None, and it is not deletable. It composes cleanly with either reviewer.

---

## Pair 4 — `grill-me` (plugin) vs `grill-me-codex` (local, **deletable**)

### 1. What each one actually does

**`grill-me`** at v1.2.2 is a **thin user-invoked launcher**: 154 bytes, frontmatter plus one line —
"Run a `/grilling` session." (`disable-model-invocation: true`, and `agents/openai.yaml` sets
`policy.allow_implicit_invocation: false`, so it is human-reachable only). All the substance lives in
the separate `grilling` skill: interview relentlessly, map a **design tree**, work it in **rounds**
where the **frontier** is every decision whose prerequisites are settled, ask the whole frontier in
one round with numbered `❓ **Q1**` questions each carrying a `➡️` recommended answer, dispatch a
sub-agent for any fact the environment can answer, and finish when the frontier is empty.

**`grill-me-codex`** is two acts. **Act 1** is a verbatim-in-spirit copy of the grill prompt
(attributed to Pocock under MIT in `THIRD-PARTY-NOTICES.md`), ending by writing the agreed plan to
`PLAN.md` in a fixed five-section structure and initialising `PLAN-REVIEW-LOG.md`. **Act 2** is the
`codex-review` adversarial loop described in 3b — same `MAX_ROUNDS=5` cap, same read-only Codex,
same `VERDICT: APPROVED|REVISE` protocol, same "Claude is final arbiter", same deadlock honesty.

### 2. What the local one has that the plugin does not

- **Act 2 in its entirety** — a second, different model attacking the locked plan. The stated
  rationale: Act 1 fixes "building the wrong thing", Act 2 fixes "a plan that sounds right but
  breaks"; cross-model means no echo chamber.
- The verified Codex mechanics: `-s read-only` on first call, `-c sandbox_mode="read-only"` on every
  resume (resume rejects `-s`), `--version` ≥ 0.130, do not pin `-m`, `2>/dev/null` for cosmetic
  stderr, confirm success by verdict-file + `thread.started`.
- A fixed `PLAN.md` schema and an append-only `PLAN-REVIEW-LOG.md` as the deliverable.
- The Drive-root artefact rule (write `PLAN.md` into `Numen/Operations/<workstream>/`, never the
  Drive root, or each run overwrites the last).
- Explicit MIT attribution for the borrowed act.

### 3. What the plugin one has that the local one does not

The **current** grilling procedure. `grill-me-codex`'s Act 1 is frozen at the older
one-question-at-a-time formulation ("Ask the questions one at a time, waiting for my answer"),
whereas plugin `grilling` v1.2.2 now works in **frontier rounds** with a question format and
sub-agent fact-finding. Delegating (as `grill-me` does) means Act 1 stays current for free.

### 4. Is the local one strictly redundant?

**No.** Act 1 is redundant with `grill-me`; Act 2 has no plugin counterpart.

### 5. Retire the local one?

**Keep.** Deleting it would remove the cross-model adversarial half, which is the entire reason the
skill exists. Worth doing at cutover, though: replace the inlined Act 1 with "run `/grilling`", so
the interview half tracks the plugin instead of drifting.

---

## Pair 5 — `grill-with-docs` (plugin) vs `grill-with-docs-codex` (local, **deletable**)

### 1. What each one actually does

**`grill-with-docs`** at v1.2.2 is another thin launcher (252 bytes, user-invoked only): "Run a
`/grilling` session, using the `/domain-modeling` skill." The substance is in `grilling` (above) plus
`domain-modeling`: challenge terms that conflict with `CONTEXT.md`, sharpen fuzzy language, invent
edge-case scenarios, cross-reference claims against code, update `CONTEXT.md` **inline** as terms
resolve (never batched, glossary only, no implementation details), and offer an ADR only when all
three of hard-to-reverse / surprising-without-context / result-of-a-real-trade-off hold — with
`CONTEXT-FORMAT.md` and `ADR-FORMAT.md` as the formats.

**`grill-with-docs-codex`** inlines that whole Act 1 (grill + single/multi-context file layout +
glossary challenge + inline `CONTEXT.md` updates + the three-part ADR test), ships its own copies of
`CONTEXT-FORMAT.md` and `ADR-FORMAT.md`, then runs the same Act 2 Codex loop — with the review prompt
extended to read `CONTEXT.md`/ADRs and to flag **domain-language mismatches** as a finding class.

### 2. What the local one has that the plugin does not

- Act 2 (as pair 4), plus the domain-aware review prompt — Codex is told to read `CONTEXT.md` and the
  ADRs and to treat domain-language mismatch as a flaw class.
- The `PLAN.md` header convention `_Locked via grill-with-docs — … Terms per CONTEXT.md._` and the
  instruction to write the plan in the project's ubiquitous language.
- The Drive-root artefact rule and MIT attribution, as above.

### 3. What the plugin one has that the local one does not

Currency and separation of concerns. The plugin splits the job into `grilling` + `domain-modeling`,
so both improve independently; `grill-with-docs-codex` froze a copy of both. Its Act 1 grill text is
the older one-at-a-time formulation, not the frontier-rounds one. Its `CONTEXT-FORMAT.md` and
`ADR-FORMAT.md` are byte-identical to the plugin's current copies, so the format side has not
drifted — but nothing keeps it from drifting.

### 4. Is the local one strictly redundant?

**No** — same shape as pair 4: Act 1 redundant, Act 2 unique.

### 5. Retire the local one?

**Keep, and re-point Act 1.** Replace the inlined grill + domain-modeling body with a delegation to
`/grilling` and `/domain-modeling`, keeping only the Act 1→Act 2 handoff (the `PLAN.md` schema and
log initialisation) and Act 2 itself. That deletes ~90 lines of frozen copy and its two duplicated
format files while losing nothing.

### Related finding (outside the six pairs)

`C:\Users\rajdh\.claude\skills\` also holds **local copies of the Pocock skills themselves** —
`grilling`, `domain-modeling`, `codebase-design`, `prototype`, `research`, `implement`,
`improve-codebase-architecture`, `to-spec`, `to-tickets`, `teach`, `wayfinder`,
`setup-matt-pocock-skills` — dated 2026-07-24, alongside a `MATT-POCOCK-NOTICE.md`. These are **not**
symlinks into the upstream repo (only `caesar` is a symlink), so they are frozen at whatever v1.2.2
predecessor was current then. Verified by diff:

- `grilling` — **materially stale**. Local is the one-question-at-a-time version; plugin v1.2.2 is
  the design-tree / frontier-rounds version with the `❓ Q1` format and sub-agent fact-finding.
- `domain-modeling` — identical apart from line endings (local CRLF, plugin LF).

Since a local skill never shadows a plugin skill (#84), the practical effect is a duplicate
`grilling` entry whose local copy is out of date. Worth folding into the cutover ticket (#88).

---

## Pair 6 — `handoff` (plugin) vs `save-session` (local, **deletable**)

### 1. What each one actually does

**`handoff`** (895 bytes, user-invoked only, `argument-hint: "What will the next session be used
for?"`) is nine lines of prose instruction: write a handoff document summarising the current
conversation so a fresh agent can continue; **save it to the OS temp directory, not the workspace**;
include a "suggested skills" section naming skills the next agent should invoke; do not duplicate
content already captured in specs, plans, ADRs, issues, commits or diffs — reference them by path or
URL; redact secrets and PII; and if arguments were passed, treat them as the next session's focus and
tailor the doc. There is **no fixed section schema and no read side** — nothing in the skill reads a
handoff back.

**`save-session`** is a three-mode store keyed by workstream. Files live at
`~/.claude/session-handoff-<slug>.md`, one per named workstream, each overwritten only by its own
save, so saving workstream B never clobbers A. Every file opens with a `Project:` line (the cwd leaf
folder) as a cross-project guard. **SAVE** writes a fixed six-section schema: one-line state,
✅ WORKED, ❌ DID NOT WORK + WHY, 🔲 NOT TRIED YET, ▶ EXACT NEXT STEP, ⛔ WHAT NOT TO RETRY — the last
of which is **mandatory** ("it is the whole point"; if nothing was ruled out, write
`- (nothing ruled out yet)`, never delete the section), with a specificity rule demanding full file
paths, exact commands and exact error text. **SAVE-ALL** runs SAVE per in-flight workstream.
**RESUME** reads the named file, warns if its `Project:` line disagrees with the current cwd, and
briefs **WHAT NOT TO RETRY first**, then EXACT NEXT STEP, then a recap — and must not silently
re-attempt anything on the dead-end lists. **RESUME-ALL** globs every handoff and gives a standup.
**CLEAR** deletes a finished workstream's file, with an explicit irreversibility warning and a
confirm gate on `clear all`.

### 2. What the local one has that the plugin does not

- **The dead-ends-first format.** ❌ DID NOT WORK + WHY and the mandatory ⛔ WHAT NOT TO RETRY, and
  the rule that RESUME leads with the latter. `handoff` has no equivalent — a summary of what
  happened is not a record of what was disproven.
- **A resume side at all**, including RESUME-ALL as a morning standup across workstreams.
- **Per-workstream files with slugging**, so several parallel threads coexist rather than one doc.
- **The `Project:` cross-project guard** with a warn-and-wait on mismatch.
- **CLEAR** with an irreversible-deletion warning and a confirm gate on `clear all`.
- A durable location (`~/.claude/`), where `handoff` deliberately writes to the OS temp dir.
- A fixed schema at all — `handoff`'s output shape is left to the model.

### 3. What the plugin one has that the local one does not

- The **"suggested skills" section** — tell the next agent which skills to invoke.
- The **do-not-duplicate rule** — reference specs, plans, ADRs, issues, commits and diffs by path or
  URL instead of restating them.
- An explicit **redact secrets/PII** instruction.
- The **argument hint** ("what will the next session be used for?") so the doc is tailored to the
  next session's purpose.
- Temp-dir placement, which keeps handoffs out of the repo — a real advantage `save-session` gets a
  different way (writing to `~/.claude/`, also outside the repo).

### 4. Is the local one strictly redundant?

**No.** `handoff` writes one untyped document to temp with no way to read it back; `save-session` is
a multi-workstream, schema'd, resumable store whose central asset — the disproven-approaches list —
`handoff` does not ask for.

### 5. Retire the local one?

**Keep.** The mandatory WHAT-NOT-TO-RETRY section plus RESUME/RESUME-ALL is the whole value, and
neither exists in `handoff`. Cheap improvement at cutover: borrow `handoff`'s three good bits —
a suggested-skills line, the reference-don't-duplicate rule, and the redaction instruction — into
`save-session`'s SAVE schema.
