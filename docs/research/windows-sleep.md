# Windows sleep, and what it does to a live Caesar session

Ticket [#166](https://github.com/Dhillvn/caesar/issues/166). Measured on this laptop on
2026-08-15; Windows 11 Home 10.0.26200.

The question is not "can Caesar run forever". Raj is content to let the machine sleep
overnight. The question is what exactly dies, when, and what the corpse looks like to the
next Caesar session.

**The short answer.** This laptop has no S3. It only has *modern standby* (S0 low-power
idle) and hibernate. In modern standby, Windows does not kill `claude` — it **suspends**
it. The process is still there on wake, still holding its PID, still holding a 0-byte
result file and a `ticket-N-*` worktree. That is worse than death: `watch-runs.ps1` only
declares a run dead when its **PID is gone**, and Caesar's startup rule reads an open
ticket plus a `ticket-N-*` worktree as *the live-centurion case*. A slept centurion is
therefore indistinguishable, on disk, from a working one — while its HTTPS stream to the
API has almost certainly been dropped hours ago.

---

## 1. What this laptop actually does today

Every figure below is from a read-only probe run during this ticket. No power setting was
changed.

### Sleep states available

`powercfg -a`:

```
The following sleep states are available on this system:
    Standby (S0 Low Power Idle) Network Connected
    Hibernate
    Fast Startup

The following sleep states are not available on this system:
    Standby (S1)  - firmware does not support; disabled when S0 low power idle is supported
    Standby (S2)  - firmware does not support; disabled when S0 low power idle is supported
    Standby (S3)  - disabled when S0 low power idle is supported
    Hybrid Sleep  - Standby (S3) is not available
```

**Measured.** This machine is a modern-standby machine. S3 does not exist on it, so every
piece of folk knowledge about "S3 sleep freezes the CPU" is inapplicable here. Microsoft:
"SoC systems that support Modern Standby don't use *S1-S3*."
([System power states](https://learn.microsoft.com/en-us/windows/win32/power/system-power-states))

The `Network Connected` suffix matters: this is connected standby, not disconnected
standby, so the networking stack is meant to stay up while the box is "asleep".

### Active scheme and timeouts

`powercfg -getactivescheme` → `381b4222-f694-41f0-9685-ff5bb260df2e (Balanced)`.

`powercfg -q SCHEME_CURRENT SUB_SLEEP`:

| Setting | GUID alias | AC | DC | Reading |
|---|---|---|---|---|
| Sleep after | `STANDBYIDLE` | `0x00002a30` = 10800 s | `0x00000000` | **3 hours on mains**, Never on battery |
| Allow hybrid sleep | `HYBRIDSLEEP` | `1` (On) | `1` (On) | set On, but **unavailable** — see conflict below |
| Hibernate after | `HIBERNATEIDLE` | `0x00000000` | `0x00000000` | Never, both |
| Allow wake timers | `RTCWAKE` | `0` (Disable) | `0` (Disable) | **Disabled, both** |

`0` on an idle timeout is powercfg's "Never". So: **left alone on mains, this laptop enters
modern standby after three hours.** That is inside the "Raj is out for a few hours" window
the destination assumes.

`powercfg -lastwake` → `Wake History Count - 0`.
`powercfg -devicequery wake_armed` → `NONE`. **No device on this machine is currently armed
to wake it.** Combined with `RTCWAKE = Disable`, nothing scheduled and nothing on the
network can bring it back — only a human touching it.

### Fast startup and hibernate

`Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"`
→ `HiberbootEnabled = 1`. **Fast startup is on.** `CsEnabled` and `PlatformAoAcOverride`
are both absent from `HKLM:\SYSTEM\CurrentControlSet\Control\Power`, i.e. modern standby is
running at its firmware default with no override.

`powercfg -a` reporting Hibernate as available means the hiberfile is **full**, not reduced:
"When a full hibernation file is used, the results state that hibernation is an available
option. When a reduced hibernation file is used, the results say hibernation is not
supported."
([System power states](https://learn.microsoft.com/en-us/windows/win32/power/system-power-states))

### Network

`Get-NetIPAddress -AddressFamily IPv4`:

| Interface | Address | Origin |
|---|---|---|
| Wi-Fi | `192.168.0.132` | Dhcp / Dhcp |
| Ethernet | `169.254.208.200` | WellKnown / Link (APIPA — **unplugged**) |
| Local Area Connection* 1 / 2, Bluetooth | `169.254.x.x` | link-local only |

**This laptop is on Wi-Fi only, with a DHCP address.** That single fact removes two of the
remote-reachability options outright; see §5.

Battery: `Win32_Battery` → `BatteryStatus = 2` (on AC), `EstimatedChargeRemaining = 100`.

Tunnel tooling already installed: `cloudflared`
(`C:\Program Files (x86)\cloudflared\cloudflared.exe`) and `ngrok`
(`%LOCALAPPDATA%\Microsoft\WinGet\Links\ngrok.exe`). `tailscale` is **not** installed. One
`ngrok` process (PID 15084) was running at probe time; no `cloudflared` process was.

This shell's `SessionId` is **1** — an interactive session, not session 0. That decides
which half of the DAM rule applies to every `claude` process Caesar starts (§3).

### Where probe and documentation disagree

| Claim | Documentation | This machine | Which is authoritative here |
|---|---|---|---|
| `powercfg /requests` privileges | The [powercfg reference](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options) marks `/systemsleepdiagnostics` and `/systempowerreport` as needing elevation, and says nothing about `/requests` | `powercfg -requests` → `This command requires administrator privileges and must be executed from an elevated command prompt.` | **Measured.** Step 1 of this ticket cannot be fully answered unelevated; the current power-request holders are unknown |
| Hybrid sleep | Hybrid sleep is "a combination of the sleep and hibernation states … a system uses a hibernation file with S1-S3" ([System power states](https://learn.microsoft.com/en-us/windows/win32/power/system-power-states)) | Scheme says `HYBRIDSLEEP = On` on both AC and DC, yet `powercfg -a` lists Hybrid Sleep as **not available** because S3 is not available | **Measured.** The scheme value is inert. Do not read "On" as protection |
| Lid-close action | `SUB_BUTTONS` documents a lid action | `powercfg -q SCHEME_CURRENT 4f971e89-...` returned only *Start menu power button* (`UIBUTTON_ACTION`, AC 0 / DC 0 = Sleep). The lid setting is hidden from `/q` on this SKU | **Neither.** The current lid action is *unknown from an unelevated read-only probe* and must be read from Settings or an elevated shell before §5's recommendation is acted on |

---

## 2. Modern standby vs S3 vs hibernate, from the documentation

| | S0 low-power idle (modern standby) | S3 sleep | S4 hibernate |
|---|---|---|---|
| Available on this laptop | **yes** | **no** | yes |
| Where process state lives | RAM, process still scheduled-but-suspended | RAM, CPU halted | written to hiberfile on disk, then RAM powered off |
| Processes | desktop apps **suspended** by the DAM; session-0 services throttled | all execution stops | all execution stops; restored byte-for-byte on resume |
| Network hardware | stays associated and connected ("Network Connected") | off, except wake-armed NIC | off, except wake-armed NIC |
| Wake-on-LAN | natively supported; **do not** enable legacy S3 WoL | supported | supported |
| Survives a full shutdown / reboot | no | no | no |

Sources: [System power states](https://learn.microsoft.com/en-us/windows/win32/power/system-power-states),
[Modern Standby wake sources](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby-wake-sources).

Resume from hibernate "puts the system in the exact state it was in when it was hibernated"
and "drivers and services are notified but aren't restarted. They're only restored to the
state they were in prior to hibernation"
([System power states](https://learn.microsoft.com/en-us/windows/win32/power/system-power-states)).
So hibernate is **not** a process killer either. What kills processes is S5 soft off, a
restart, or power loss — "During a full shutdown and boot, the entire user session is torn
down and restarted on the next boot."

The mechanism that actually touches Caesar is the **Desktop Activity Moderator**:

> The desktop activity moderator (DAM) is the Windows component that is used to pause all
> desktop applications and throttle the runtime of third-party system services. […] Windows
> prevents desktop applications from running during any part of modern standby after
> completing the DAM phase.
> — [Prepare software for modern standby](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/prepare-software-for-modern-standby)

and the split that decides which of the two happens to a given process:

> - If the process was created in session 0, DAM adds the process to a job object subject to
>   **throttling**
> - If the process was created in an interactive session (session 1 or higher), DAM adds the
>   process to a job object subject to **suspension**
>
> Processes that are subject to suspension have all their threads suspended (not allowed to
> run under any circumstances); app state (process memory) is maintained.
> — [Desktop Activity Moderator](https://learn.microsoft.com/en-us/windows/win32/w8cookbook/desktop-activity-moderator)

In the resiliency phase, "Session-0 services are throttled by the DAM to no more than one
second of activity every 30 seconds" and "As of 24H2, additional session-0 services may be
suspended, and session-0 service throttling may be stopped"
([Prepare software for modern standby](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/prepare-software-for-modern-standby)).

Entry is triggered by "the user pressing the power button, the user closing the lid, the
user selecting *Sleep* … the system idling out" (same page). **Closing the lid is a
first-class entry path**, not a special case.

---

## 3. What sleep does to each Caesar-relevant process

Every process below is created in this interactive session, `SessionId 1` (measured). So
every one of them lands in the **suspension** job object, not the throttled one.

| Process | On entry to modern standby | Still alive? |
|---|---|---|
| Interactive Claude Code (Caesar's own session) | all threads suspended | yes — memory intact, PID intact |
| Detached `claude -p` centurion (`spawn-ticket-agent.ps1:154`, `Start-Process … -WindowStyle Hidden`) | all threads suspended | yes — PID intact, result file still 0 bytes |
| `watch-runs.ps1` polling loop | all threads suspended; emits nothing for the whole standby window | yes |
| `ngrok` / `cloudflared` tunnel client (a desktop process) | all threads suspended → tunnel goes dead upstream even though the NIC is up | process yes, tunnel session no |
| DHCP client, other session-0 services | throttled to ~1 s per 30 s; may be suspended outright on 24H2+ | yes |

The failure is not the suspension itself — it is what the suspension does to an
**in-flight HTTPS request**. `claude -p` spends its life inside a long streaming response
from the API. Microsoft's own warning:

> Vendors who create software for, or dependent on, the web should consider how process
> suspension affects connection lifetimes and handshakes.
> — [Desktop Activity Moderator](https://learn.microsoft.com/en-us/windows/win32/w8cookbook/desktop-activity-moderator)

A socket that is not read for three hours is dropped by the far end, by the NAT table on the
router, or both. On resume the centurion's socket is a corpse; the process wakes into a
read that will never complete or an error it must handle.

**Phone reachability during standby.** Two documented blockers, and this laptop hits both:

- "Remote Access features are only available when using an Ethernet connection, regardless
  of whether the device is on AC or DC power" — Remote Desktop and File Sharing wake the SoC
  only over Ethernet ([Modern Standby wake sources](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby-wake-sources)).
  **Measured: this laptop's Ethernet is unplugged (APIPA); it is Wi-Fi only.**
- "When using a DC power source, the networking stacks may initiate disconnection from
  networks. This includes L2 disconnect for Ethernet, disconnection of Wi-Fi and Bluetooth"
  (same page). On battery, the Wi-Fi association itself is not guaranteed.

And even where the NIC does stay up, the thing a phone client talks to — a tunnel agent or
a local listener — is a desktop process, and desktop processes are exactly what the DAM
suspends. **Reachability from a phone during modern standby is not available on this laptop
as configured.**

---

## 4. What wake looks like, and how Caesar misreads it

### What resumes

On resume from modern standby (or from hibernate) the processes are all still there. Memory
is intact. PIDs are unchanged. The `ticket-N-*` worktrees are unchanged. Nothing has been
reaped.

What has silently died is anything that depended on **elapsed time or a live connection**:
the API stream, the OAuth token if it expired, the tunnel session, and any assumption in the
process that wall-clock time moved monotonically. The DAM page names this exactly:
"inconsistencies in uptime / runtime vs. wall clock time, inconsistencies in timer behavior".

Only a **shutdown, restart, or power loss** actually kills the centurion, and note the trap:
fast startup is on (`HiberbootEnabled = 1`), so a "shut down" is really an S4 of session 0
with **the user session torn down** — "Fast startup logs off user sessions" — so the
centurion dies, while the kernel state is preserved. A "restart" is a genuine S5. Both leave
a dead process and a live-looking worktree.

### What a killed centurion leaves behind

| Artefact | State after a kill (shutdown / restart / power loss) | State after a sleep/wake cycle |
|---|---|---|
| `.claude/worktrees/ticket-N-*` | present, locked, holding uncommitted work | present, unchanged |
| `.claude/caesar-runs/<run>.json` | present, **0 bytes** — redirection creates it at spawn, `claude -p` writes it once at the very end | present, 0 bytes |
| `.claude/caesar-runs/<run>.dispatch.json` | present, carrying `ProcessId` of a now-dead PID | present, carrying a PID that is **still alive** |
| transcript `.jsonl` under `%USERPROFILE%\.claude\projects\...` | present, mtime frozen at the moment of death | present, mtime frozen at the moment of sleep |
| GitHub ticket | still open, no resolution comment | still open |

### How Caesar's next startup reads it

`skill/SKILL.md:77` makes `git worktree list` an unconditional startup read, and
`skill/references/worktrees.md:32` gives the classification:

> | `ticket-N-*`, ticket N open | not an orphan — that is the live-centurion case |

**So both a dead centurion and a slept one classify as live.** SKILL.md's instruction on that
branch is "arm the watcher before anything else" — Caesar will wait on a corpse.

The disambiguation is supposed to come from `watch-runs.ps1`, and it half works:

- **After a real kill** (shutdown/restart), the run's PID is gone. The watcher's
  `skill/scripts/watch-runs.ps1:124` check — dead PID **and** empty result **and** no
  transcript — emits `DIED-AT-SPAWN`. But that check requires `Get-HeartbeatAge` to return
  `$null`, i.e. *no transcript at all*. A centurion killed **mid-run** has written a
  transcript, so it fails the third condition and falls through to the `QUIET` path
  (`watch-runs.ps1:159`) instead: "no transcript write for Nm — look, do not kill". Caesar
  is told to look, not that it is dead. That is the correct conservative answer, but it means
  **a mid-run kill is never reported as a death** — only as an ageing silence.
- **After a sleep/wake cycle**, the PID is *still alive*, so the death check at
  `watch-runs.ps1:124` cannot fire at all. The heartbeat age, being wall-clock, jumps by the
  full sleep duration, so `QUIET` fires immediately on wake with an age of ~180 minutes even
  though the centurion may be perfectly fine and about to resume. **Sleep manufactures a
  false alarm; a mid-run kill produces the same alarm.** Caesar cannot tell them apart from
  the watcher output alone.
- There is a further hazard the script already acknowledges in its own comment: "PID reuse
  can only make a dead run look alive, never the reverse". Across a **reboot**, PIDs are
  reassigned from scratch, so a stale `dispatch.json` PID can collide with an unrelated live
  process and the dead run reads as live forever.

The honest summary for the map: **after sleep, `git worktree list` plus the run directory
cannot distinguish a working centurion, a frozen one, and a dead one.** The only ground truth
is the GitHub artefact — which is exactly the fallback `skill/references/failure.md:110`
already prescribes ("check the GitHub artifact, not the disk"). Sleep does not create a new
failure mode; it widens the window in which the existing one applies, and it does so
silently, on mains, after three hours.

---

## 5. Keeping the machine awake and reachable

### Which options survive a closed lid

This is the deciding filter, because a closed lid is how the laptop is normally left.

Microsoft is unambiguous that the software route does not clear it:

> The **SetThreadExecutionState** function cannot be used to prevent the user from putting
> the computer to sleep. Applications should respect that the user expects a certain
> behavior when they close the lid on their laptop or press the power button.
> — [SetThreadExecutionState](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setthreadexecutionstate)

| Option | Cost | Survives closed lid? | Notes |
|---|---|---|---|
| Change **lid-close action** to *Do nothing* (AC only) | free; laptop runs hot and fans audibly with the lid shut | **Yes** — this is the only setting that does | The one lever that matters. Current value unknown from an unelevated probe (§1 conflict table) |
| Set `standby-timeout-ac` to `0` (never sleep on mains) | free; ~15–25 W continuous instead of ~1 W | No — lid close still sleeps | Necessary but not sufficient. Current value is 3 h |
| A keep-awake app (Caffeine, PowerToys Awake, `presentationsettings`) — all wrap `SetThreadExecutionState` / `PowerSetRequest` | free; must be running and remembered | **No** — explicitly cannot override a lid close | Also itself a desktop process, so it is suspended once standby is entered anyway |
| `powercfg /requestsoverride` for a named process | free; per-process, elevated to set | No — same ceiling as above | Would let `claude.exe` hold a System request. Still loses to the lid |
| Leave the lid **open** on a desk, screen off, on mains | free; needs the physical habit | N/A — sidesteps the question | With `standby-timeout-ac 0` this is the zero-config answer |
| External display attached, lid closed | needs a monitor at home | No — input suppression is skipped, but the lid *action* still fires | The doc's external-display note is about the display turning on, not about sleep |
| Enable wake timers + a scheduled task to wake it | free | N/A — wakes it *after* it slept, work already frozen | `RTCWAKE` is **Disable** on both AC and DC today, so this does nothing until changed |
| Wake-on-LAN from the phone | free, natively supported in modern standby | N/A | **Blocked on this laptop: Wi-Fi only.** Remote wake/access is Ethernet-only per the wake-sources doc |
| Tailscale / cloudflared tunnel for phone reachability | free tier; new dependency | No — the agent is a desktop process, suspended with everything else | Useful only *in combination with* the machine not sleeping |

### Address and tunnel across a sleep/wake cycle and a router reboot

- **Across sleep/wake.** The Wi-Fi address is DHCP (measured: `192.168.0.132`,
  `PrefixOrigin = Dhcp`). Modern standby keeps the networking subsystem connected on AC and
  keeps session-0 services like DHCP running — the wake-sources doc explicitly notes system
  processes "can remain active (e.g., DHCP) and use the network during Disconnected
  Standby". A short standby therefore normally keeps the same lease and the same address. On
  **battery** that guarantee is gone: "the networking stacks may initiate disconnection from
  networks … disconnection of Wi-Fi".
- **Across a router reboot.** Nothing holds. The lease is re-requested; whether the same
  address comes back is entirely the router's DHCP pool behaviour and is not a Windows
  property. Any scheme that hardcodes `192.168.0.132` is a landmine. Both installed tunnel
  agents (`cloudflared`, `ngrok`) are outbound-connecting and would re-dial, but only once
  their process is running and unsuspended — so after a router reboot *during* standby, the
  tunnel is down until something wakes the box, and on this laptop nothing can
  (`wake_armed` → `NONE`, `RTCWAKE` → Disable).

### Two configurations to put to Raj

Changing any of this is Raj's call and a later ticket. Both options below are AC-only
changes; neither touches battery behaviour, so an unplugged laptop in a bag still sleeps.

**Option A — "lid down, keeps working" (recommended).**
Set lid-close action on AC to *Do nothing*, and `standby-timeout-ac` to `0`.

- *Gives:* centurions run to completion while Raj is out, whatever the lid is doing. The
  three-hour cliff disappears. Caesar's `git worktree list` inference stays trustworthy.
- *Costs:* ~15–25 W continuous instead of ~1 W; the machine runs warm with the lid shut and
  needs to be on a hard surface, not a bed or a bag. Overnight sleep is lost unless Raj
  sleeps it deliberately — which he can, and which is safe, because a *deliberate* sleep is
  a known event rather than a silent one.
- *Gives up:* the automatic overnight power saving Raj said he was content with. He would
  have to sleep it by hand, or accept the draw.

**Option B — "lid open, never sleeps on mains" (minimum change).**
Set `standby-timeout-ac` to `0` only; leave the lid action alone and adopt the habit of
leaving the lid open when a centurion is out.

- *Gives:* the same protection for the actual scenario, with one setting changed instead of
  two, and no thermal question.
- *Costs:* it is a habit, not a guarantee. One absent-minded lid close and a centurion
  freezes mid-run with no signal until Caesar's next `QUIET`.
- *Gives up:* nothing configurationally; it trades a config guarantee for a human one.

Neither option makes the laptop reachable from a phone during standby. That is a separate
problem with a separate answer (wired Ethernet, or Tailscale plus a never-sleeping machine),
and it is not solvable by power settings alone on a Wi-Fi-only modern-standby laptop.

---

## Sources

All fetched during this run, 2026-08-15.

- [System power states](https://learn.microsoft.com/en-us/windows/win32/power/system-power-states) — S0/S1-S3/S4/S5, hybrid sleep, fast startup, hibernation file types, WoL
- [Prepare software for modern standby](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/prepare-software-for-modern-standby) — standby entry triggers, software phases, DAM phase, resiliency-phase throttling
- [Desktop Activity Moderator](https://learn.microsoft.com/en-us/windows/win32/w8cookbook/desktop-activity-moderator) — session-0 throttling vs session-1+ suspension, job objects, connection lifetimes
- [Modern Standby wake sources](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/modern-standby-wake-sources) — wake sources, Ethernet-only remote access, DC network disconnect, critical-battery hibernate
- [Powercfg command-line options](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/powercfg-command-line-options) — `/a`, `/q`, `/requests`, `/lastwake`, `/devicequery`, `/hibernate`
- [SetThreadExecutionState](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setthreadexecutionstate) — keep-awake flags and the lid-close ceiling
