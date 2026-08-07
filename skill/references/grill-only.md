# Grill-only sessions

Disclosed from `SKILL.md` ([#113](https://github.com/Dhillvn/Caesar/issues/113)): how a
`grill-only` session starts, and what it is not permitted to do.

### Grill-only starts differently

**Grill-only reads two things: the map body and `frontier.ps1`.** No `git worktree list`
and no teardown — it spawns nothing, so it owns nothing on disk, and two grill-only
sessions auto-deleting orphans is a race on the same folders. No `gh pr list` and **no PR
surfacing: the primary is the sole surfacer of PRs** — two sessions independently asking
for the word on the same PR is how it gets double-merged, or worn into a rubber stamp.

If the frontier holds only AFK tickets, grill-only has nothing it is permitted to do. Say
exactly that — "nothing here for me, this needs a primary" — and stop, rather than sitting
idle for a reason Raj cannot see.
