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

## The PowerShell rule

Every silent-failure bug this repo has shipped is one family: **content with spaces or
newlines shredded by passing it through PowerShell** — a deny list split on its internal
space (#19), a `--jq` expression split the same way (#24), a `git commit -m` here-string
dying at the first newline (#32), and a whole 25 KB map body flattened to one line by
`--jq .body | Set-Content -NoNewline`, because native output is an **array of lines** and
`-NoNewline` joins an array with no separator (#36). Every one of them looked correct
while reading and failed without an error.

So, when content travels:

- **To a native tool: through a file** — `--body-file`, `--input`, `-F`. Never argv.
- **From a native tool: to a file** — `Start-Process -RedirectStandardOutput`. Never a
  variable, if the value is going to be written back somewhere.
- **Splitting or joining lines yourself: say the separator out loud** — an explicit
  newline in `-split` / `-join`, or `[IO.File]::ReadAllText`/`WriteAllText`. `-NoNewline` on anything that
  might be an array is banned outright.
- **Any `^`-anchored regex: apply it to a string, never to an array.** `^` never matches
  in an array pipeline, so the check silently reports zero and reads as a clean result.
- **Verify structure, not phrasing.** A check that asks "is the old text gone?" passes on
  a destroyed file.

## Agent skills

### Issue tracker

GitHub issues in the private repo `Dhillvn/caesar`, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context — `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
