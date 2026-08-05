# Can a headless centurion query and ingest NotebookLM?

Ticket: [#74](https://github.com/Dhillvn/caesar/issues/74). Measured 2026-08-05 on Raj's
Windows machine, from inside a real spawned ticket agent (this document's author was one).

## Answer

**Neither is reliably available to a centurion today, and the blocker is the same for both:
authentication.** The `notebooklm` skill's CLI can do query *and* ingest — the API surface is
not the problem — but it authenticates with browser cookies that Google expires server-side
after roughly a week, and the only way to renew them is a human signing into a Chromium
window. At the moment of writing, the stored session was **already dead**, so both `ask` and
`source add` fail for any agent on this machine until Raj logs in again.

The rule that follows for a centurion prompt is therefore:

> Query the notebook if a live session happens to exist; **verify with a real call, never with
> `auth check`**; on failure fall back to reading sources directly. Never plan work that
> depends on NotebookLM ingesting sources first.

## The two questions, answered separately

### 1. Query — capable, but gated on a human-refreshed cookie

`notebooklm ask` is a plain non-interactive CLI call. Nothing about it needs a GUI, a display,
or a terminal prompt, and nothing in the centurion sandbox blocks it (see §3). It works
whenever the cookie is alive. It did not work today:

```
$ notebooklm ask "..." -n d7a2611d-43da-40a4-b7bf-9602195dbbde
Unexpected error: Authentication expired or invalid. Redirected to: https://accounts.google.com/...
Run 'notebooklm login' to re-authenticate.
```

Three findings make this worse than "the cookie expired":

**`auth check` reports a healthy session that does not work.** Run bare, it passes every check
— storage exists, JSON valid, 28 cookies, SID cookie present — and prints *"Authentication is
valid."* The same session then fails on the first real call. `auth check` only inspects the
file; the token fetch is skipped unless you pass `--test`, and `auth check --test` correctly
reports `Token fetch failed`. **Any centurion preflight must use `--test` (or just attempt the
real query) — the skill's documented `auth check` is a false green.**

**Expiry is server-side and unreadable from disk.** The stored profile
(`~/.notebooklm/profiles/default/storage_state.json`, last written **2026-07-26**) still holds
38 cookies of which exactly one — `OTZ`, not an auth cookie — was past its stated date. `SID`,
`__Secure-1PSID` and friends all claim validity into 2027. Google invalidated the session
anyway. So an agent cannot inspect the file and decide whether NotebookLM will work; only a
live call answers that. Observed lifetime from one human login to death: **~10 days**.

**There is no headless recovery.** `notebooklm auth refresh` exists and is exactly the command
you would hope for; against an expired session it fails with the identical redirect error.
`notebooklm login` opens a Chromium window and waits up to 5 minutes for an interactive Google
sign-in (2FA included) — a human action by construction, and one that cannot be performed by a
detached `claude -p` process with no attached user. `--browser-cookies chrome` (harvesting a
live Chrome session instead) is unusable on Windows because of app-bound cookie encryption.

The one genuinely useful headless affordance: the CLI accepts auth via the
`NOTEBOOKLM_AUTH_JSON` environment variable (inline storage-state JSON, no disk file), and
supports a `NOTEBOOKLM_REFRESH_CMD` hook plus a keepalive poke. That means a *live* session can
be handed to a spawned agent without touching disk, and a warm session can be kept warm. It
does not create a session, and it cannot revive a dead one.

### 2. Ingest — programmatically available on the consumer CLI, gated by the same cookie; genuinely headless only on the paid Enterprise API

**Ingestion is not click-only.** `notebooklm source add` takes local files (with
`--mime-type "text/plain"` for `.md`), URLs and YouTube links, and the skill already documents
a working bulk-ingest loop. It is an ordinary CLI call and would run fine unattended. It could
not be exercised today because it rides the same dead cookie as `ask` — so, in practice, ingest
is *never more available to a centurion than query is*. There is no scenario where an agent can
ingest but not query.

Two vendor facts worth recording, both re-confirmed against current docs (not the skill's
notes):

- **There is still no public consumer API.** The product was renamed **Gemini Notebook** in
  July 2026; the consumer surface remains browser-only, which is why `notebooklm-py` v0.6.0 is
  a cookie-driven unofficial client and why it breaks this way.
- **Gemini Notebook Enterprise does have a real, fully headless API** on
  `*-discoveryengine.googleapis.com/v1alpha`, authenticated with a normal bearer token
  (`gcloud auth print-access-token` — i.e. a service account works, no browser anywhere):
  `notebooks.create`, `notebooks.get`, `notebooks.listRecentlyViewed`, `notebooks.batchDelete`,
  `notebooks.share`, and for ingest `notebooks.sources.batchCreate` / retrieve / delete.
  ([notebooks](https://docs.cloud.google.com/gemini/enterprise/notebooklm-enterprise/docs/api-notebooks),
  [sources](https://docs.cloud.google.com/gemini/enterprise/notebooklm-enterprise/docs/api-notebooks-sources),
  both last updated 2026-08-03.)

  Note the inversion: the Enterprise API exposes **management and ingest but no documented
  ask/query method** — retrieval stays in the browser UI, and the overview page's "500 queries
  per user per day" is a UI limit. So the paid path would buy headless *ingest* and lose
  headless *query*, on notebooks in a Google Cloud project that are **not** the Numen Workspace
  notebooks in the skill's registry. It is not a drop-in fix; it is a different product.

### 3. The sandbox is not the blocker

`skill/scripts/spawn-ticket-agent.ps1` runs the centurion with `--permission-mode
bypassPermissions` and a 15-entry deny list covering merges, `rm -rf`, force pushes,
`gh repo delete`, `gh auth token`, `Read(~/.ssh/**)` and `Read(**/.env)`. Nothing in it touches
`Bash(notebooklm ...)`, the venv, or `~/.notebooklm`. This document is the proof: every command
quoted above was executed by a spawned ticket agent under exactly that deny list, and each one
reached Google and came back with a server response. A browser session, in the sense that
matters here, is a **file of cookies** — it survives detachment perfectly well. What does not
survive detachment is the human who has to create it.

## Consequences for Caesar

1. **Do not write "make NotebookLM read the sources" into a centurion prompt.** Ingest is
   programmatically possible but shares a failure mode with query, and both fail closed and
   silently-looking (`auth check` lies) roughly every week.
2. **The >5-source rule should read: query the notebook if it answers, otherwise read the
   sources directly.** Reading directly must be the documented fallback, not an improvisation.
3. **If a centurion does try NotebookLM, its preflight is `auth check --test` or the real
   query** — and a failure is a fallback, not a ticket-ending error.
4. **A cheap, real fix exists and is human-cadence, not agent-cadence:** Raj re-running
   `notebooklm login` weekly (or a scheduled job that pokes the session to keep it warm via the
   keepalive/`NOTEBOOKLM_REFRESH_CMD` path) would make both capabilities usable to centurions
   most of the time. Nothing an agent can do unblocks itself.

## Evidence log

| Check | Command | Result |
|---|---|---|
| CLI present | `notebooklm --version` | `NotebookLM CLI, version 0.6.0` |
| Static auth | `notebooklm auth check` | all rows pass, *"Authentication is valid."* — **wrong** |
| Live auth | `notebooklm auth check --test` | `Token fetch failed: Authentication expired or invalid` |
| Query | `notebooklm ask ... -n <id>` | exit 2, redirect to `accounts.google.com` |
| Headless re-auth | `notebooklm auth refresh` | same redirect error — no headless recovery |
| Interactive re-auth | `notebooklm login --help` | "Opens a browser window for Google login" |
| Session age | profile `storage_state.json` mtime | 2026-07-26 → dead by 2026-08-05 (~10 days) |
| Sandbox | `skill/scripts/spawn-ticket-agent.ps1` deny list | no rule touches the CLI or its profile |
