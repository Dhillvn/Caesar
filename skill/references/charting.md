# Charting a new map

Disclosed from `SKILL.md` ([#113](https://github.com/Dhillvn/Caesar/issues/113)): the path
`/caesar` takes when Raj arrives with a loose idea and no map URL.

## Charting a new map

Raj arrives with a loose idea and no map. You chart it and then you drive it — charting
is not a separate session that hands over.

**The repo constraint, checked first.** A map is issues in a git repo: every frozen script
talks to `gh` against that repo, and `--worktree` is repo-local. So you must be inside a
git repo with issues enabled. If the idea has no repo, say so plainly and offer to stand
one up (`gh repo create`, private) as the map's first AFK `task` ticket. Never dead-end on
it, and never try to host a map in Drive markdown.

Then, in order:

1. **Name the destination.** Grill (`/grilling`, `/domain-modeling`) until it is one or two
   lines: the spec, decision or change this effort is finding its way to. Scope before
   route — the destination is what fixes in and out.
2. **Grill again, breadth-first.** Fan out across the whole space rather than deep on one
   thread: the open decisions, and the first steps takeable now. **If no fog surfaces** —
   the way is already clear and the whole thing fits one session — there is nothing to
   chart. Say so and ask him how he wants to proceed.
3. **Create the map**, labelled `wayfinder:map`, body in Wayfinder's shape: Destination and
   Notes filled in, Decisions-so-far empty, the fog in **Not yet specified**.
4. **Create the tickets** you can specify now, each labelled `wayfinder:<type>`, and attach
   each to the map as a sub-issue.
5. **Wire blocking in a second pass** — issues need ids before they can reference each
   other, so this cannot be folded into step 4.

```
gh issue create --label wayfinder:map --title "..." --body-file <file>
gh issue create --label wayfinder:<type> --title "..." --body-file <file>
gh api repos/<owner>/<repo>/issues/<n> --jq .id
gh api --method POST repos/<owner>/<repo>/issues/<map>/sub_issues -F sub_issue_id=<child-db-id>
gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>
```

Both relationship endpoints take the numeric **database id**, not the `#number` and not the
`node_id`. Bodies travel **through a file** — a multi-line body dies at the first newline in
argv.

**The labels must already exist in the target repo.** `gh issue create --label` hard-errors
on an unknown label and creates nothing — so in a repo that has never held a map, run
`gh label create wayfinder:map` and one per `wayfinder:<type>` you are about to use, first.

No new script for any of this: these are flagless one-liners and the rest is judgment, the
same reasoning that kept startup as prose.

**Fog, not pre-sliced tickets.** The test is whether you can *state* the question sharply
now — not whether you can answer it. Sharp but blocked → a ticket. Not yet sharp → one loose
line under **Not yet specified**. Do not slice fog into ticket-shaped pieces; one patch may
graduate into several tickets, or none.

**Declare the shape before you drive.** Name in a line or two what this map will
actually exercise — two centurions running concurrently, a PR merge gate — and what it
will not touch. A map that empties without exercising them is a **partial**, and that
is declared up front, not argued afterwards.

**Then drive.** Do not stop at the handover: name the first ticket you are taking and why,
and go straight into the loop.

### Why this is not `/wayfinder` in charting mode

Two of its charting instructions contradict locked decisions here, and "follow it except
those two bits" is exactly the improvisation surface the frozen scripts exist to kill:

- *"Fire the research subagents"* — research tickets go out as headless agents through
  `spawn-ticket-agent.ps1`, never subagents.
- *"Stop — charting is one session's work; it hand-resolves nothing"* — charting flows into
  driving.

Everything else in its charting mode carries over on its merits, and is written out above
rather than referenced.
