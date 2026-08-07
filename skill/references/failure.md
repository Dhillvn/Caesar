# When a centurion fails

Disclosed from `SKILL.md` ([#113](https://github.com/Dhillvn/Caesar/issues/113)): what to do
when a run errors, dies, goes quiet, or lands an artifact you will not accept. The tier names
it escalates between are defined in [`dispatch.md`](dispatch.md).

## When a centurion fails

**Retry a bad roll, flag a wall. One retry maximum, ever** — then flag regardless of
class. There is no per-failure-mode policy table to apply: read the evidence and ask
whether a re-fire could plausibly come out differently. If it could, re-fire once. If
the same run would hit the same thing again, stop and hand it over.

Look at it with `scripts/inspect-run.ps1` — pipe the spawn result straight in, or pass
`-ResultFile` alone from a later session. It prints liveness, heartbeat, artifact state,
the result JSON fields, and the stderr/transcript tails, and **returns no verdict**. The
call is yours, here:

| What you see | What you do |
|---|---|
| **Transient error** — `is_error: true`, stderr shows network / 5xx / rate limit | **Retry** |
| **Budget exhausted** — cost at cap, no artifact | **Flag.** Raising the cap or splitting the ticket is Raj's call |
| **Silent do-nothing** — exit 0, `is_error: false`, ticket open, no comment. Includes the clean-exit-mid-wait shape: the centurion built its rig, backgrounded the work, and ended its turn saying it is waiting for a completion notification — nothing wakes a headless agent, so the work finishes after it is gone and is thrown away | **Retry**, prompt sharpened to name the missing artifact |
| **Half-done** — comment but not closed, or closed with no comment | **Neither.** Finish the mechanical remainder yourself, no spawn. Flag only if the *work* is partial rather than the bookkeeping |
| **Died at spawn** — `DIED-AT-SPAWN`: the process is gone, nothing was ever written, stderr tail on the event | **Read the tail.** It is the whole diagnosis, and it is nearly always the environment refusing — worktree taken, path missing, auth. Fix the environment and **retry**; if nothing on this machine can be fixed, **flag** |
| **Wedged** — killed after the heartbeat flatlined | **Triage on the tails.** Died mid-API-call → bad roll → retry. Looping the same action → wall → flag. Never really started (auth, bad path) → wall → flag |
| **Coherently wrong** — artifact complete, answer collides with a prior decision | **Reopen, comment what it collides with, flag. Never retry** — *except* a complete-but-inadequate artifact at **Execute**, which retries **once at Heavy** |

Wrong never retries because new information may legitimately change Raj's mind — he
might take the new answer or hold the old one, and you cannot know which. So it goes
back to him with the collision named, never re-rolled and never resolved on your own
judgment. The gist does not reach the map either way; you append only after verifying.

**The one licensed exception — escalation is a misclassification remedy, not a failure
remedy.** It fires on exactly one condition: an Execute run produced a complete artifact
that is inadequate. That is evidence the Execute gate was called wrong, so the ticket
re-fires **once at Heavy**. The rule above was written when every run was Opus and the
model was therefore a constant — a re-roll at the same configuration is the same bet. Once
the tier can change, a re-fire is a materially different bet, which is what narrowly
licenses this and nothing else. It applies at Execute only, and it does not raise the one-
retry maximum.

**Every other failure class retries at the same tier, or does not retry.** In particular,
**budget death never escalates**: it flags, and raising the cap or splitting the ticket is
Raj's call. Tail burns the cap faster, so escalating there is
counting to a tip. **Heavy → Tail never fires automatically** either — Opus medium failing
does not imply Opus high succeeding, and it costs more. Tail is reached only by an explicit
per-map override.

**A non-empty `permission_denials` is not a failure signal.** A real successful run on
disk carries one. Denials count only when no artifact landed.

### The timer: look, do not kill

**At 30 minutes you look; you do not kill.** The clock is the watcher's — a centurion whose
transcript has not advanced arrives as a `QUIET` event, and re-arrives every 15 minutes
while it stays quiet, so a wedge cannot go silent again after one notice. You are never the
one counting; before the watcher existed this rule had no clock at all and so never fired.

On a `QUIET`, read the heartbeat: still moving → the ticket is genuinely long, let it run.
Not moving → wedged, kill by PID and triage on the tails. A hard kill at the clock bins
legitimately slow work, and `--max-budget-usd` already bounds a runaway. Both intervals are
`-QuietMinutes` / `-RecheckMinutes` on the watcher, overridable per-map in the map's
**Notes**.

A wedge is not automatically a flag — a dropped connection is a bad roll, a loop is a
wall, and the table above already tells them apart.

**A death is not on the clock at all.** A run whose process is gone before it wrote a turn
is finished, not slow, so `DIED-AT-SPAWN` arrives on the next poll — seconds, not 30
minutes — and arrives exactly **once**, because a corpse's state cannot change and a
repeated alarm on it is how a real landing gets missed. Nothing acknowledges it and nothing
needs to: re-arming the watcher backfills it silently, the same as a landing.

### Retry mechanics

**Fresh spawn, fresh worktree**, prompt naming what the last attempt left behind ("a
previous run pushed branch X — continue from it"). Never `--resume`: it carries the
failed context forward, so a centurion that talked instead of acting resumes talking.

**The attempt count is a comment on the ticket** ("attempt 2 of 2"), not the run logs —
`.claude/caesar-runs/` is gitignored machine-bound scratch that does not exist for a
grill-only session on another checkout. GitHub is the truth.

### Flagging: `caesar:needs-raj`

A flagged ticket carries **`caesar:needs-raj`**, **stays assigned**, and gets a comment
saying why you stopped. Label so the sweep sees it, comment so Raj can read it,
assignment so it is off the frontier. `frontier.ps1` reports it as `flagged` and
`status.ps1` renders it **Needs you**, above everything else.

Leave it labelled, assigned and commented, so the sweep passes over it; never leave a
failed ticket open and unassigned — that hands it back to the next
session, which re-fires it, defeating the retry ceiling silently.

The label is per ticket and is not only for failures: it marks **any AFK ticket you have
stopped on**, including one that finished with an answer you will not accept alone. HITL
tickets never carry it — Raj is already in the room.

Retries fire **silently**. Flags **queue and surface at a break in the grill**, one line
each — same as ready PRs, and for the same reason.

## Reconciling a claimed AFK ticket against the disk

The other half of `SKILL.md`'s *Reconciling GitHub against the disk*; the half every branch
reads stays inline there.

- **Claimed AFK with nothing on disk — check the GitHub artifact, not the disk**, then
  fall into the failure rules above. Resolution comment but ticket still open →
  bookkeeping half-done, finish the mechanical remainder yourself. Branch or PR but no
  comment → *work* half-done, flag it. Nothing at all → nothing ran, re-fire under the
  retry ceiling. The attempt count is a ticket comment precisely so a session with no
  local logs can count it — **no new machinery**.

**Assumption, load-bearing and stated: one machine, one checkout per repo.** You are
always invoked from inside the map's repo and every spawned worktree lives there, so
`git worktree list` sees every centurion on this map whoever dispatched it — which is
what makes "no worktree" mean *nothing running* rather than *running where I cannot
see*. A second machine or checkout breaks the inference.
