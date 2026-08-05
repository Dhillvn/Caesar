# `--model` and `--effort`: precedence, proof, and cost

Research for [#50](https://github.com/Dhillvn/caesar/issues/50) on map [#49](https://github.com/Dhillvn/caesar/issues/49).
Measured 2026-08-04 against the installed Claude Code CLI on this machine, using subscription auth
(no `--bare`, per #7). Every claim below is either a documentation quote or a probe result; where
neither exists, the section says so.

## 1. A CLI flag beats user settings — confirmed both ways

The docs are explicit. `--model` "overrides the `model` setting" and "overrides the `ANTHROPIC_MODEL`
environment variable"; `--effort` "overrides the `effortLevel` setting for this session" and "does not
persist across sessions". The settings page states the scope order: managed (highest) > **command line
arguments** > local > project > user (lowest).

The "settings still apply" wording in `claude --help` is not about precedence — it means the rest of
your settings (permissions, hooks, MCP) still load. It does not mean `settings.json`'s `model` wins.

Proved empirically. The user settings at `C:\Users\rajdh\.claude\settings.json` carry
`"model": "claude-opus-5"` and `"effortLevel": "medium"`. A run passed `--model sonnet` reported
`claude-sonnet-5`, and a run passed `--effort high` logged `high`. Neither user setting survived.

## 2. The result JSON proves the model. It does not prove the effort.

**Model — `modelUsage`.** The `--output-format json` result object carries a top-level `modelUsage`
map, keyed by the model actually billed:

```json
"modelUsage": {
  "claude-sonnet-5": {
    "inputTokens": 2, "outputTokens": 4,
    "cacheReadInputTokens": 0, "cacheCreationInputTokens": 40010,
    "costUSD": 0.240126, "contextWindow": 1000000, "maxOutputTokens": 64000,
    "canonicalModel": "claude-sonnet-5", "provider": "firstParty"
  }
}
```

This is billing data, not a self-report, and it is the field to verify against. Read the key of
`modelUsage`, or `modelUsage.<key>.canonicalModel`. `spawn-ticket-agent.ps1` already writes exactly
this object to `.claude\caesar-runs\<worktree>-<stamp>.json`, so every past Caesar run on disk can be
audited retroactively for which model it used.

If a run ever falls back mid-session, `modelUsage` would hold more than one key — a single-key check
is therefore also a fallback detector.

**Effort — not in the result JSON.** No `effort` field appears anywhere in the result object. There is
no `--output-format json` evidence of the effort level used. Searched the full object; only
`modelUsage`, `usage`, `speed`, `service_tier`, `fast_mode_state` describe the configuration.

**Effort is recorded in the session transcript instead.** Each `assistant` record in
`~\.claude\projects\<encoded-cwd>\<session_id>.jsonl` carries a top-level `"effort"` key. The result
JSON gives you `session_id`; the transcript then gives you the effort. Verified across four runs —
`--effort low`, `medium`, `high` and `max` each logged the matching value.

That is harness-recorded state, not a model self-report, so it is acceptable evidence. Its weakness is
locality: the transcript lives under the user profile keyed by the run's cwd, is not part of the run
artifact, and is subject to whatever transcript retention the CLI applies. A dispatch policy that wants
durable effort proof should copy the effort out of the transcript into the caesar-runs record at spawn
time, or record the flag it passed.

## 3. Accepted `--effort` values, and what a bad one does

`claude --help` enumerates: **`low, medium, high, xhigh, max`**. The docs add **`ultracode`**
(starts at `xhigh` with ultracode on, v2.1.203+), and note available levels depend on the model.
The `effortLevel` *settings* key documents a narrower set — `low, medium, high, xhigh` — so `max` is
flag-only.

**An invalid value does not hard-error. It warns on stderr and continues.**

```
$ claude -p "..." --model sonnet --effort bogus --output-format json
Warning: Unknown --effort value 'bogus' — ignoring it and using the default effort. Valid values: low, medium, high, xhigh, max.
exit=0
```

The run completed normally, exit 0, valid result JSON. This is the dangerous case the ticket
anticipated: a typo'd effort produces a run that looks configured and is not.

The fallback is **not a hardcoded constant** — it re-resolves the normal chain. Proved by re-running
with `CLAUDE_CODE_EFFORT_LEVEL=high` alongside `--effort bogus`: the transcript logged `high`, not
`medium`. With no env var set, a bad flag therefore lands back on
`C:\Users\rajdh\.claude\settings.json`'s `"effortLevel": "medium"`.

**Mitigation already in place:** `spawn-ticket-agent.ps1` redirects stderr to its own file
(`-RedirectStandardError $stderrFile`). The warning is captured, so an invalid effort is detectable
after the fact by grepping that file for `Unknown --effort value`. Nothing today does that grep.

`--model` with a bad value was not probed. Unknown whether it errors or falls back; assume nothing.

## 4. Cost

### Derived unit rates

Solving the observed `costUSD` against the observed token counts across probes gives exact, consistent
rates (both models resolved a 1-hour ephemeral cache; write = 2× input, read = 0.1× input):

| | input | output | 1h cache write | cache read |
|---|---|---|---|---|
| `claude-sonnet-5` | $3 /MTok | $15 /MTok | $6 /MTok | $0.30 /MTok |
| `claude-opus-5` | $5 /MTok | $25 /MTok | $10 /MTok | $0.50 /MTok |

These reproduce every measured `total_cost_usd` to the fourth decimal. **Opus is 1.67× Sonnet per
token, flat, on every token class.**

### Raw probe results

Identical prompt ("list every markdown file under `docs/` and state in exactly 3 bullets what this repo
does"), run in the ticket worktree so the loaded context matches a real centurion:

| Config | cost | out tok | cache write | cache read | turns | wall |
|---|---|---|---|---|---|---|
| sonnet / low | $0.1077 | 269 | 13,885 | 67,866 | 2 | 6.6 s |
| sonnet / medium | $0.1052 | 406 | 13,167 | 67,067 | 2 | 11.1 s |
| sonnet / max | $0.2664 | 478 | 41,171 | 40,793 | 2 | 10.6 s |
| opus / medium | $0.3192 | 525 | 29,158 | 29,002 | 2 | 9.8 s |

**Read these raw numbers with suspicion.** They are dominated by cache warmth, not by model or effort.
The sonnet/max run cost 2.5× sonnet/medium almost entirely because it re-wrote 41 k of cache instead of
reading it — an artifact of probe ordering, not of effort.

### Normalised, cache-cold cost of that same task

Applying the derived rates to a cold start (~42 k context written to cache, observed output tokens):

| Config | cache write | output | **total** |
|---|---|---|---|
| sonnet / low | $0.252 | $0.004 | **$0.256** |
| sonnet / medium | $0.252 | $0.006 | **$0.258** |
| sonnet / max | $0.252 | $0.007 | **$0.259** |
| opus / medium | $0.420 | $0.013 | **$0.433** |

A trivial single-`--print` run with no work at all costs **$0.24 on Sonnet / $0.40 on Opus**, purely to
write ~40 k of system context into cache. That is the floor per cold run.

### What this means for `-BudgetUsd 2.0`

1. **Model choice is a flat 1.67× multiplier.** Sonnet instead of Opus buys 40 % off a ticket, no
   nuance. On the cold-start floor alone that is $0.40 → $0.24.
2. **The floor is the context, not the thinking.** Roughly $0.24–$0.40 of every ticket is spent before
   the agent does anything, writing CLAUDE.md + skills + hooks into cache. Trimming loaded context is a
   bigger lever on cheap tickets than picking a model.
3. **Effort's cost effect could not be measured usefully here.** On this task, low→max moved output
   from 269 to 478 tokens — $0.003 of difference. That is noise. A task this small does not exercise
   thinking budget, so **do not extrapolate**: this research does *not* establish what effort costs on
   a real ticket. Measuring it honestly needs two full ticket runs on identical work at different
   effort, which is a real-money experiment (a full Caesar ticket run, not a probe), and was out of
   scope here. Stated plainly rather than guessed.
4. **`-BudgetUsd 2.0` is not obviously wrong**, but it was never derived. At Opus rates it buys roughly
   5 cold cache writes plus reasoning; a research ticket that reads a lot and writes one doc will sit
   well under it, and a build ticket with many tool turns can approach it. Re-baselining properly needs
   per-turn cost from real caesar-runs artifacts, which now exist and carry `modelUsage` — the data is
   already on disk for whoever does that.

## 5. Method and honest limits

Probes were `claude -p "<trivial prompt>" --output-format json --model <m> --effort <e>`, never
`--bare`, never with a modified settings file, always with the flags on the command line. No file in
`C:\Users\rajdh\.claude\` and no file in the repo other than this document was written.

What was **not** established:

- Effort's real cost on ticket-sized work (§4.3).
- `--model` invalid-value behaviour.
- Whether `ultracode` is accepted by this installed version (docs-only claim, gated on v2.1.203+; the
  installed `--help` does not list it).
- Whether effort survives into any artifact other than the session transcript.
