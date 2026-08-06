# Does every skill name Caesar invokes still resolve?

Ticket: [#99](https://github.com/Dhillvn/Caesar/issues/99) · 2026-08-06 · read-only against `C:\Users\rajdh\.claude\`

## Answer

**Yes — every skill name Caesar says still resolves, and nothing needs renaming.**

The feared breakage does not exist. A **bare skill name resolves to a plugin skill**; the
`mattpocock-skills:` namespace prefix is optional, not required. This was checked, not
reasoned: the Skill tool accepted `grilling` and `mattpocock-skills:grilling` identically in a
nested headless run, with a known-bad control name rejected in the same probe.

Caesar names **no `superpowers` skill anywhere**, so that plugin being disabled costs him
nothing.

The only two names that do not resolve to a Skill-tool call — `wayfinder` and `implement` —
fail because they carry `disable-model-invocation: true`, which is a property of those skills
and not of the namespacing change. Caesar's `SKILL.md` already documents `wayfinder`'s case
and already routes around it by path via `claude plugin list --json`. `implement` is mentioned
descriptively, never invoked.

## The roster

Every skill name in `skill/SKILL.md` and every file under `skill/scripts/`.

| Name | Where Caesar says it | Resolves to | Broken? |
|---|---|---|---|
| `wayfinder` | `SKILL.md:17`, `SKILL.md:210` (`/wayfinder`) | plugin `mattpocock-skills` → `skills\engineering\wayfinder`. **Skill tool refuses it**: `disable-model-invocation: true` | **No.** Refusal is by design and Caesar already documents it and reads the file by path via `claude plugin list --json`. |
| `grilling` | `SKILL.md:164` (`/grilling`) | plugin `mattpocock-skills` → `skills\productivity\grilling`. Bare name accepted; namespaced name accepted; no local copy exists | No |
| `domain-modeling` | `SKILL.md:164` (`/domain-modeling`) | plugin `mattpocock-skills` → `skills\engineering\domain-modeling`. Bare name accepted; no local copy exists | No |
| `implement` | `SKILL.md:566` (`/implement`) | plugin `mattpocock-skills` → `skills\engineering\implement`. **Skill tool refuses it**: `disable-model-invocation: true` | **No** — Caesar describes its behaviour, he never invokes it. Worth knowing a centurion cannot call it either. |
| `impeccable` | `SKILL.md:309`, skill block table | local `C:\Users\rajdh\.claude\skills\impeccable`. Accepted | No |
| `numen-stack-review` | `SKILL.md:310`, skill block table | local `...\skills\numen-stack-review`. Accepted | No |
| `codex-review` | `SKILL.md:310`, skill block table | local `...\skills\codex-review`. Accepted | No |
| `ponytail` | `SKILL.md:280`, `SKILL.md:283` (cited as inherited from global `CLAUDE.md`, not invoked) | plugin `ponytail` → `ponytail:ponytail`. Bare name accepted; no local copy exists | No |
| `caesar` | `SKILL.md:3,39,44,51,56,121,758` (`/caesar`) | local `...\skills\caesar`. Accepted | No |
| `claude-api` | `SKILL.md:286,291,301`; guardrail heredoc `scripts/spawn-ticket-agent.ps1:112` | bundled skill, present in the harness skill list | No — and deliberately **not** probed: it is the one banned skill (~898 KB injected), so invoking it to test it would defeat the ban. |
| `notebooklm` | `SKILL.md:314–323` | Caesar names the **CLI** (`notebooklm auth check`), not the skill. A local `...\skills\notebooklm` also exists and the Skill tool accepts the name | No |
| Firecrawl | `SKILL.md:311`, skill block table | MCP server, not a skill. Out of scope for name resolution | No |
| caveman mode | `SKILL.md:280` | Named as a global-`CLAUDE.md` behaviour, not as a skill name to invoke. Plugin `caveman` is installed and enabled | No |
| any `superpowers` skill | — | **No occurrence.** Grepped `skill/` for `superpowers` and all 14 skill names under that plugin: zero hits | N/A |

## How each row was checked

**Roster.** `grep -rn` over `skill/SKILL.md` and every file under `skill/scripts/`, plus a
sweep for bare `/name` invocations and for all 14 `superpowers` skill names. Only
`spawn-ticket-agent.ps1` names a skill among the scripts (`claude-api`, in the guardrail
heredoc); no other script names one.

**Roster of what exists.** Local skills: directory listing of
`C:\Users\rajdh\.claude\skills\` (27 entries; **no `wayfinder`, no `grilling`, no
`domain-modeling`, no `ponytail`** — the hand-copied Pocock set has been moved to
`C:\Users\rajdh\.claude\skills-archive\pocock-handcopied-20260806\`). Plugins:
`claude plugin list --json`. Enabled plugins are `caveman`, `mattpocock-skills` (1.2.2),
`ponytail`; `superpowers` (6.2.0) is installed but **disabled**. Skills enumerated under each
`<installPath>\skills\`.

**`disable-model-invocation`.** Read straight from frontmatter across all `SKILL.md` files in
the `mattpocock-skills` install path. Set on: `wayfinder`, `implement`, `to-spec`,
`to-tickets`, `triage`, `improve-codebase-architecture`, `grill-with-docs`, `ask-matt`,
`setup-matt-pocock-skills`, `teach`, `grill-me`, `handoff`, `wait-what`, `to-questionnaire`,
`claude-handoff`, `loop-me`, `setup-ts-deep-modules`, `writing-beats`, `writing-fragments`,
`writing-shape`. Not set on `grilling`, `domain-modeling`, `research`, `tdd`, `prototype`,
`code-review`, `codebase-design`, `diagnosing-bugs`, `resolving-merge-conflicts`, `wizard`,
`writing-for-agents`.

**Resolution.** Three nested headless probes — `claude -p` in a scratch directory, each asking
the run to call the Skill tool with a given name and report `ACCEPTED` or the verbatim
rejection. (`--permission-mode bypassPermissions` must **not** be passed: the parent session's
permission layer auto-denies it and the nested call never runs.)

Probe 1 — bare vs namespaced:

```
bare: ACCEPTED
namespaced: ACCEPTED
```

Probe 2 — refused names, with an unknown-name control proving rejections are real:

```
wayfinder: REJECTED Skill wayfinder cannot be used with Skill tool due to disable-model-invocation. …
implement: REJECTED Skill implement cannot be used with Skill tool due to disable-model-invocation. …
control:   REJECTED Unknown skill: zzz-does-not-exist
```

Probe 3 — the remaining named skills, all `ACCEPTED`: `domain-modeling`, `impeccable`,
`numen-stack-review`, `codex-review`, `notebooklm`, `caesar`, `ponytail`.

Every row above is a checked result except `claude-api` (present in the harness skill list;
not probed, by the ban) and the two non-skill rows (Firecrawl, caveman mode).

## What this corrects

The prior finding in #84 — "plugin skills are namespaced and a local copy wins only the bare
typed command name" — reads as if a bare name needs a local copy to resolve. It does not.
`grilling`, `domain-modeling` and `ponytail` all have **no** local copy today and all resolve
from the bare name. What a local copy wins is the `/name` slash-command shadow, not Skill-tool
resolution.

## Consequences for the fix ticket

Nothing to rename. Two things worth writing down instead:

1. The `wayfinder` paragraph in `SKILL.md:17–32` is correct and should stay — it is the one
   place where a name genuinely does not resolve through the Skill tool.
2. `/implement` at `SKILL.md:566` is descriptive prose about a skill neither Caesar nor a
   centurion can invoke. If that line is ever read as an instruction to run it, it will fail
   the same way `wayfinder` does. A half-sentence saying so would close the gap.
