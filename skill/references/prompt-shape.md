# The dispatch-prompt shape

The shape of what you write below the `--- ticket instructions follow ---` marker when you
dispatch a centurion. Derived once from `writing-for-agents`, so composing a dispatch reads
this instead of re-deriving it
([#101](https://github.com/Dhillvn/Caesar/issues/101) rules the derivation is done and does
not repeat).

## The frame

Above the marker, the guardrail heredoc in `scripts/spawn-ticket-agent.ps1` gives every
centurion the same **frame**: its ticket URL and role; run synchronously because nothing can
wake it; the full skill list inherited and free to use, `claude-api` excepted; write only to
its own ticket and its own branch, never the map body and never another ticket; open a draft
PR and stop; post the resolution, close the ticket, print a 30–60 word `GIST:` line.

Every one of those is already in the centurion's context when it reads your half. Write them
again and you have two authorities for one meaning — the thing a **single source of truth**
forbids — and you inflate them past the ticket's own material on the page.

You write about the frame in one case: to **override** it. A research ticket that ends at a
pushed branch rather than a PR states that end state and says it replaces the frame's.

## The five parts

In this order. A part with nothing to say is left out; the order of the rest holds.

**1. The job, in one sentence, first line.** What this centurion is for, in the imperative.
It is the leading line of the prompt and does the same work a skill description does — the
agent reads it before anything else and reads everything after it in its light.

**2. What only the disk knows.** The facts the ticket cannot carry because they live in the
working environment: which files are the worked examples and where they actually sit,
gitignored paths, a sibling branch running in parallel, a method that has already been tried.
This is the **cache** lever — a prompt earns its length by carrying the lookups the centurion
cannot cheaply perform, and by leaving the ones it can (a file it will open anyway, a
`--help` output) to the environment. Give it its own heading when it runs past a paragraph.

**3. `## Steps` — numbered, in execution order.** The primary tier of the information
hierarchy is *what the agent does, in order*. A ticket with a real sequence — fetch the
proposal, read the section, rewrite it, cite the finding, rename the branch, open the PR —
written as flat prose leaves the ordering to the centurion's inference, which is a variance
bug you can fix by typing numbers. Each step names its object: the file by path, the section
by heading, the branch by name.

**4. `## Done when` — the bound, carried here.** The prompt **stands alone**: a centurion
that never runs `gh issue view` still finishes correctly and still knows when to stop.
Pointing at the ticket for the completion criterion is progressive disclosure applied
backwards — the one element that must never be missed made the one element that is fetched,
and a skipped or truncated call leaves the run with no bound at all.

Make the criterion **checkable and exhaustive**: a state a `git diff` or a `gh` read settles,
covering every artifact the ticket produces. *"A `git diff` against `main` touches
`skill/SKILL.md` and nothing else"* is the form; *"the section reads well"* is not. Where the
deliverable is a PR, name the five things the merge gate wants (`SKILL.md`, *Build work and
the merge gate*) in the prompt — the centurion cannot see `SKILL.md`.

This part is also the Execute gate. A ticket you can write step 3 and step 4 for is Execute;
one you cannot is Heavy.

**5. `## Constraints` — what stays untouched, and the blast radius.** Files and sections the
run leaves alone, and the reason where the reason is load-bearing (a parallel branch, a
junction into the live skill, an artifact with no revision history). State each one once. If
the ticket already carries a constraint, either point at the ticket or write the constraint —
doing both is the duplication to remove, and writing it is usually right, because part 4 has
already committed to a prompt that stands alone.

## Prompt the positive

State the target behaviour, so the behaviour you do not want is never named. Steering by
prohibition drags the forbidden thing into context and makes it *more* available, and the
negation is a weak modifier over a strongly activated concept.

- *do not rule from the name alone* → **read each skill's own frontmatter and description
  before ruling on it**
- *do not fix anything* → **the deliverable is the artifact; the map's later task ticket
  applies the fix**
- *do not assume from the name* → **check the frontmatter**

A prohibition earns its place only as a hard guardrail with no positive phrasing — the live
example being *do NOT pass `--permission-mode bypassPermissions` to a nested `claude -p`*,
where the flag must be named to be avoided. Pair it with the positive target in the same
breath: *drop the flag and the nested call goes through*.
