# Branch fixtures

One JSON file per fixture. `branch-harness.ps1` globs this directory, so adding a sixth
branch is dropping a sixth file here — the runner never changes.

## Schema

| Key | Meaning |
|---|---|
| `id` | Filename-safe id. `-Fixture <id>` selects it. |
| `branch` | The Caesar branch this forces, in words. |
| `situation` | Why this arrangement *is* the branch rather than a question about it. |
| `map` | `null`, or `{ "title": ..., "body": ... }`. A `null` map means the fixture creates no map — the Chart branch needs the absence of one. |
| `tickets` | Array of `{ key, title, labels, body, assign, close, comment, blocked_by }`. `key` is referenced from other bodies as `{key}` and substituted with `#<number>` once created. `assign: true` assigns to the authenticated login (a claim). `comment` posts one comment after creation. `blocked_by` lists other `key`s. |
| `invocation` | The session's first and only user message. `{map_url}` is substituted. Natural language, not `/caesar` — a slash command in `-p` swallows the rest of the message. |
| `expect_reads` | Reference files the fixture predicts the session will read, as paths relative to the Caesar skill root (e.g. `references/prompt-shape.md`). Empty is a real prediction: today most branches have nothing to point at. |
| `expect_markers` | Regexes matched case-insensitively against the session's final text. This is how the report knows the branch *fired*, as opposed to the session reading nothing and saying nothing. |

Bodies are plain JSON strings with `\n` escapes and are written to a temp file before
they reach `gh --body-file`. They never travel through argv.

## Fixture hygiene

Every issue the harness creates is titled `[FIXTURE <id>] ...` and carries the
`caesar:fixture` label, which the runner creates with `gh label create` first —
`gh issue create --label` hard-errors on an unknown label and creates nothing.

`branch-harness.ps1 -Cleanup` closes every open `caesar:fixture` issue in the repo and
comments why. Nothing else in the repo carries that label.
