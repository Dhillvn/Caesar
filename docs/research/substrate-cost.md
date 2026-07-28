# What one ticket costs in each substrate

Resolves [#15](https://github.com/Dhillvn/caesar/issues/15). Measured 2026-07-28 on Claude Code
`2.1.220`, Windows 11, native (no WSL, no tmux). All runs used `--model sonnet` so the token
counts are comparable; dollar figures are Sonnet 5 rates.

## Method

One fixed, ticket-shaped job, run identically in every substrate from
`C:\Users\rajdh\Projects\caesar` (so each run loads the same CLAUDE.md, skills and settings):

> Read the file `docs/research/firstmate.md` in this repository. In exactly one sentence, state
> what First Mate's escalation layer does. Write only that sentence (no preamble, no markdown)
> to the file `measure/out-RUNLABEL.txt`. Then stop.

Costs come from two places, cross-checked against each other:

- `claude -p --output-format json` reports `total_cost_usd` and a `usage` block directly.
- The session transcripts under `~/.claude/projects/<slug>/` carry per-message `usage`, including
  `cache_creation.ephemeral_5m_input_tokens` / `ephemeral_1h_input_tokens`. Subagent transcripts
  live in a `<session-id>/subagents/agent-*.jsonl` subdirectory, separate from the parent's.

Reconstructing cost from the transcripts reproduces the CLI's own `total_cost_usd` to within
$0.002, which is what makes the parent/subagent split below trustworthy. The rate card it implies:

| | per 1M tokens |
|---|---|
| input | $3.00 |
| output | $15.00 |
| cache read | $0.30 |
| cache write, 1h TTL | $6.00 |
| cache write, 5m TTL | $3.75 |

## Results

| Substrate | Cold run | Warm run | Wall clock | Lands in parent context |
|---|---|---|---|---|
| **Subagent** (marginal, from a live parent) | $0.148 | **$0.089** + $0.015 parent re-read ≈ **$0.104** | ~10-14s of the parent's 18-23s | 274-285 chars (~75 tokens) |
| **Headless `claude -p`** | $0.295 | **$0.139** | 12-14s | nothing, if stdout is redirected to a file |
| **Background `claude --bg`** | $0.361 | **$0.225** | 18-20s, plus 1.4s to spawn | nothing — the parent never sees it |

Warm-state ratio: **subagent 1.00x · headless 1.34x · background 2.16x.**

Raw numbers, deduplicated by cache-token signature (the transcript writes each assistant message
twice, once partial and once final):

| Run | Substrate | cache write | cache read | output | $ | wall |
|---|---|---|---|---|---|---|
| b1 | headless, cold | 44,287 (1h) | 79,319 | 366 | 0.2950 | 12.4s |
| b2 | headless, warm | 17,340 (1h) | 106,287 | 368 | 0.1414 | 12.9s |
| b3 | headless, warm | 16,541 (1h) | 107,979 | 337 | 0.1367 | 14.2s |
| a1 | subagent — parent | 12,035 (1h) | 65,491 | 334 | 0.0969 | 22.8s total |
| a1 | subagent — child | 33,119 (5m) | 59,888 | 418 | 0.1484 | |
| a2 | subagent — parent | 11,167 (1h) | 64,660 | 318 | 0.0912 | 18.1s total |
| a2 | subagent — child | 16,431 (5m) | 76,174 | 272 | 0.0885 | |
| c1 | background, cold | 51,503 (1h) | 139,306 | 646 | 0.3605 | 19.6s |
| c2 | background, warm | 27,152 (1h) | 166,802 | 771 | 0.2245 | 18.2s |

**The subagent is cheapest, and the margin is small.** Roughly 4/3 the price to go headless and
just over 2x to go background. At these numbers the substrate choice is worth about $0.03-0.12
per ticket, so it should be decided on the properties below, not on price.

Two things drive the spread. First, **subagents write 5-minute cache and top-level sessions write
1-hour cache** — verified directly, every subagent message reports its cache creation under
`ephemeral_5m_input_tokens` and every top-level one under `ephemeral_1h_input_tokens`. The 5m
write is 37.5% cheaper per token, which is most of the subagent's advantage. It also means a
subagent's cached prefix has almost certainly expired before the next ticket starts, so subagents
never get to amortise across tickets the way a long-lived session does. Second, **the job itself
is noise.** Every run spends 80-180K tokens on the system prompt, CLAUDE.md, skill list and tool
definitions; the actual work is one file read and one file write. Ticket cost is dominated by
the fixed per-session preamble, so a bigger ticket costs barely more than a trivial one — and
splitting one ticket into two roughly doubles its cost.

## Things only a live test could settle

**`--tmux` is dead on Windows, by an explicit guard, not by accident.** `claude --tmux --worktree x`
returns `Error: --tmux is not supported on Windows`. It also requires `--worktree`
(`Error: --tmux requires --worktree`). The platform check fires first. There is nothing to work
around here — Caesar cannot use tmux panes as a substrate.

**`claude -p` exit codes are 0, 1 and 143, and 1 is heavily overloaded:**

| Exit | Cases seen |
|---|---|
| 0 | success — **and also a run where the agent simply declined to do the work** |
| 1 | unknown flag; `--bg` combined with `--print`; `--tmux` on Windows; unavailable model; `--max-budget-usd` exceeded mid-run |
| 143 | SIGTERM (per [#2](https://github.com/Dhillvn/caesar/issues/2); not re-tested here) |

Exit 1 covers both "never started" (argument validation, before any tokens are spent) and "ran and
was cut off" (`--max-budget-usd 0.001` still billed $0.113 before failing). The discriminator is
stdout: argument errors print a bare message and no JSON, whereas a run that started and failed
emits a full result object with `"is_error": true`. **`subtype` is not a discriminator** — it
stayed `"success"` on a failed run. Use `is_error`.

**The dangerous case is exit 0.** A run where the agent was asked to do something its allowed-tools
list forbade returned exit 0, `is_error: false`, and an *empty* `permission_denials` array — the
model simply talked instead of acting. Process-level success says nothing about whether the ticket
was actually resolved. **Caesar must verify the artifact — the resolution comment, the closed
issue, the written file — and never trust an exit code as evidence of work done.**

## `--bg` behaves quite differently from the other two

Findings that matter more than its price:

- **`--bg` and `-p` are mutually exclusive.** `claude --bg -p "..."` exits 1 with
  `--bg and --print conflict: --print never starts the interactive session that 'claude agents'
  attaches to`. The prompt goes in as the positional argument. So there is **no `--output-format
  json` for a background session** — no result object, no `total_cost_usd`, no structured answer.
- **Every `--bg` run silently creates its own git worktree** under `.claude/worktrees/<random-name>`
  and migrates its cwd there a few seconds after launch. Two runs produced two worktrees
  (`kind-zooming-lemon`, `indexed-growing-graham`). The job's file writes land in the worktree,
  **not in the main checkout** — the measurement output for run c1 appeared at
  `.claude/worktrees/kind-zooming-lemon/measure/out-c1.txt` while `measure/` in the repo stayed
  empty. Anything Caesar spawns this way needs its work merged back, or it is invisible.
- **The worktrees are `locked` and survive `claude stop`** (`worktree retained at ...`). Cleanup is
  `git worktree unlock` then `git worktree remove --force`. Caesar has to do this himself or the
  directory accumulates one worktree per ticket forever.
- **`claude logs <id>` is not machine-readable** — it replays raw ANSI TUI frames, cursor moves and
  all. The only structured record of a background session is its transcript jsonl.
- **`claude agents --json` is the usable status API.** It needs no TTY, and reports `status`
  (`busy`/`idle`) plus `state` (`working`/`blocked`/`done`) per session, keyed by a short id. A
  finished session goes `idle`/`done` but **stays alive as a process** until `claude stop`. `state`
  also distinguishes `blocked` — a session waiting on a human — from `working`.

## What this means for [#7](https://github.com/Dhillvn/caesar/issues/7)

Cost does not decide it. The spread is $0.03-0.12 a ticket, which will not be the thing Raj
notices. What the measurements actually argue:

- **Subagents** are cheapest, return a ~75-token summary straight into Caesar's context, and are
  the only option that needs no plumbing to collect a result. Against them: they die with the
  parent session (per [#2](https://github.com/Dhillvn/caesar/issues/2)) and their 5m cache never
  amortises.
- **Headless `claude -p`** is 1.34x the price and buys a real result object — `is_error`,
  `total_cost_usd`, `permission_denials`, `session_id` — plus `--max-budget-usd` as a hard cap.
  It writes to the real checkout. This is the only substrate with a structured, parseable outcome.
- **Background `--bg`** is 2.16x the price and the only one that survives Caesar's session closing,
  but it pays for that with no structured result, an unreadable log, and a worktree per ticket that
  Caesar must merge and then clean up. It is the most work to adopt, not the least.

The measured facts do not support `--bg` for the common case. The live question for #7 is whether
surviving a closed session is worth giving up structured results — and if it is not, the choice is
between subagents and `claude -p`, on durability and result-parsing, not on cost.
