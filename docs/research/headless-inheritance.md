# Does a headless centurion inherit CLAUDE.md and the skill list?

Ticket: [#72](https://github.com/Dhillvn/caesar/issues/72). Measured 2026-08-05.

**Answer: it inherits all three.** A `claude -p` fired by `skill/scripts/spawn-ticket-agent.ps1`
starts with the global `~/.claude/CLAUDE.md`, the repo `CLAUDE.md`, the full skill list, and the
user-level SessionStart hooks already in context — the same as an interactive session.
`--worktree` changes nothing but the working directory. Caesar's prompt block is therefore an
**override** layer: name the exclusions, do not re-list what is already there.

## Method

Four probes through the real spawn path (`Tier Execute`, sonnet-5/medium, $0.75 cap). Each probe
was asked to print four lines and forbidden to touch the disk — because the whole point is what
was in context *before* it started, a file read would invalidate the answer.

| Q | Asks for | Only obtainable from |
|---|---|---|
| Q1 | the skill names in the "Skill outputs meant for external use" bullet | global `~/.claude/CLAUDE.md` |
| Q2 | the four issue numbers cited in the PowerShell rule | repo `CLAUDE.md` |
| Q3 | invoke `Skill(ponytail:ponytail-help)`, print its first heading | a live `Skill` tool |
| Q4 | the cwd as stated in context | the harness preamble |

No answer is guessable: Q1 is a private list of seven skill names, Q2 is `#19, #24, #32, #36`.
Reproducing them is an observable effect, not a self-report — the probe cannot emit content it
never received.

The `--worktree` arm is the frozen script unmodified. The no-`--worktree` arm is the same script
with the single line `'--worktree', $WorktreeName` deleted, run from the repo root; every other
flag identical.

Prompts used: `docs/research/worktree-ticket-72-9606/probe-prompt.txt` (v1) and `probe-prompt-v2.txt`.

## Results

| Probe | `--worktree` | Q1 global | Q2 repo | Q3 Skill | Q4 cwd | cost |
|---|---|---|---|---|---|---|
| `probe72-wt` | yes | all 7 names | `#19, #24, #32, #36` | `# Ponytail Help` | `…\.claude\worktrees\probe72-wt` | $0.249 |
| `probe72-wt2` | yes | all 7 names | `#19, #24, #32, #36` | `# Ponytail Help` | `…\.claude\worktrees\probe72-wt2` | $0.149 |
| `probe72-nowt2` | no | all 7 names | `19, 24, 32, 36` | `# Ponytail Help` | `C:\Users\rajdh\Projects\caesar` | $0.115 |
| `probe72-nowt` | no | refused (see below) | refused | refused | refused | $0.130 |

Raw results in `.claude/caesar-runs/probe72-*.json` (gitignored, machine-local).

### The disk-read control

Scripted over each probe's transcript `.jsonl`, counting `tool_use` blocks only (nothing read into
context): every completed probe made **exactly one tool call in its entire session, `Skill`**. Zero
`Read`, zero `Bash`, zero `Grep`. So Q1, Q2 and Q4 were answered out of the starting context, not
off the disk. `permission_denials` was `[]` in all four runs — nothing was blocked and retried.

### What proves each item

- **Global `~/.claude/CLAUDE.md` — inherited.** Q1 reproduced all seven private skill names, with
  no file read. Corroborated independently by probe `probe72-nowt`, which refused the v1 prompt as
  a suspected instruction-leak and wrote its refusal *in caveman style* — the global file's default
  mode, visibly in force in output that was trying not to disclose the file.
- **Repo `CLAUDE.md` — inherited.** Q2 reproduced `#19, #24, #32, #36`, which appear nowhere but the
  repo file. It reaches the worktree arm because `CLAUDE.md` is tracked, so `git worktree add`
  materialises it.
- **Skill list — inherited.** `Skill(ponytail:ponytail-help)` was called and returned; the transcript
  records the `tool_use`, and the returned heading `# Ponytail Help` is in the reply. The tool exists
  and resolves plugin skills.
- **Hooks — inherited.** Every probe transcript carries SessionStart hook records, and the caveman
  refusal above is that hook's effect landing in output.
- **`--worktree` — changes only the cwd.** `probe72-wt2` and `probe72-nowt2` differ on Q4 and on
  nothing else. Both transcript directories confirm it: the worktree arm logs under
  `…-claude-worktrees-probe72-wt2`, the plain arm under `…-Projects-caesar`.

## The one real gap

The worktree has **no `.claude/` of its own** — `.claude/worktrees/` is gitignored, so a spawned
worktree contains `CLAUDE.md`, `docs`, `scripts`, `skill` and no `.claude` directory at all.
Inheritance survives that only because everything measured here lives at *user* level
(`~/.claude/settings.json`, user skills, user CLAUDE.md) or is *tracked* (repo `CLAUDE.md`). This
repo has no `.claude/settings.json`, so nothing is lost today.

The consequence to remember: **project-level `.claude/` config would not reach a centurion.** If
Caesar ever grows repo-local hooks, permissions or project skills, they must be tracked *and* the
worktree must not gitignore them — otherwise they silently vanish for every headless agent while
still working interactively from the main checkout.

## Consequence for Caesar's prompt block

Do not enumerate skills a centurion "should have" — it has them. Spend the block on overrides:
which skills are banned for this ticket (e.g. `claude-api`), which are mandatory (`ponytail` before
code), and the operating rules that contradict the inherited defaults. Naming what is already
inherited is dead weight in every dispatch.
