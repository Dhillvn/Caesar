# Caesar

An orchestrator layer on top of the **Wayfinder** workflow.

Today Raj hand-runs every Wayfinder ticket: stop, spawn an agent, track which ticket is next,
repeat. Caesar removes that. Raj talks to one session — Caesar's — and Caesar drives the map:
resolving AFK tickets himself, and interrupting Raj only for the ticket types that genuinely
need a human (`prototype`, `grilling`, HITL `task`).

Caesar drives Wayfinder maps only. He is not a general-purpose work supervisor.

## Prior art

`github.com/kunchenguid/firstmate` — the same captain/first-mate/crewmate shape for a different
workflow. Concept ports; implementation (tmux, multi-harness hooks, secondmates, X mode,
macOS notifications) does not. Caesar needs its spawn and escalate layers, not its state layer —
the Wayfinder map already **is** the queue.

## Agent skills

### Issue tracker

GitHub issues in the private repo `Dhillvn/caesar`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context — `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
