# Prior art: First Mate

Researched 2026-07-28. Source: `https://github.com/kunchenguid/firstmate` (MIT, author `kunchenguid`).
Windows port: `https://github.com/FallingReign/firstmate-win`.

**Not** Matt Pocock's `mattpocock/skills` — unrelated project, explicitly ruled out during research.

## What it is

Not a plugin, not an MCP server, not an installable binary. A **git repo you clone and run your
coding-agent CLI inside**. Its `AGENTS.md` (symlinked as `CLAUDE.md`) *is* the orchestrator — the
whole loop is prompt text. Everything else is bash/Node in `bin/` plus conditionally-loaded
Markdown skills in `.agents/skills/*/SKILL.md`. Tagline: "Talk to one agent. Ship with a crew."

## Roles

- **captain** — the human.
- **first mate** — the single live agent session the captain talks to.
- **crewmate** — an autonomous agent spawned per task, torn down on completion.
- **secondmate** — optional persistent, domain-scoped crewmate with its own isolated `FM_HOME`,
  state and backlog.

## State

No database, no queue service. Files only.

- `data/` (durable, gitignored): `backlog.md`, `captain.md`, `learnings.md`, `projects.md`,
  `secondmates.md`, per-task `<id>/brief.md` and `<id>/report.md`.
- `state/` (volatile): `<id>.status` (append-only wake-event log), `<id>.meta`, `.wake-queue`,
  `.afk` flag, lock files.
- `config/` (local operator choices): `crew-harness`, `backend`, `crew-dispatch.json`,
  `secondmate-harness`, `wedge-alarm`, `calm`.

`data/backlog.md` is "the durable queue... tracks work items only, never agents."

## Choosing what runs next

No scheduler and no algorithm, by explicit design. The first mate reads the backlog plus a status
digest at session start (`bin/fm-session-start.sh`) and reasons about priority itself. Dispatch
rules live in `config/crew-dispatch.json` as human-editable natural language, resolved by the agent.

> "Firstmate owns the judgment. Do not add a daemon, opaque composite score, routing wrapper,
> hard-coded model-specific policy, or producer-side route recommendation."
> — `quota-array-dispatch/SKILL.md`

Task classification is binary: **Ship** (default — produces a project change/PR) vs **Scout**
(produces `data/<id>/report.md`, never a PR).

## Spawning and isolation

`bin/fm-spawn.sh <task-id> <project-dir> [--harness ...] [--model ...] [--effort ...] [--backend ...] [--scout]`

Each crewmate gets its own **git worktree** and its own **terminal session pane**. Hard-enforced:

> "`fm-spawn.sh` refuses to launch unless the resolved task path is a real git worktree root that
> is distinct from the project primary checkout."

Session backends are pluggable — tmux (hard default / only verified reference), herdr, zellij,
orca, cmux. Teardown (`bin/fm-teardown.sh`) is fail-closed: refuses to destroy a worktree holding
uncommitted or unlanded work.

## Human-in-the-loop

Hard rules from `AGENTS.md`, verbatim, in priority order:

1. Never write to a project (first mate is read-only over projects; crewmates make all changes).
2. Never merge a PR without the captain's explicit word.
3. Never tear down unlanded work.
4. **Crewmates never address the captain** — all output relays through the first mate.
5. Report outcomes faithfully.

A project may carry a standing `yolo` posture that relaxes *routine* decisions only; destructive,
irreversible or security-sensitive actions still gate on the captain.

**`/afk` skill** — away mode. Sets `state/.afk`, spins up a sub-supervisor daemon that classifies
wakes itself and self-handles the routine majority, escalating only on terminal captain verbs
`done:` / `needs-decision:` / `blocked:` / `failed:`. Escalations buffer for
`FM_ESCALATE_BATCH_SECS` (default 90s), flush as one digest line, and are injected into the
captain's session with a stable `FIRSTMATE_OP:` prefix preceded by an invisible U+2063 separator,
so machine injections are distinguishable from real messages.

**Wedge alarm** — if an injection can't be confirmed delivered within `FM_MAX_DEFER_SECS`
(default 300s), fire a loud rate-limited alarm (macOS `osascript` banner by default, or a
configurable command), drop a durable `state/.subsuper-inject-wedged` marker, flash the terminal.

**Resume** is implicit: the captain's next message lacking the `FIRSTMATE_OP:` prefix and not
starting with `/afk` triggers `bin/fm-afk-return.sh` — ordered daemon shutdown, drain buffered
escalations, gate ordinary work until a return-catch-up check passes.

## Parallelism

No concurrency cap. From `AGENTS.md` §7:

> "dispatch isolated work immediately with no concurrency cap when each change can be
> independently implemented and validated... Serialize only for a true semantic dependency,
> shared mutable external state, incompatible concurrent migration... same-file editing alone is
> insufficient."

`bin/fm-watch.sh` is a bash-only event classifier that sleeps across the whole fleet and wakes the
token-costly LLM turn only when something is actionable — "zero-token" supervision between wakes:

> "Classifies supervision wakes in bash. In normal mode it absorbs benign wakes and keeps blocking;
> it queues and exits only for actionable wakes... While `state/.afk` exists, the daemon owns triage
> and this watcher queues and exits on every wake."

## File layout

```
AGENTS.md                 the entire operating contract/prompt (CLAUDE.md symlinks to it)
.tasks.toml               tracked config for the default markdown backlog backend
.agents/skills/*/SKILL.md internal skills (afk, ahoy, ask-user-authority, bearings,
                          bootstrap-diagnostics, decision-hold-lifecycle, diagnostic-reasoning,
                          firstmate-codexapp, firstmate-coding-guidelines, firstmate-orca,
                          fmx-respond, harness-adapters, project-management,
                          quota-array-dispatch, secondmate-provisioning, stow,
                          stuck-crewmate-recovery, updatefirstmate)
.claude/skills            symlink to .agents/skills
skills/stow/SKILL.md      the one public, installer-facing skill
bin/fm-spawn.sh           spawns a crewmate/secondmate into a worktree + session pane
bin/fm-teardown.sh        fail-closed teardown; refuses if work is unlanded
bin/fm-watch.sh           bash-only event classifier, the "zero-token" loop
bin/fm-crew-state.sh      reconciles a task's actual current state vs its status-log events
bin/fm-send.sh            fail-closed steer/message-injection into a crewmate pane
bin/fm-afk-launch.sh|start.sh|return.sh   away-mode lifecycle
bin/fm-supervise-daemon.sh sub-supervisor daemon used during /afk
bin/fm-pr-check.sh|merge.sh|poll.sh       PR lifecycle
bin/fm-backend*.sh, bin/backends/{tmux,herdr,zellij,orca,cmux}.sh  pluggable session backends
bin/fm-session-start.sh   once per session: lock, bootstrap, wake-queue drain, digests
bin/fm-bootstrap.sh       detect-only tool/auth checks, asks consent before installing
bin/fm-x-*.sh             optional X/Twitter posting + auto-reply subsystem
projects/                 cloned target repos crewmates work in (read-only to the first mate)
docs/architecture.md, docs/wedge-alarm.md, docs/*-backend.md, docs/supervision-protocols/*.md
tests/                    100+ bash/python test files
.grok/hooks/, .opencode/plugins/, .pi/extensions/, .codex/hooks.json  per-harness shims
```

## What does NOT transfer to Caesar

- **tmux** — the hard default and only verified backend; no native Windows equivalent. The
  `firstmate-win` fork had to rewrite it to WezTerm tabs + Git Bash, touching dozens of `bin/fm-*.sh`
  scripts that shell out to a `tmux.sh` backend interface.
- **git worktrees as a hard isolation requirement** — needs "treehouse" pooling or Orca. Most
  Wayfinder tickets produce issue comments, not code, so this may be pure ceremony here.
- **macOS `osascript` notification path** for the wedge alarm.
- **`tasks-axi`, `gh-axi`, `chrome-devtools-axi`, `lavish-axi`** — the author's own helper CLIs.
  A plain Claude Code user falls back to `config/backlog-backend = manual`.
- **Multi-harness support** (Claude/Grok/Pi/Codex/OpenCode) and its per-harness hook files —
  dead weight for a Claude-Code-only user.
- **Secondmates** and **X mode** (auto-replying to X/Twitter mentions) — built for an always-on
  fleet-ops workflow.

Net: the **concept** ports — one supervising session, isolated per-task agents, disk-based durable
state, escalate-on-decision human gating. The **implementation** is heavily Unix/tmux/GitHub-CLI/
macOS-specific.

## The load-bearing read for Caesar

First Mate's `data/backlog.md` is a hand-rolled queue. **Caesar already has a better one — the
Wayfinder map.** So Caesar does not need First Mate's state layer at all. It needs its **spawn**
layer and its **escalate** layer.

Second read: Wayfinder's hard rule is *one ticket per session*. "One spawned agent per ticket,
torn down after" satisfies that for free — the same shape First Mate arrived at independently.
