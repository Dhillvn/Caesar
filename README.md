# Caesar

An orchestrator layer on top of the Wayfinder workflow. Raj talks to one session; Caesar drives the map's tickets, running AFK work itself and pulling the human in only for prototype and grilling tickets.

## Install

```powershell
.\install.ps1
```

Junctions `~\.claude\skills\caesar` onto `skill\` in this repo. No admin needed, no
restart needed — Claude Code loads a junctioned skill live. Idempotent; re-run it after
moving the repo. `.\install.ps1 -Uninstall` removes the junction.

Then, from inside whichever repo owns the map:

```
/caesar https://github.com/<owner>/<repo>/issues/<map-number>
```

## Layout

| Path | What |
|---|---|
| `skill/SKILL.md` | The judgment layer — which ticket to take, when to interrupt, the merge gate |
| `skill/scripts/frontier.ps1` | Frozen: one-GraphQL-call frontier sweep of a map |
| `skill/scripts/spawn-ticket-agent.ps1` | Frozen: fire one headless ticket agent, worktree + deny list |
| `skill/scripts/remove-worktree.ps1` | Frozen: fail-closed worktree teardown |
| `skill/scripts/status.ps1` | The status view — renders over the sweep, no query of its own |
| `install.ps1` | The junction install |
| `docs/research/` | Prior-art and measurement write-ups |

The three scripts are **frozen** because each is a command whose safety is a flag that
improvisation can silently drop. Judgment stays prose; these do not.
