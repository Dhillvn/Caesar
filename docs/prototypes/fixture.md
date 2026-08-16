# Command centre prototype fixture

Every prototype for ticket #182 hard-codes exactly this data. Same numbers, same titles,
same states — so the comparison is about the design and nothing else.

Generated-at to display: `2026-08-16 10:18` (refreshed 12s ago).

## Global

- Agent slots: **0 of 4 in use** (the runs below are historical unless marked RUNNING).
- Open PRs: **1**.

### Open PRs

| # | Title | Repo | Draft | URL |
|---|---|---|---|---|
| 174 | Report a centurion's own failure modes back into the session | Dhillvn/Caesar | yes | https://github.com/Dhillvn/Caesar/pull/174 |

### Centurion runs

| Ticket | Repo | Classification | Cost | Turns | When |
|---|---|---|---|---|---|
| 168 | Dhillvn/Caesar | LANDED | $2.41 | 38 | 2026-08-15 16:02 |
| 167 | Dhillvn/Caesar | ERRORED | $5.00 | 61 | 2026-08-15 14:47 |
| 166 | Dhillvn/numen-ops | LANDED (no GIST) | $1.12 | 19 | 2026-08-15 11:20 |
| 161 | Dhillvn/Caesar | LANDED | $3.08 | 44 | 2026-08-14 18:55 |

The ERRORED run is `terminal_reason: budget cap reached`.

## Maps — 4 driven, 21 open tickets

### Map A — `Dhillvn/Caesar` #178

**One self-refreshing command centre for every Caesar map**
https://github.com/Dhillvn/Caesar/issues/178 — 0 decided, **9 open**
Last decided: none yet.

| # | Title | Type | Owner | State | Blockers |
|---|---|---|---|---|---|
| 179 | Measure the sweep, and choose how the page stays fresh | research | Caesar | Ongoing | — |
| 180 | Retire caesar:driving from the maps that are finished | task | Caesar | Ongoing | — |
| 181 | Emit the whole picture as one JSON document | task | Caesar | Ongoing | — |
| 182 | Prototype how the command centre looks | prototype | You | Queued | — |
| 183 | Build the renderer and the refresh loop, and make every row on the page click through to GitHub | task | Caesar | Blocked | 179, 181, 182 |
| 184 | Make it one command that stays running | task | Caesar | Blocked | 183 |
| 186 | Decide what the page shows when a sweep fails | grilling | You | Queued | — |
| 187 | Rule whether the history view belongs on the page | grilling | You | Queued | — |
| 188 | Package the command centre so a cold machine can run it | task | Caesar | Blocked | 184 |

Ticket 183's title is deliberately long — it must wrap to two lines and the layout must
still hold. URLs are `https://github.com/Dhillvn/Caesar/issues/<number>`.

### Map B — `Dhillvn/numen-ops` #61

**Give every scheduled job a health signal Raj can read**
https://github.com/Dhillvn/numen-ops/issues/61 — 12 decided, **5 open**
Last decided: #78 *Ship the heartbeat file format* — https://github.com/Dhillvn/numen-ops/issues/78

| # | Title | Type | Owner | State | Blockers |
|---|---|---|---|---|---|
| 79 | Alert when a job misses two consecutive runs | task | Caesar | Needs you | — |
| 80 | Survey what the nine jobs already write on failure | research | Caesar | Queued | — |
| 81 | Rule where the health signal is surfaced | grilling | You | Queued | — |
| 83 | Wire the heartbeat into the remaining six jobs | task | Caesar | Blocked | 80 |
| 84 | Decide the retention window for heartbeat history | grilling | You | Queued | — |

Ticket 79 carries `caesar:needs-raj` — it is flagged, so it reads **Needs you**, it is Raj's
whatever its type says, and it does **not** count as an agent slot. URLs are
`https://github.com/Dhillvn/numen-ops/issues/<number>`.

### Map C — `Dhillvn/Caesar` #140

**Caesar drives several maps in one session without losing the thread**
https://github.com/Dhillvn/Caesar/issues/140 — 7 decided, **4 open**
Last decided: #158 *Withdraw from a map as a drain, not a stop* — https://github.com/Dhillvn/Caesar/issues/158

| # | Title | Type | Owner | State | Blockers |
|---|---|---|---|---|---|
| 159 | Rule how a session picks between two live frontiers | grilling | You | Queued | — |
| 160 | Measure the context cost of a two-map startup | research | Caesar | Queued | — |
| 162 | Teach status.ps1 to group by map rather than by repo | task | Caesar | Blocked | 159 |
| 163 | Decide whether a withdrawn map keeps its claim | grilling | You | Queued | — |

URLs are `https://github.com/Dhillvn/Caesar/issues/<number>`.

### Map D — `Dhillvn/numen-ops` #44

**Every credential on the machine has a known owner and an expiry**
https://github.com/Dhillvn/numen-ops/issues/44 — 9 decided, **3 open**
Last decided: #71 *Inventory every token the scheduled jobs hold* — https://github.com/Dhillvn/numen-ops/issues/71

| # | Title | Type | Owner | State | Blockers |
|---|---|---|---|---|---|
| 72 | Rotate the gws refresh token to a minimum-scope client | task | Caesar | Needs you | — |
| 73 | Decide which credentials may live in a cloud runner | grilling | You | Queued | — |
| 75 | Record an expiry date against every token | task | Caesar | Blocked | 72 |

Ticket 72 carries `caesar:needs-raj`. URLs are
`https://github.com/Dhillvn/numen-ops/issues/<number>`.

## Totals to display

- 4 maps driven, 21 open tickets, 28 decided.
- Needs Raj: 8 — the 6 `You`-owned tickets (182, 186, 187, 81, 84, 159, 163, 73 → that is 8
  You-owned) plus the 2 flagged (79, 72) = 10 rows that are his. Caesar holds 11.
- Count them from the tables above rather than trusting this line; the tables are the truth.
