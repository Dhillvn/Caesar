# Worktrees

Disclosed from `SKILL.md` ([#113](https://github.com/Dhillvn/Caesar/issues/113)): who owns a
worktree, how one is torn down, and what to do with one you cannot prove you created.

## Worktrees

Every centurion gets its own, always — `--worktree` inside the spawn script. Not
per ticket type: the deciding factor is parallelism, and N processes in one checkout
collide on `git checkout` no matter what they write.

The centurion renames off the machine-gibberish `worktree-<name>` onto a legible branch, so
the PR is judgeable. Teardown is `scripts/remove-worktree.ps1`, which is **fail-closed**
— it will not delete a worktree holding uncommitted or unpushed work.

Report a leftover **once, with the resolution attached**: what happened to the ticket,
that you have already handled it, where the remains are, and that he can say "bin it".
A bare "there is a folder here" is unactionable and is a bug in you.

### Orphan worktrees

`spawn-ticket-agent.ps1` names every worktree `ticket-<number>-<random>`, so provenance is
stamped into the folder name. **Delete only what you can prove you created and that holds
nothing.**

| Worktree | Action |
|---|---|
| `ticket-N-*`, ticket N closed, teardown succeeds | delete **silently** — one correct outcome, zero information for Raj |
| `ticket-N-*`, ticket N closed, teardown refuses (dirty/unpushed) | report **once, with the resolution attached** |
| `ticket-N-*`, ticket N open | not an orphan — that is the live-centurion case |
| anything not `ticket-N-*` | **never delete.** Could be Raj's own. Report once and ask |
