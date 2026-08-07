# The watcher

Disclosed from `SKILL.md` ([#113](https://github.com/Dhillvn/Caesar/issues/113)): how a
finished centurion reaches you, how the watcher is armed, and the six events it reports.

### The watcher — how a landing reaches you

**Arm it once per session, at your first dispatch**, and leave it up:

```
Monitor(command: 'powershell -NoProfile -ExecutionPolicy Bypass -File
        "<skill>\scripts\watch-runs.ps1" -RepoPath "<repo>"',
        description: 'centurion landings', persistent: true)
```

**Both Windows paths are quoted, and that is load-bearing.** Monitor runs its command
through bash, which strips the backslashes out of an unquoted Windows path — so
`-RepoPath C:\Users\rajdh\Projects\caesar` arrives as `C:UsersrajdhProjectscaesar`, and a
watcher aimed there can never see a landing. The script now refuses a `-RepoPath` that
does not exist, emitting `WATCHER-BAD-REPOPATH` and exiting non-zero; before that it
polled the missing directory in silence and looked healthy for 75 minutes across two real
landings. **If you see `WATCHER-BAD-REPOPATH`, re-arm with the path quoted** — nothing
else is wrong.

One watcher covers every centurion on the machine, however many maps dispatched them — do
not arm one per ticket. It backfills silently on start, so re-arming after a crash replays
nothing and cannot double-append a gist to the map.

What the watcher is for: `spawn-ticket-agent.ps1` detaches and returns immediately, so a
finished centurion reaches nothing on its own: no `SubagentStop`, no background-task
completion, no entry in `claude agents`. Without a watcher your only wake is Raj typing,
and nothing obliges you to check on that turn — which is how a landed scout sits unreported
until he asks. **He should never have to ask.**

Six events, and **it returns no verdict** — same as `inspect-run.ps1`:

| Event | What it means |
|---|---|
| `LANDED` | result JSON parsed, `GIST:` line carried on the event — verify, then append |
| `LANDED-NO-GIST` | exit clean, no `GIST:` printed — verify the ticket before appending anything |
| `ERRORED` | `is_error: true`, with `terminal_reason` and cost |
| `DIED-AT-SPAWN` | the dispatched process is **gone**, its result file empty, no turn ever written — it definitely never started, and the stderr tail is on the event. Off the clock: it arrives on the next poll |
| `QUIET` | transcript has not advanced past the timer — **look, do not kill** |
| `NO-TRANSCRIPT` | past the timer and the session never wrote a turn — it *may* never have started |

`DIED-AT-SPAWN` and `NO-TRANSCRIPT` differ in certainty, and that is the whole distinction:
the first read the PID from the dispatch sidecar and found nothing alive, so the run is
terminal and is reported **once**. The second only knows the clock ran out, so it re-arrives
every `-RecheckMinutes` — the process may yet be alive.

`LANDED` is not "accept the gist" and `QUIET` is not "kill it". The failure table in
[`failure.md`](failure.md) makes both calls, unchanged.

**Never hand-poll the run directory.** The watcher is the only mechanism; a hand-poll only
fires on a turn you already have, which is the failure this replaces.
