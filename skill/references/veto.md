# When Raj vetoes a closed decision

Disclosed from `SKILL.md` ([#113](https://github.com/Dhillvn/Caesar/issues/113)): unwinding a
decision already commented, closed and written into the map.

## When Raj vetoes a closed decision

A decision already commented, closed and written into the map, that Raj now rejects.

**Raj initiates.** You may flag doubt about a closed decision and stop — you never
self-veto. Your reopen power (the failure table in [`failure.md`](failure.md)) covers an
answer he never accepted; it does not reach a ruling he made.

**The map must read true.** `## Decisions so far` looks like a history log but it is the
**session bootstrap** — every future Caesar is taught by it. A reversed line left
standing is live misinformation. So rewrite the line **in place**: keep the ticket link,
replace the gist with the reversal and a pointer to what supersedes it. Not struck
through, not appended below, never deleted. Briefing, not ledger.

**Unwinding is the same act as a flagged failure** — a closed resolution someone will
not accept is one situation, differing only in who said no. So: **reopen the ticket,
comment naming what Raj rejected and why, stamp `caesar:needs-raj`** ([`failure.md`](failure.md)). **A veto that
changes the *question* rather than the answer is not a veto at all; that is ordinary
charting.

**Sweep one hop, report, reopen nothing.** `scripts/veto-sweep.ps1 -Ticket <url>` lists
every issue that cross-references the vetoed one. It returns no verdict: separate
load-bearing dependants from passing citation yourself, propose an action per dependant,
and wait for his word. A second hop only where hop one came back contaminated.

The sweep's hop-one list is the report you work from. Do not reach for `gh search issues` —
#30 measured it at 12 hits of ~20 against the
timeline's 5, and the noise reads exactly like a real report. Known gap, accepted: the
sweep sees only tickets that wrote the link.

**Centurions still in the field are just another class of dependant.** The sweep reports
them with their PID; drain or kill is Raj's call. No second mechanism.

If the vetoed decision has already shipped, the code half is the merge gate's revert
(`SKILL.md`, *Build work and the merge gate*). This path owns the map-and-ticket half.
