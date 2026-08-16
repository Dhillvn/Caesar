# How the command centre stays fresh without Node

Ticket [#179](https://github.com/Dhillvn/caesar/issues/179), under map
[#178](https://github.com/Dhillvn/Caesar/issues/178). Measured on this laptop on
2026-08-16; Windows 11 Home 10.0.26200, Windows PowerShell 5.1.26100.9168,
`gh` 2.89.0. Live map set at measurement time: **6 open maps across 3 repos**.

**The ruling.** A detached PowerShell regenerator loop writing a static
`index.html`, ticking every **60 seconds**, with `<meta http-equiv="refresh"
content="30">` in the page. It beat an `HttpListener` on cost ceiling, on failure
shape, and on machinery. The binding constraint is not wall clock and it is not
process startup — it is the **GraphQL points budget**, and a listener that
regenerates per request has no ceiling on it at all.

**Two premises in the charting were wrong**, and the arithmetic below uses the
measured values instead:

- `frontier.ps1` costs **3 GraphQL points per map**, not 1. Its query walks
  `subIssues` → `assignees` + `labels` + `blockedBy`, and GitHub prices the
  connection nesting, not the call.
- `gh pr list` is **GraphQL, not REST**. A whole sweep spends **zero** REST core
  points and zero REST search points. `gh search issues` is also GraphQL. There is
  no REST budget to defend; there is only the one GraphQL budget, and everything
  competes for it.

---

## 1. Timing: one full sweep, three repeats

Harness lived in `%TEMP%`, not the repo. `frontier.ps1` was called, never edited.
All timings in milliseconds.

### Per component, in one PowerShell process

| Component | rep 1 | rep 2 | rep 3 | median | spread |
|---|---|---|---|---|---|
| `frontier.ps1` Caesar#178 | 1266 | 1333 | 874 | — | — |
| `frontier.ps1` numen-site#6 | 1298 | 1191 | 878 | — | — |
| `frontier.ps1` numen-ops#220 | 941 | 1408 | 1124 | — | — |
| `frontier.ps1` numen-ops#164 | 837 | 911 | 2259 | — | — |
| `frontier.ps1` numen-ops#35 | 749 | 890 | 1181 | — | — |
| `frontier.ps1` numen-ops#17 | 1307 | 905 | 834 | — | — |
| **all 18 frontier samples** | | | | **1033** | 749 – 2259, mean 1121 |
| `gh pr list` Dhillvn/Caesar | 528 | 711 | 587 | | |
| `gh pr list` Dhillvn/numen-site | 725 | 672 | 608 | | |
| `gh pr list` Dhillvn/numen-ops | 739 | 871 | 1179 | | |
| **all 9 pr-list samples** | | | | **711** | 528 – 1179, mean 736 |
| `caesar-runs` scan, 204 run files | 2628 | 395 | 605 | **605** | first sample is cold NTFS cache |
| `gh search` map discovery | 1686 | 1648 | 1698 | **1686** | tight |
| **whole sweep, warm process** | 11052 | 9304 | 10151 | **10151** | 9.3 – 11.1 s |

### End to end, cold `powershell.exe` per tick — what a loop actually pays

`status.ps1` invoked as a fresh process, three repeats per set:

| Set | rep 1 | rep 2 | rep 3 | mean |
|---|---|---|---|---|
| **4 maps / 3 repos** | 6228 | 6023 | 6966 | **6406 ms** |
| **6 maps / 3 repos** (live set) | 9921 | 13936 | 9249 | **11035 ms** |

**Per-map cost: 1.0 – 2.3 s.** The direct measurement (n=18, median 1033 ms) is the
trustworthy one; the 4-map→6-map delta implies 2315 ms/map but rests on n=3 per set
measured minutes apart, so it is noise-dominated. Every safety calculation below
uses the pessimistic 2.3 s.

**The 4-map total the charting asked for: 6.4 s** (measured, 6.0 – 7.0 s).
**The 6-map total as the set actually stands: 11.0 s** (9.2 – 13.9 s).
**A 9-map set projects to ~17.9 s** (6.4 s + 5 × 2.3 s), still under a fifth of the
chosen interval.

One implementation trap found while measuring, worth writing down because it is the
repo's PowerShell family again: `powershell.exe -File status.ps1 -MapUrl a b c`
**cannot bind a `string[]` parameter** — argument 2 lands on `-Cap` and the run dies
with a type-conversion error. A regenerator must use
`-Command "& '...\status.ps1' -MapUrl @('a','b','c')"`.

---

## 2. Attribution: process startup versus network

Measured, not inferred. Six samples each.

| Probe | samples (ms) | median |
|---|---|---|
| `gh --version` — gh.exe startup, no network | 190, 284, 991, 406, 175, 140 | **183** |
| `powershell.exe -NoProfile -Command exit` — WinPS 5.1 startup | 576, 1363, 917, 573, 520, 354 | **575** |
| `gh api rate_limit` — startup + one round trip | 672, 775, 820, 622, 568, 739 | **706** |

**Network dominates, startup does not.** One round trip to GitHub costs
706 − 183 = **~523 ms** of pure network. Against the median `frontier.ps1` call of
1033 ms, gh's process startup is **~18%**; the remaining ~850 ms is the GraphQL round
trip plus JSON parse, and the frontier query is materially heavier than the
`rate_limit` probe. On a `gh pr list` (median 711 ms) startup is ~26%.

The single `powershell.exe` startup a loop pays per tick is ~575 ms — **5% of an
11 s sweep**. Process startup is real but it is not the thing to optimise, and it is
not a reason to prefer a long-lived listener process over a loop that respawns.
(The loop below does not respawn per tick anyway; it pays that 575 ms once, at start.)

---

## 3. API cost of one sweep, and the safe interval

### Measured per-call cost

Each figure is a `gh api rate_limit` read either side of the call. `gh api
rate_limit` itself is **free on every budget** (core 4958 → 4958 across a whole
sweep), so it does not perturb what it measures.

| Call | GraphQL points | REST core | REST search |
|---|---|---|---|
| `frontier.ps1`, one map | **3** (n=3: 5, 3, 3 — the 5 contaminated by a concurrent centurion) | 0 | 0 |
| `gh pr list`, one repo | **1** (n=3: 1, 1, 1) | 0 | 0 |
| `gh search issues`, discovery | **1** | 0 | **0** |
| `gh api rate_limit` | 0 | 0 | 0 |

The REST search budget is 30/**minute**, and a sweep never touches it — `gh search
issues` goes through GraphQL. It is not a constraint.

### Cost per sweep

```
points = 1 (discovery) + 3 × maps + 1 × unique_repos
```

| Map set | arithmetic | points/sweep |
|---|---|---|
| 4 maps, 3 repos | 1 + 3×4 + 3 | **16** |
| 6 maps, 3 repos (live) | 1 + 3×6 + 3 | **22** |
| 9 maps, 3 repos (worst case) | 1 + 3×9 + 3 | **31** |

Sanity check against a whole live sweep: predicted 22, observed **49**. The 27-point
gap is a concurrent centurion (ticket #180 clearing map labels) spending inside the
same ~11 s window. That is the headroom argument, measured rather than assumed:
**interactive Caesar sessions burst at roughly 2.5 points/second while they run**,
which is ~9000 points/hour if it were ever sustained.

### Deriving the interval

Quota read at measurement time: GraphQL **5000/hr** (4950 → 4611 remaining across the
session), core **5000/hr** (untouched).

Reserve **75% of the GraphQL budget for interactive sessions and centurions**, giving
the command centre 1250 points/hour. Worst case 31 points/sweep:

```
1250 ÷ 31 = 40 sweeps/hour → one every 90 s   (theoretical floor)
```

Round to **60 s**, which is inside that floor on cost and comfortably outside it on
duty cycle:

| Map set | sweeps/hr at 60 s | points/hr | % of 5000 | left for sessions |
|---|---|---|---|---|
| 4 maps | 60 | 960 | 19% | 4040/hr |
| 6 maps | 60 | 1320 | 26% | 3680/hr |
| 9 maps | 60 | 1860 | 37% | 3140/hr |

Duty cycle at the worst measured sweep: 13.9 s / 60 s = **23%**. A tick can run 4×
slower than the worst sample and still finish before the next one starts, so no
overlap guard is needed beyond the single-instance lock in §5.

**30 s was rejected**: at 9 maps that is 3720 points/hour, 74% of the budget, leaving
1280 — one busy centurion burst eats it, and the thing the page exists to watch is
the thing it would starve. **300 s was rejected** the other way: it costs nothing but
a five-minute-old board is not a command centre; ticket state transitions are faster
than that.

The page's own `<meta http-equiv="refresh">` is a **local file read at zero API
cost**, so set it to **30 s** against a 60 s regenerate. Worst-case age of what Raj
is looking at: 60 s (generation gap) + 30 s (reload gap) + ~14 s (sweep) ≈ 105 s;
typical ~45 s.

---

## 4. The ruling, and why each loser lost

### Winner — (a) detached regenerator loop + `<meta http-equiv="refresh">`

One `powershell.exe -WindowStyle Hidden` process running
`while ($true) { try { render } catch { render-the-error }; Start-Sleep 60 }`,
writing `index.html`, opened `file:///…` in a browser tab. No port, no listener, no
JS, no HTTP stack, no dependency beyond what is already installed. The refresh
cadence is a constant in one place, so the quota cost is a fixed 1320 points/hour
regardless of what Raj does with the browser.

### Loser — (b) `HttpListener` serving the page, regenerating on request

Three reasons, in order of weight.

**The cost ceiling disappears.** Regenerate-on-request makes quota spend a function
of how often the page is fetched, not of an interval anyone chose. A JS timer in two
open tabs doubles it. A tab left open on a second screen and forgotten keeps
spending. A held-down F5 spends 22 points per keystroke. The §3 arithmetic — the
whole reason 60 s is defensible — only holds if exactly one thing decides when a
sweep happens, and a listener hands that decision to the browser.

**It fails invisibly at the process level and visibly at the wrong moment.** A
listener that dies takes the page with it: the browser shows `ERR_CONNECTION_REFUSED`,
which is at least honest, but it means the board is *gone* rather than *stale* — and
it will die while Raj is asleep, so it is gone every morning. Worse, `HttpListener`
in single-threaded PS 5.1 blocks on `GetContext()`; the 9–14 s sweep runs inside the
request, so every reload hangs the tab for ten seconds and a second concurrent
request queues behind the first. And binding anything other than
`http://localhost:PORT/` needs a `netsh http add urlacl` run elevated — machinery,
and machinery that has to be re-run after a reinstall.

**It is strictly more parts for the same output.** Both options end at "a browser
renders HTML that a PowerShell script generated". (b) adds a socket, a port, a URL
reservation, a request loop, a MIME decision, and client-side JS to the same
generator. The measurements give it nothing back: startup is 5% of a sweep (§2), so
the long-lived process buys no meaningful speed.

### Loser — (c1) Scheduled Task instead of a detached loop

A genuine contender, and it fixes the winner's ugliest failure mode ("Raj forgot to
start it") by surviving reboot. It loses **today** on machinery: task registration,
the "run whether user is logged on or not" credential prompt, and a second place
(Task Scheduler) to look when the page goes stale. Windows' minimum repetition
interval of 1 minute also pins the interval exactly at the chosen 60 s with no room
to tune. **Named as the upgrade path**: if failure mode 2 below actually bites in
practice, promoting the loop's launch to a logon-triggered Scheduled Task is a
two-line change to the same generator and nothing else moves.

### Loser — (c2) no page at all, `status.ps1` on a terminal loop

Cheapest possible. Loses because it occupies a terminal, dies when that terminal
closes, cannot be read from a phone or a second screen, and cannot show the run
corpus and the map tables in one glance. The point of #178 is a *board*, and a
scrollback buffer is not one.

---

## 5. Failure modes the winner carries

**Half-written file read mid-reload.** The browser can load `index.html` between the
truncate and the last write, rendering a blank or truncated board — and
`<meta refresh>` means it re-renders that garbage every 30 s until the next tick.
*Mitigation:* generate to `index.html.tmp` in the same directory, then swap with
`[IO.File]::Replace($tmp, $dst, $null)` — an NTFS same-volume rename, atomic from a
reader's view. Never write into the live file. Note `[IO.File]::WriteAllText` for the
tmp file, not `Set-Content -NoNewline`, per the repo's PowerShell rule.

**A loop Raj forgets to start.** This is the worst one, because it does not look like
a failure: the page loads, the tables render, `<meta refresh>` keeps reloading, and
every number is from yesterday. There is no live component to notice its absence.
*Mitigation:* bake the generation timestamp into the page as the largest thing on it,
not a footer. Because the page has no JS, it cannot age its own timestamp — so the
generator must also stamp the interval it believes it is running at, letting Raj do
the subtraction against the wall clock in one glance. A stale board must be
*obviously* stale, not merely *technically* labelled.

**The loop dies mid-run.** `frontier.ps1` sets `$ErrorActionPreference = 'Stop'` and
throws on any `gh` non-zero — a rate-limit 403, a dropped Wi-Fi, a map issue deleted.
An unhandled throw in the loop body kills the whole process, and the symptom is
identical to "forgot to start it". *Mitigation:* every tick's body inside
`try { } catch { }`; nothing is allowed to escape into the `while`.

**A failed sweep showing stale data.** Catching the throw creates the next hazard:
the page keeps the last good bytes and the last good timestamp, and reads as healthy.
*Mitigation:* on catch, **still rewrite the page** — keep the last good tables,
prepend a banner with the exception message, the time the sweep failed, and how many
consecutive ticks have now failed. A degraded board must never be byte-identical to a
working one.

**Sleep and wake.** This laptop has no S3, only modern standby (see
[`windows-sleep.md`](windows-sleep.md)). `Start-Sleep 60` does not run while
suspended, so an overnight sleep silently ages the board by hours and the loop
resumes as if nothing happened. Same mitigation as the forgotten loop — the on-page
timestamp is the only defence, which is why it must be prominent.

**Two loops running.** A second copy started after a reboot doubles the quota spend
and races the other on `[IO.File]::Replace`. *Mitigation:* a named
`System.Threading.Mutex` acquired at start; second instance exits with a message
rather than joining in.

---

## Appendix — reproducing

Harnesses were written to `%TEMP%\caesar-179-*.ps1` and are not part of this repo, by
design: they call `skill\scripts\frontier.ps1` and `status.ps1` unmodified, and the
only durable output of this ticket is this ruling. Raw output is pasted in the pull
request for #179. The three probes were: a component breakdown in one warm process
(3 reps × 6 maps, 3 repos, 204 run files); `status.ps1` as a cold process over a
4-map and a 6-map set (3 reps each); and a `gh api rate_limit` diff either side of
each individual call and of a whole sweep.
