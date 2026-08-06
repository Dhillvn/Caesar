# The pointer standard

A **context pointer** is the line left behind in `SKILL.md` when material moves out of it and
into `references/`. It is the only thing deciding whether a session reaches that material:
the target is already written, the wording is what fires or does not fire. So a block moved
behind a weak line is not disclosed, it is deleted with extra steps.

Derived once from `writing-for-agents`
([#112](https://github.com/Dhillvn/Caesar/issues/112)) so the disclosures on
[#109](https://github.com/Dhillvn/Caesar/issues/109) are written to one rule rather than
improvised six times. Applying it needs nothing but this file.

## 1. What a pointer states

Two things, and it is not finished until it carries both.

**The material** — what is behind the link, in the terms a session would use to ask for it.
Not the file's subject in the abstract: the specific contents it will be reached *for*. *"the
failure table"* is the material. *"notes on failures"* is not.

**The branches that trigger reaching it** — a **branch** is a distinct case the material
handles, so different runs take different paths through it. A branch is written as the
concrete moment in a run: *before you retry*, *before you hand back*, *when the ticket is
HITL*. A pointer that names material but no branch tells a session what exists and never
tells it when to look, which is the common way a disclosed block goes cold.

The form the two make, and the one this file's own pointer takes:

```
**<leading word> — <the material>. <the branch, or branches>:
[`references/<file>.md`](references/<file>.md).
```

The link carries the path. Prose that also announces where the file lives is the path
written twice.

## 2. Choosing the leading word

A **leading word** is a compact concept the model already holds from pretraining, which the
session thinks with while it runs. In a pointer it does the *invocation* work: when the same
word lives in the prompt, in this skill, and in the scripts, the session links that shared
language to the material and reaches it more reliably.

Caesar already runs a set: `frontier`, `fog`, `centurion`, `scout`, `map`, `ticket`, and
*crossing the Rubicon*. These are the pointers' first assets, and they are spent by one rule:

**Lead with the word the session is already holding when the branch fires.** A run about to
kill a stalled process is holding `centurion`; a run picking what to work next is holding
`frontier`. That word, first, is the pointer's strongest hook — put it in the opening token
rather than behind framing like *"for more on…"*.

Three consequences:

- **One running word, one target.** If two pointers both open on `centurion`, neither fires
  cleanly. Qualify with the running word plus the act — *dispatching a centurion*, *a
  centurion that fails* — so the pair stays distinguishable.
- **Where no running word fits, reach for an existing one, not a new one.** *Retry*,
  *dispatch*, *merge*, *worktree* all carry priors. A coined word recruits none: you pay in
  definition tokens what a pretrained word gives free.
- **The word must also be the body's word.** The pointer and the file it reaches share
  vocabulary, or the session that follows the link finds a document that reads as a different
  subject and drops it.

## 3. Pruning a line that is loaded every turn

The body behind a pointer costs only when reached. The pointer costs on every turn, whether
or not it fires, so it earns harder pruning than the material it names.

- **One trigger per branch.** Synonyms renaming a single branch are one branch written twice
  — *before you retry, re-run, or try again* is one branch. Collapse them, keep only branches
  that genuinely take different paths through the material.
- **Cut identity the body already carries.** The file states its own subject in its first
  line. A pointer that also says *this document explains…* or restates the file's title as
  prose buys nothing.
- **Front-load, then stop.** Leading word, material, branches, link. Everything before the
  leading word is load with no trigger in it.
- **The deletion test.** Take any word out. If no branch stops firing, it was never doing
  triggering work — leave it out.

## 4. How strength scales with the cost of a miss

**Strength** is how much of the pointer's line is spent making the session actually go. It is
set by one question: *what happens if this never fires and the session proceeds from memory?*
The costs across this skill differ by an order of magnitude — a missed voice note is
cosmetic, a missed line from the failure table means a centurion is mishandled — so a single
strength for every pointer is either waste or a live bug.

Four rungs. Take the lowest one the cost allows.

1. **Naming.** The session is fine without it; it just reads better with it. Material plus
   one branch, no obligation. *Cosmetic cost — a voice note, a rationale, a piece of history.*
2. **Firm.** Reaching it is stated as a step in the run: *read it before you compose one*.
   Branches named explicitly rather than implied. *Cost is a wasted run or a rework.*
3. **Hard.** Firm, plus the pointer carries the **one fact whose absence is dangerous** — a
   stub inline in the pointer line itself, so a session that never follows the link still
   does not act on a wrong assumption. Say what the miss costs, in the pointer. *Cost is
   silent and unrecoverable: a mishandled centurion, a lost run, `main` touched.*
4. **Inline.** The material does not move. Reserved for what every branch needs anyway —
   disclosure only protects the top of the file when what it pushes down is genuinely
   branch-local.

Climb the ladder in that order, and only on evidence: sharpen the wording first, raise the
strength second, keep it inline last. Reaching for rung 3 on everything spends the line
budget that makes rung 3 legible where it is earned.

## 5. Worked examples

Three, written as they would land in `SKILL.md`, for material this map is likely to disclose.

**A centurion that fails** — *hard*, because the miss is silent: a failure classed from
memory retries a run that needed Raj, and the retry looks like progress.

```
**A centurion that fails** — the failure table: which failures retry, which stamp
`caesar:needs-raj`, which are Raj's call and not yours. Read it before you retry, flag or
kill; a failure classed from memory is the one that reads as progress:
[`references/failure-modes.md`](references/failure-modes.md).
```

The stub is *which are Raj's call and not yours* — the fact a session must not guess at even
if the link is never followed.

**Which tier a ticket takes** — *firm*: the cost of a miss is a ticket dispatched at the
wrong tier, expensive but visible and reversible.

```
**Which tier a ticket takes** — the dispatch rubric: Heavy or Execute, the gate that
separates them, and the one licensed escalation. Read it before you dispatch, and before you
re-fire a run that failed:
[`references/dispatch-rubric.md`](references/dispatch-rubric.md).
```

Two branches, both real — a first dispatch and a re-fire take different paths through the
rubric.

**Voice** — *naming*: the cost of a miss is a report in flat prose, which is cosmetic.

```
**Voice** — the ranks, the address, and the surfaces the flavour is off on:
[`references/voice.md`](references/voice.md).
```

No obligation verb, no cost clause. Both would be spent on a line that changes no decision.
