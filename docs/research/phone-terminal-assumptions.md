# Phone-terminal assumptions in Caesar's own source

Audit for [#165](https://github.com/Dhillvn/caesar/issues/165). Inventory only — nothing
under `skill/` is repaired here. Repair belongs to a later ticket, once the surface is
chosen.

## Scope and method

Every file that is Caesar was read end to end: `skill/SKILL.md`, all eleven files under
`skill/references/`, and all ten under `skill/scripts/` — 2,664 lines. Each was read for
six kinds of assumption: a real TTY, a wide monospace viewport, a Windows drive letter, a
specific working directory, a local file a human opens by hand, and an ambient credential.

Every claim below is judged from the code, not from the prose describing it. Where the two
disagree, the disagreement is a row of its own (see *Where the prose and the code
disagree*).

One measurement was taken rather than estimated: `status.ps1`'s table renders at **98
columns** — the column widths at `skill/scripts/status.ps1:21` fed through `Format-Row`
and `Format-Bar` produce a 98-character line each. That number is the single largest
viewport fact in the audit.

### The three damage classes

The class in the inventory is the **worst case across the three surface classes** in the
next section. A row marked *breaks outright* need not break on all three; the per-surface
sections say where each one actually bites.

- **breaks outright** — on at least one surface the mechanism yields no usable result, or
  a silently wrong one.
- **degrades but usable** — still works, at a cost in legibility, density, or extra steps.
- **fine** — surface-independent.

### The three surface classes

1. **A real terminal over SSH** — an SSH client on the phone into the Windows box. The
   TTY is real, the machine is real, PowerShell is real, `gh` auth is real. The only thing
   that changed is the viewport: roughly 40×20 characters in portrait, ~80×12 in landscape
   with the soft keyboard up.
2. **A chat-style web UI** — Claude Code in a phone browser. Output is rendered as
   Markdown in a proportional font. Harness tools exist, but the compute host is not
   guaranteed to be Raj's Windows box, and a persistent background process is not
   guaranteed to outlive a turn.
3. **A message-bridge** — Telegram or similar: each turn is exactly one message with a
   hard character cap (~4,096), no monospace guarantee, no streaming, and asynchronous
   events arrive as separate messages.

---

## Inventory

### Wide monospace viewport

| `file:line` | Assumption | Class |
|---|---|---|
| `skill/scripts/status.ps1:21` | Column widths `4/6/50/13/9` render a fixed **98-column** table. The status view is the one thing Raj is told to read. | breaks outright |
| `skill/scripts/status.ps1:29` | `Format-Row` frames every cell with `│` (U+2502) and pads to width — alignment requires a monospace font. | breaks outright |
| `skill/scripts/status.ps1:34-37` | `Format-Bar` draws `┌┬┐ ├┼┤ └┴┘` rules the full 98 columns. | breaks outright |
| `skill/scripts/status.ps1:24` | `Format-Cell` truncates to the *cell* width with `…`, so narrowing the viewport cannot recover content — it is already gone before wrapping happens. | degrades but usable |
| `skill/scripts/status.ps1:60-69` | `Split-Wrap` wraps a ticket title at 50 columns, i.e. the desktop cell width, and continuation lines are re-framed as full-width rows. | breaks outright |
| `skill/scripts/status.ps1:100-101` | Headline concatenates counts and the last decision on one line with `·` separators; unbounded length, no wrap. | degrades but usable |
| `skill/scripts/veto-sweep.ps1:90` | `Format-Table … \| Out-String -Width 200` — a **200-column** render, twice the status table. | breaks outright |
| `skill/scripts/inspect-run.ps1:39-42` | `Clip` allows 200-character single lines. | degrades but usable |
| `skill/scripts/inspect-run.ps1:65-166` | The whole report is a ~35-line vertical dump across seven sections — a tall preview, which Raj's interface already truncates on a desktop. | degrades but usable |
| `skill/scripts/watch-runs.ps1:137` | The `DIED-AT-SPAWN` event line carries prose plus a 200-character stderr tail — ~300 characters on one notification line. | degrades but usable |
| `skill/scripts/publish-runs.ps1:138` | Gist header advertises `last $Cap` with `$Cap = 40` (`publish-runs.ps1:26`) — 40 run blocks in one file. A scrolling web page, so height is free. | fine |
| `skill/SKILL.md:325-332` | The *Where the voice is on* table is a 2-column Markdown table; renders in any Markdown surface. | fine |
| `skill/SKILL.md:119-127` | The first turn is specified as four one-line items ending in the pick. Deliberately short. | fine |

**Not found, and that matters:** `AskUserQuestion` appears nowhere in Caesar's source.
Every grill is free prose. The option-text truncation in Raj's interface therefore never
fires on Caesar — the table above is the whole viewport exposure.

### A real TTY and a persistent local process

| `file:line` | Assumption | Class |
|---|---|---|
| `skill/references/watcher.md:10-13` | The watcher is armed as a `Monitor(… persistent: true)` process whose stdout lines become notifications. Every landing reaches Caesar only through this. | breaks outright |
| `skill/scripts/watch-runs.ps1:320-323` | `while ($true) { … Start-Sleep }` — an unbounded foreground loop needing a process host that outlives a turn. | breaks outright |
| `skill/scripts/watch-runs.ps1:50-56` | `Emit` writes to `[Console]::Out` and flushes explicitly, assuming a live consumer of a streamed stdout. | breaks outright |
| `skill/scripts/spawn-ticket-agent.ps1:154-157` | `Start-Process … -WindowStyle Hidden` with three stream redirections — a Windows process-creation API with a window-station concept. | breaks outright |
| `skill/scripts/spawn-ticket-agent.ps1:154` | `claude` is on `PATH` as an executable and can be spawned detached. | breaks outright |
| `skill/SKILL.md:21-25` | A PowerShell pipeline (`claude plugin list --json \| ConvertFrom-Json …`) is run each session to locate Wayfinder. Requires PowerShell *and* the plugin installed on this host. | breaks outright |
| `skill/scripts/veto-sweep.ps1:76-83` | `Get-CimInstance Win32_Process` reads the local Windows process table to find in-flight centurions. Explicitly *"the process table is the truth about what is in flight"* (`veto-sweep.ps1:73-74`). | breaks outright |
| `skill/scripts/watch-runs.ps1:123-125` | `Get-Process -Id $d.ProcessId` — liveness by local PID. | breaks outright |
| `skill/scripts/inspect-run.ps1:75-83` | `Get-Process` for liveness, with a `claude\|node` process-name check. | degrades but usable |
| `skill/scripts/remove-worktree.ps1:42-72` | `git -C` against a local worktree path for status, log, unlock, remove. | breaks outright |
| `skill/scripts/watch-runs.ps1:186-187`, `285-286` | The self-test shells out to `powershell` with `Start-Process` and redirected stdout. | degrades but usable |
| `skill/references/watcher.md:16-23` | The documented failure mode is Monitor→bash backslash stripping, i.e. the arming command is composed for **bash on Windows**. | degrades but usable |
| `skill/SKILL.md:139-141` | *"subagents cannot converse with a human, so you are the channel"* — a live, turn-taking conversational channel is presumed to exist. | fine |
| `skill/SKILL.md:227-228`, `skill/references/failure.md:100-101` | Ready PRs and flags *"queue and surface at a break in the grill"* — needs multi-turn conversation, not a TTY. | fine |
| `skill/SKILL.md:361-362` | Away-mode is out of scope: *"You wake, you report, you wait."* Presumes Raj answers, not that he is at a terminal. | fine |

### Windows drive letters and hard-coded paths

| `file:line` | Assumption | Class |
|---|---|---|
| `skill/scripts/publish-runs.ps1:24` | `$ProjectsRoot = %USERPROFILE%\Projects` — every repo Caesar publishes lives under one Windows directory. | breaks outright |
| `skill/scripts/publish-runs.ps1:32` | Gist id is read from `caesar\.claude\caesar-runs\.gist-id` — backslash literal, and a repo named exactly `caesar`. | breaks outright |
| `skill/scripts/publish-runs.ps1:34` | Falls back to a **hard-coded gist id** `12fdf235c41ddc3f74a4847bdb89dc8c` when that file is absent — so on a different host it publishes to Raj's gist silently rather than failing. | degrades but usable |
| `skill/scripts/publish-runs.ps1:145` | `Join-Path $_.FullName '.claude\caesar-runs'` — backslash literal. | breaks outright |
| `skill/scripts/spawn-ticket-agent.ps1:60` | `$RepoPath = $canonicalRepoPath -replace '/', '\'` — git's forward slashes are forced to the backslash form the rest of the script needs. | breaks outright |
| `skill/scripts/spawn-ticket-agent.ps1:93`, `:162` | `'.claude\caesar-runs'` and `".claude\worktrees\$WorktreeName"` — backslash literals in the run-log and worktree paths. | breaks outright |
| `skill/scripts/spawn-ticket-agent.ps1:115` | The guardrail heredoc writes `%TEMP%\claude\bundled-skills\<version>\<hash>\claude-api\` into **every** centurion prompt — Windows env-var syntax shipped to every dispatched agent. | degrades but usable |
| `skill/scripts/watch-runs.ps1:76-77` | Transcript dir is `%USERPROFILE%\.claude\projects` with the worktree path dash-mangled — the heartbeat, and therefore `QUIET`, exists only on this machine. | breaks outright |
| `skill/scripts/inspect-run.ps1:90-91` | Same derivation, duplicated. | breaks outright |
| `skill/scripts/inspect-run.ps1:57-58` | `$WorktreePath` is rebuilt as `<repo>\.claude\worktrees\<name>` by walking two parents up from the log dir. | breaks outright |
| `skill/scripts/verify-dispatch.py:19` | Default repo is `os.path.expanduser("~/Projects/caesar")` — Raj's layout as a code default. | degrades but usable |
| `skill/scripts/verify-dispatch.py:52-53` | `.replace("/", "\\")` then `re.sub(r"[:\\/.]", "-", …)` — the Windows path shape is load-bearing for finding the transcript at all. | breaks outright |
| `skill/scripts/map-body.ps1:119` | Backup dir `'.claude/caesar-runs/map-backups'` (forward slashes here, backslashes elsewhere — inconsistent, but portable). | fine |
| `skill/references/watcher.md:18`, `skill/scripts/watch-runs.ps1:28`, `:64`, `:271`, `skill/scripts/spawn-ticket-agent.ps1:23`, `skill/scripts/remove-worktree.ps1:18` | `C:\Users\rajdh\Projects\caesar` appears as the worked example in six places, so a session composing a command from the docs reproduces it. | degrades but usable |

### A specific working directory

| `file:line` | Assumption | Class |
|---|---|---|
| `skill/SKILL.md:40` | *"`/caesar <map-url>` from inside the repo the map belongs to."* The invocation contract is cwd. | breaks outright |
| `skill/references/charting.md:11-16` | Charting requires being inside a git repo with issues enabled; *"never try to host a map in Drive markdown."* | breaks outright |
| `skill/scripts/map-body.ps1:116-118` | Backup root derived from `(Get-Location).Path` → `git -C $here rev-parse --show-toplevel`, falling back to the cwd itself. | degrades but usable |
| `skill/scripts/map-body.ps1:151` | A relative `-BodyFile` is resolved against `$here`, i.e. the session's location. | degrades but usable |
| `skill/scripts/inspect-run.ps1:47-48` | `$ResultFile` combined against `$PWD.Path`, with a comment recording that a `cd`-ed session once reported on a different repo entirely. | degrades but usable |
| `skill/scripts/veto-sweep.ps1:27` | `[string]$RepoPath = $PWD.Path`. | degrades but usable |
| `skill/scripts/veto-sweep.ps1:37` | With a bare issue number, the repo is inferred from `gh repo view` — i.e. from the cwd. | degrades but usable |
| `skill/SKILL.md:78-80` | Startup read 3 is `git worktree list`, unconditionally, because *"the orphan case is visible only from the disk side."* | breaks outright |
| `skill/references/failure.md:115-119` | Stated and load-bearing: **one machine, one checkout per repo**. *"A second machine or checkout breaks the inference."* | breaks outright |
| `skill/references/worktrees.md:9-10` | Every centurion gets a `--worktree` inside the spawn script — repo-local by construction. | breaks outright |
| `skill/references/grill-only.md:8-10` | Grill-only reads only the map body and `frontier.ps1` — no disk reads at all. The one role already free of cwd. | fine |

### Local files a human opens by hand

| `file:line` | Assumption | Class |
|---|---|---|
| `skill/SKILL.md:266-268` | The pre-write copy under `.claude/caesar-runs/map-backups/` is *"the only undo that exists"* for the map body. It is a local file on one disk. | breaks outright |
| `skill/scripts/map-body.ps1:169` | The verdict carries a `Restore` string — `gh issue edit … --body-file "<backup>"` — written to be pasted into a shell by a human. | breaks outright |
| `skill/SKILL.md:258-261` | The map-body workflow is *fetch to a file → edit the file on disk → write it back*. Caesar edits it, but recovery is Raj's and is file-shaped. | degrades but usable |
| `skill/references/failure.md:82-83` | `.claude/caesar-runs/` is *"gitignored machine-bound scratch"*, explicitly absent for a session on another checkout — with the attempt count deliberately kept on GitHub for that reason. | fine |
| `skill/SKILL.md:144-146`, `skill/references/dispatch.md:15-16` | `publish-runs.ps1` renders run state into a **phone-readable gist**. The one place Caesar already designs for a small screen. | fine |
| `skill/scripts/publish-runs.ps1:165-179` | The gist is the delivery surface: `gh gist edit` per repo file. Web-readable from anywhere. | fine |

### Ambient credentials

| `file:line` | Assumption | Class |
|---|---|---|
| `skill/scripts/frontier.ps1:48` | `gh api graphql` with no auth handling — an authenticated `gh` is ambient. Every read Caesar makes descends from this. | breaks outright |
| `skill/scripts/status.ps1:132` | `gh pr list` — same. | breaks outright |
| `skill/scripts/map-body.ps1:112` | `(Get-Command gh -ErrorAction Stop).Source` — `gh` must be on `PATH` as a resolvable binary, not merely reachable. | breaks outright |
| `skill/scripts/publish-runs.ps1:165-179` | `gh api gists/<id>` and `gh gist edit` — needs the `gist` scope on the ambient token specifically. | breaks outright |
| `skill/scripts/veto-sweep.ps1:44`, `:52` | `gh issue view`, `gh api …/timeline --paginate`. | breaks outright |
| `skill/scripts/inspect-run.ps1:108` | `gh issue view` for the artifact check — *"the only real evidence of work done"*. | breaks outright |
| `skill/references/charting.md:33-38` | `gh issue create`, `gh api … sub_issues`, `… dependencies/blocked_by`. | breaks outright |
| `skill/references/multi-map.md:11-13` | `gh search issues --owner Dhillvn …` — the owner is hard-coded in the documented command. | degrades but usable |
| `skill/scripts/spawn-ticket-agent.ps1:88` | `'Bash(gh auth token:*)'` is on the deny list — the deny list presupposes an ambient token worth stealing. | fine |
| `skill/scripts/spawn-ticket-agent.ps1:145-146` | `--bare` is banned because it forces API-key auth; plain `claude -p` **keeps the host's subscription auth**. Every dispatch rides an ambient Claude subscription session. | breaks outright |
| `skill/references/dispatch.md:88-92` | NotebookLM rides browser cookies renewable *"only by a human signing into a Chromium window"* — a desktop-GUI credential path. Already retired as an expectation, and recorded as the reason. | fine |

---

## What breaks, by surface

### 1. A real terminal over SSH

Everything machine-bound is satisfied: the TTY is real, PowerShell runs, the process table
and the worktrees and `%USERPROFILE%\.claude\projects` are all the right ones, `gh` and
`claude` carry their ambient auth. The Windows path rows, the cwd rows, the local-file
rows and the credential rows all collapse to *fine* here.

What still breaks is the viewport, and only the viewport:

- `skill/scripts/status.ps1:21`, `:29`, `:34-37`, `:60-69` — the 98-column table against a
  ~40-column portrait viewport. Every row soft-wraps, the box rules break in the middle,
  and the column that carries meaning (`Ticket`, 50 wide) is the one that wraps furthest.
  This is the only *breaks outright* on this surface, and it is the surface Raj is told to
  read (`skill/SKILL.md:193-196`).
- `skill/scripts/veto-sweep.ps1:90` — the 200-column `Out-String` is twice as bad again,
  but fires only on a veto, which is rare and always a conversation.
- `skill/scripts/inspect-run.ps1:65-166` — ~35 lines of vertical report, scrollable in a
  terminal; annoying, not fatal.
- `skill/scripts/watch-runs.ps1:137` — a ~300-character event line wraps to eight lines on
  a phone terminal. Legible.

Everything else — the watcher's persistent process, `Start-Process`, `Win32_Process`,
`git worktree`, the backup files, the gist — works exactly as designed.

### 2. A chat-style web UI

Two independent failures, and which ones fire depends on where the compute host is.

**Always, regardless of host — monospace is gone.** Markdown in a proportional font
destroys every fixed-width render:

- `skill/scripts/status.ps1:24`, `:29`, `:34-37` — padding and box-drawing characters no
  longer align. Unlike the SSH case this cannot be fixed by turning the phone sideways;
  the output is structurally wrong, not merely too wide. A fenced code block would restore
  monospace but not the 98 columns.
- `skill/scripts/veto-sweep.ps1:90` — same, worse.
- `skill/scripts/inspect-run.ps1:65-166` — a tall preview, which Raj's interface already
  truncates on a desktop, so it is truncated here by definition.

**If the compute host is not Raj's Windows box, everything machine-bound breaks
outright** — and mostly *silently*, which is the worse half:

- The watcher cannot be armed at all: `skill/references/watcher.md:10-13`,
  `skill/scripts/watch-runs.ps1:320-323`, `:50-56`. With no watcher, `skill/SKILL.md:143-146`'s
  Harvest step has no trigger, and by `skill/references/watcher.md:31-34`'s own reasoning a
  landed centurion reaches nobody.
- Dispatch cannot happen: `skill/scripts/spawn-ticket-agent.ps1:154-157` needs Windows
  process creation, and `:145-146` needs the host's subscription auth.
- Startup read 3 (`skill/SKILL.md:78-80`) and the orphan reconciliation
  (`skill/references/failure.md:115-119`) return an empty or foreign worktree list, which
  reads as *nothing running* rather than *running where I cannot see*. That is the exact
  inference `failure.md:115-119` names as broken by a second machine, and it fails clean —
  no error, wrong answer.
- `skill/scripts/publish-runs.ps1:24` finds no `%USERPROFILE%\Projects`, throws at `:151`
  — and if it did find one, `:34`'s hard-coded gist id would publish a foreign machine's
  runs into Raj's gist.
- Every `gh` row loses its ambient token.

What survives on this surface unconditionally: the map body, `frontier.ps1`'s output as
data rather than as a table, the conversation itself, and the published gist read as a web
page.

### 3. A message-bridge (one message per turn, hard character cap)

The cap is the new constraint; everything from surface 2 also applies, since a bridge is
proportional-font Markdown at best.

- `skill/scripts/status.ps1:21` — a 98-column table with, say, twelve open tickets is
  ~1,300 characters before wrapping and is unreadable regardless. It does not exceed a
  4,096-character cap; it fails on shape, not size.
- `skill/scripts/veto-sweep.ps1:90` — a 200-column `Format-Table` with a dozen hits is the
  one render that can plausibly *exceed* the cap and be truncated mid-table, losing rows
  without saying so.
- `skill/scripts/inspect-run.ps1:65-166` — ~35 lines across seven sections; fits the cap,
  but consumes an entire message for one diagnostic.
- `skill/references/watcher.md:10-13` — each watcher line becomes one message. This is
  actually the **best fit** of the three surfaces for the watcher's output shape: one event,
  one line, one message. `skill/scripts/watch-runs.ps1:137`'s ~300-character
  `DIED-AT-SPAWN` line is well under the cap. What breaks is not the format but the
  *mechanism* — a bridge with no persistent process host cannot run
  `watch-runs.ps1:320-323` at all.
- `skill/SKILL.md:119-127` — the four-line first turn fits one message comfortably. It was
  designed for a different reason (context cost) and happens to be cap-shaped.
- `skill/references/dispatch.md:167-168` — one gist line then straight back to the grill
  question. A 30–60 word gist is ~350 characters; one message holds it and the question.
  Fine.
- `skill/SKILL.md:139-141`, `:227-228` — the conversational contract survives intact. One
  HITL ticket per session worked in prose is exactly what a bridge does well.

## Where the prose and the code disagree

Three, recorded because the disagreement is itself a finding.

1. **`skill/SKILL.md:193-196` vs `skill/scripts/status.ps1:21`.** The prose says the status
   table is *"the whole answer"* and that Raj *"should never need GitHub's web UI."* The
   code renders it at a fixed 98 columns in box-drawing characters. On a phone the web UI
   is strictly more readable than Caesar's own status view — the prose claims
   surface-independence the renderer does not have.
2. **`skill/scripts/publish-runs.ps1:3` vs `:24` and `:143-149`.** The synopsis claims
   *"every Caesar run directory on this machine."* Discovery is one non-recursive
   `Get-ChildItem` over `%USERPROFILE%\Projects`, so a repo one level deeper, on another
   drive, or outside that root is invisible — and `:151` only throws when *nothing* is
   found, so a partial miss is silent. The `.DESCRIPTION` at `:7` is honest about this
   (*"every `<ProjectsRoot>\*\.claude\caesar-runs` directory"*); the synopsis one line
   above it is not, and the synopsis is what a session skims.
3. **`skill/references/watcher.md:16-23` vs `skill/scripts/watch-runs.ps1:67-70`.** The
   prose presents quoting as the fix for the mangled-path failure. The guard tests only
   whether the path *exists*. A backslash-stripped path that happens to resolve to a real
   directory would pass the guard and resume the silent 75-minute failure the guard was
   written for. Narrow, but the guard is weaker than its own documentation implies.

Two places where the prose is already **correct and ahead of the code**, worth naming so a
later ticket does not treat them as gaps:

- `skill/SKILL.md:96` — *"Reads 2 and 4 are GitHub and portable; read 3 and the run logs
  are machine-bound."* That is precisely the split this audit found, stated before it.
- `skill/references/failure.md:82-83` and `:115-119` — the attempt count was deliberately
  put on GitHub rather than in the run logs, *because* a session on another checkout has no
  local logs. Caesar already contains one worked example of porting state off the machine.

## Closing: which surface survives, and what the others cost

**Caesar survives a real terminal over SSH most nearly intact**, and it is not close. On
that surface exactly one class of assumption fails — the viewport — and every mechanism
that carries actual risk (dispatch, the watcher, worktree teardown, the map-body backup,
ambient `gh` and subscription auth) is untouched. Caesar was built for one machine and one
checkout (`skill/references/failure.md:115-119`), and SSH is the only surface that keeps
that promise.

The cost to close the gap, per surface:

**SSH — small, one file.** `skill/scripts/status.ps1` needs a narrow render: a
`-Width` parameter, and below some threshold a per-ticket stacked block instead of a
table. `skill/scripts/veto-sweep.ps1:90`'s `Out-String -Width 200` needs the same
treatment. Nothing else moves. This is the cheapest usable phone Caesar by a wide margin.

**Chat-style web UI — moderate if the host stays Raj's box, large if it does not.** With
the same host it is the SSH fix plus fenced code blocks around every fixed-width render,
so the proportional font cannot destroy alignment. With a different host it is a rewrite of
Caesar's disk layer: the watcher (`watch-runs.ps1:320-323`) needs a poll the harness can
drive per-turn rather than a resident loop; liveness (`veto-sweep.ps1:76-83`,
`watch-runs.ps1:123-125`) needs a source other than the local process table; the worktree
inference (`SKILL.md:78-80`, `failure.md:115-119`) needs a GitHub-side substitute; and
`publish-runs.ps1:24`/`:34` need a configured root and a required gist id rather than a
hard-coded pair. The precedent for how to do that already exists at `failure.md:82-83` —
put the fact on GitHub.

**Message-bridge — largest, but the smallest *output* change.** Its output shape is the
best match Caesar has: the watcher already emits one event per line
(`skill/references/watcher.md:36-46`), the gist line is already 30–60 words
(`skill/scripts/spawn-ticket-agent.ps1:121-124`), the first turn is already four lines
(`skill/SKILL.md:119-127`), and none of these strain a 4,096-character cap. What it cannot
supply is a process host, and every machine-bound row therefore fails at once. A bridge is
viable only in front of a Caesar that already runs somewhere persistent — i.e. it is a
delivery surface, not a host, and the honest version of that design is the SSH fix plus a
bridge that relays.

One note on relative effort. The phone-readable gist (`SKILL.md:144-146`,
`publish-runs.ps1:165-179`) already exists and already works on all three surfaces. It is
one-way — Caesar writes, Raj reads — but it means the *reporting* half of the phone problem
is largely solved already, and what remains is the *driving* half: the status view's
render, and the host.
