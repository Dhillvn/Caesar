# Pocock plugin collision inventory

`mattpocock-skills` plugin v1.2.2 (`8b36d4f`, `.claude-plugin/plugin.json` at `mattpocock/skills` HEAD) ships 25 skills. This table checks each against everything already on this machine that could plausibly fire for the same request: hand-copied Pocock skills in `C:\Users\rajdh\.claude\skills\`, Numen skills, `superpowers:` plugin skills, and `codex` variants.

**Notice discrepancy (significant finding):** `C:\Users\rajdh\.claude\skills\MATT-POCOCK-NOTICE.md` claims exactly two local modifications — `implement/SKILL.md` (tdd/code-review refs rewired) and `setup-matt-pocock-skills/domain.md` (`/grill-with-docs` repointed). Diffing both files against upstream `17f22a3` byte-for-byte (after normalizing the clone's CRLF line endings, which otherwise make every file look changed) shows **neither modification is actually present** — both files are identical to upstream. Instead, three *other* hand-copied skills carry real, undocumented modifications: `prototype/SKILL.md` + `prototype/LOGIC.md` (rewritten from a shareable-HTML demo to a terminal-UI prototype), `to-tickets/SKILL.md` (one line dropped), and `grilling/SKILL.md` (rewritten from a strict one-question-at-a-time interview to a frontier/rounds model). The notice isn't just missing a third entry — it names the wrong two files entirely.

9 of the 25 rows below are marked `identical`.

| Plugin skill | Local equivalent | Where the local one lives | Same job? | Notes |
|---|---|---|---|---|
| ask-matt | none | — | distinct | Router over Pocock's own flow; no local analogue does this (closest concept, `caveman:cavecrew`, routes a different subagent set) |
| diagnosing-bugs | `superpowers:systematic-debugging` | `C:\Users\rajdh\.claude\plugins\cache\claude-plugins-official\superpowers\6.1.1\skills\systematic-debugging` | overlapping | Same "diagnose before fixing" discipline, independently written |
| grill-with-docs | `grill-with-docs-codex` | `C:\Users\rajdh\.claude\skills\grill-with-docs-codex` | overlapping | Both grill + update docs, but local adds a second Codex-adversarial act |
| triage | none | — | distinct | Only `setup-matt-pocock-skills\triage-labels.md` exists locally, and that's a label vocabulary table, not the triage state-machine flow |
| improve-codebase-architecture | hand-copied Pocock skill | `C:\Users\rajdh\.claude\skills\improve-codebase-architecture` | identical | No content diff vs `17f22a3` |
| setup-matt-pocock-skills | hand-copied Pocock skill | `C:\Users\rajdh\.claude\skills\setup-matt-pocock-skills` | identical | No content diff vs `17f22a3`, incl. `domain.md` — notice's claimed mod is not present |
| tdd | `superpowers:test-driven-development` | `C:\Users\rajdh\.claude\plugins\cache\claude-plugins-official\superpowers\6.1.1\skills\test-driven-development` | overlapping | Same red-green-refactor discipline, independently written |
| to-spec | hand-copied Pocock skill | `C:\Users\rajdh\.claude\skills\to-spec` | identical | No content diff vs `17f22a3` |
| to-tickets | hand-copied Pocock skill (modified) | `C:\Users\rajdh\.claude\skills\to-tickets` | overlapping | One line dropped from upstream ("Work the frontier one ticket at a time with `/implement`, clearing context between tickets.") — undocumented, minor |
| wayfinder | hand-copied Pocock skill | `C:\Users\rajdh\.claude\skills\wayfinder` | identical | No content diff vs `17f22a3` |
| implement | hand-copied Pocock skill | `C:\Users\rajdh\.claude\skills\implement` | identical | No content diff vs `17f22a3` — notice's claimed tdd/code-review rewire is not present; file still reads `/tdd` and `/code-review` verbatim |
| prototype | hand-copied Pocock skill (modified) | `C:\Users\rajdh\.claude\skills\prototype` | overlapping | Upstream builds a shareable HTML demo; local version rewrites the same skill to build a terminal-UI prototype instead — a real behavioral fork, undocumented |
| research | hand-copied Pocock skill | `C:\Users\rajdh\.claude\skills\research` | identical | No content diff vs `17f22a3` |
| domain-modeling | hand-copied Pocock skill | `C:\Users\rajdh\.claude\skills\domain-modeling` | identical | No content diff vs `17f22a3` |
| codebase-design | hand-copied Pocock skill | `C:\Users\rajdh\.claude\skills\codebase-design` | identical | No content diff vs `17f22a3` |
| code-review | `numen-stack-review`, `codex-review`, `superpowers:requesting-code-review` / `receiving-code-review`, `caveman:caveman-review` | `C:\Users\rajdh\.claude\skills\numen-stack-review`, `C:\Users\rajdh\.claude\skills\codex-review`, superpowers cache, caveman marketplace | overlapping | Plugin skill is a dual-axis (Standards + Spec) parallel-subagent review; no single local skill matches that shape, but the job is jointly covered by several |
| resolving-merge-conflicts | none | — | distinct | No local skill walks a live merge/rebase conflict |
| wizard | — (new since local snapshot) | — | n/a | Generates a one-off interactive bash wizard script for human-only manual steps (provisioning, credentials, cutovers) |
| grill-me | `grill-me-codex` | `C:\Users\rajdh\.claude\skills\grill-me-codex` | overlapping | Plugin skill is a plain grilling interview; local adds a second Codex-adversarial act on top |
| grilling | hand-copied Pocock skill (modified) | `C:\Users\rajdh\.claude\skills\grilling` | overlapping | Upstream rewritten from strict one-question-at-a-time interview to a frontier/rounds model with sub-agent fact-finding — a real behavioral fork, undocumented |
| handoff | `save-session` | `C:\Users\rajdh\.claude\skills\save-session` | overlapping | Same goal (context handoff to a fresh session); local version is Raj-specific — per-workstream, dead-ends-first format, SAVE/RESUME/CLEAR modes — vs upstream's generic one-shot summary |
| teach | hand-copied Pocock skill | `C:\Users\rajdh\.claude\skills\teach` | identical | No content diff vs `17f22a3` |
| to-questionnaire | — (new since local snapshot) | — | n/a | Turns a decision the user can't answer alone into an async questionnaire document for a knowledgeable third party |
| wait-what | — (new since local snapshot) | — | n/a | Re-pitches the model's last message in Simplified Technical English when the user signals it didn't land |
| writing-for-agents | — (new since local snapshot) | — | n/a | Reference for writing any agent-consumed document (skills, `AGENTS.md`/`CLAUDE.md`) around the concept of context pointers |

## Method

- Plugin's 25 skills read from `.claude-plugin/plugin.json` at `mattpocock/skills` HEAD (`8b36d4f`, v1.2.2), cloned to a scratch temp directory.
- Local-modification claims verified by adding a detached worktree at `17f22a3` and running `diff -rq --strip-trailing-cr` between each hand-copied local skill folder and its upstream counterpart at that commit (the clone checks out CRLF line endings on Windows; without stripping, every file falsely shows as changed).
- The `agents/` subfolder present in every upstream skill folder but absent locally is upstream scaffolding (subagent templates), not skill content — not counted as a modification.
