<#
.SYNOPSIS
  Frozen watcher. Emits one line per centurion event - landed, errored, gone quiet -
  so Caesar is woken by the harness instead of waiting to be asked.

.DESCRIPTION
  Frozen for the reason the spawn and the sweep are: correctness IS the filter set.
  A watcher that greps only for the success marker is silent through a wedge, a
  crash and a budget kill, and silence is indistinguishable from "still working" -
  which is the exact failure this script exists to end.

  spawn-ticket-agent.ps1 detaches (Start-Process, no wait), so a landed centurion
  reaches nothing: no SubagentStop, no background-task completion, no entry in
  `claude agents`. Caesar's only wake was Raj typing, and nothing obliged a poll on
  that turn. Hence "Harvest. As centurions land" described an event Caesar could
  not observe.

  Drive it from the Monitor tool, persistent, one per session:
    Monitor(command: 'powershell -NoProfile -ExecutionPolicy Bypass -File
            <this> -RepoPath <repo>', persistent: true)
  Each stdout line becomes one notification, and a notification lands even while
  Caesar sits idle mid-grill. SKILL.md decides what he says about it.

  Emits no verdict, the same as inspect-run.ps1. LANDED is not "accept the gist"
  and QUIET is not "kill it" - SKILL.md's failure table makes both calls.

.EXAMPLE
  .\watch-runs.ps1 -RepoPath C:\Users\rajdh\Projects\caesar
  .\watch-runs.ps1 -RepoPath . -Once      # one pass, for the smoke test
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Watch')][string]$RepoPath,
    [Parameter(Mandatory = $true, ParameterSetName = 'SelfTest')][switch]$SelfTest,
    [int]$QuietMinutes = 30,
    [int]$RecheckMinutes = 15,
    [int]$PollSeconds = 20,
    [switch]$Once
)

$ErrorActionPreference = 'Stop'

$logDir = if ($RepoPath) { Join-Path $RepoPath '.claude\caesar-runs' }   # unset under -SelfTest
$reported = @{}

function Emit([string]$Line) {
    # Voice off: these lines are judged, and a grid is scanned (SKILL.md, "Where the
    # voice is on"). Flush explicitly - a buffered line is a notification that never
    # arrives, which is the bug this script is fixing.
    Write-Output $Line
    [Console]::Out.Flush()
}

# The only progress signal a running centurion has: `claude -p` writes its result JSON
# once, at the very end, but the transcript .jsonl mtime advances while it works.
# Derivation lifted from inspect-run.ps1 so both read the same heartbeat.
function Get-HeartbeatAge([string]$WorktreeName) {
    $wt = Join-Path $RepoPath ".claude\worktrees\$WorktreeName"
    $dir = Join-Path "$env:USERPROFILE\.claude\projects" ($wt -replace '[:\\/.]', '-')
    if (-not (Test-Path $dir)) { return $null }
    $t = Get-ChildItem $dir -Filter *.jsonl -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime | Select-Object -Last 1
    if (-not $t) { return $null }
    ((Get-Date) - $t.LastWriteTime).TotalMinutes
}

function Invoke-Pass([bool]$Silent) {
    if (-not (Test-Path $logDir)) { return }
    # *.dispatch.json is the tier/model/effort sidecar written at spawn time (#52). It is
    # not a run result and never carries a GIST, so without this exclusion every single
    # dispatch emits a phantom LANDED-NO-GIST the moment it starts.
    $runFiles = Get-ChildItem $logDir -Filter *.json -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.dispatch.json' }
    foreach ($f in $runFiles) {
        if ($reported[$f.Name] -eq 'done') { continue }
        $name = $f.BaseName -replace '-\d{8}-\d{6}$', ''

        # 0 bytes is the normal running state: redirection creates the file at spawn.
        if ($f.Length -gt 0) {
            $r = $null
            try { $r = Get-Content -Raw -LiteralPath $f.FullName | ConvertFrom-Json } catch { continue }
            $reported[$f.Name] = 'done'
            if ($Silent) { continue }   # backfill, see below
            if ($r.is_error) {
                Emit "ERRORED $name  terminal_reason=$($r.terminal_reason) cost=$([math]::Round($r.total_cost_usd,2)) -- inspect-run.ps1 -ResultFile '$($f.FullName)'"
                continue
            }
            $gist = @($r.result -split "`r?`n") | Where-Object { $_ -match '^\s*GIST:\s' } | Select-Object -First 1
            if ($gist) { Emit "LANDED $name  $($gist.Trim())" }
            else { Emit "LANDED-NO-GIST $name  exit clean but printed no GIST line -- verify the ticket before appending anything" }
            continue
        }

        if ($Silent) { continue }

        # Still running. Quiet is not dead and not a flag - SKILL.md: at 30 minutes you
        # look, you do not kill. Re-emit each RecheckMinutes so a long wedge cannot go
        # quiet again after one notice.
        $age = Get-HeartbeatAge $name
        if ($null -eq $age) {
            $age = ((Get-Date) - $f.CreationTime).TotalMinutes
            if ($age -gt $QuietMinutes) {
                $bucket = [math]::Floor($age / $RecheckMinutes)
                if ($reported[$f.Name] -ne "nostart:$bucket") {
                    $reported[$f.Name] = "nostart:$bucket"
                    Emit "NO-TRANSCRIPT $name  $([int]$age)m since spawn and the session never wrote a turn -- it may never have started"
                }
            }
            continue
        }
        if ($age -gt $QuietMinutes) {
            $bucket = [math]::Floor($age / $RecheckMinutes)
            if ($reported[$f.Name] -ne "quiet:$bucket") {
                $reported[$f.Name] = "quiet:$bucket"
                Emit "QUIET $name  no transcript write for $([int]$age)m -- look, do not kill: inspect-run.ps1 -ResultFile '$($f.FullName)'"
            }
        }
    }
}

# Backfill: mark everything already finished as reported, silently. Without this a
# watcher armed (or re-armed) mid-session replays every centurion the map ever ran as
# fresh landings, and a false landing is worse than a missed one - Caesar would append
# a gist to the map twice.
# One runnable check on the classifier, which is the whole point of the file. Fakes the
# three states against a temp dir and asserts each is named. It cannot cover the wake
# itself - that is the Monitor tool's, and is proved by dogfooding.
if ($SelfTest) {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "watch-runs-selftest-$(Get-Random)"
    $runs = New-Item -ItemType Directory -Force -Path (Join-Path $tmp '.claude\caesar-runs')
    try {
        '{"is_error":false,"result":"worked\nGIST: a judgeable sentence."}' |
            Set-Content -LiteralPath (Join-Path $runs 'ticket-1-aaa-20260101-000000.json')
        '{"is_error":true,"terminal_reason":"budget","total_cost_usd":2.0}' |
            Set-Content -LiteralPath (Join-Path $runs 'ticket-2-bbb-20260101-000000.json')
        '{"is_error":false,"result":"talked, did nothing"}' |
            Set-Content -LiteralPath (Join-Path $runs 'ticket-3-ccc-20260101-000000.json')
        $never = Join-Path $runs 'ticket-4-ddd-20260101-000000.json'
        New-Item -ItemType File -Path $never | Out-Null
        (Get-Item $never).CreationTime = (Get-Date).AddMinutes(-($QuietMinutes + 10))

        $out = & $PSCommandPath -RepoPath $tmp -Once
        $want = @(
            @{ Pattern = '^LANDED ticket-1-aaa\s+GIST: a judgeable sentence\.$'; Name = 'landed with gist' }
            @{ Pattern = '^ERRORED ticket-2-bbb\s+terminal_reason=budget'; Name = 'errored' }
            @{ Pattern = '^LANDED-NO-GIST ticket-3-ccc'; Name = 'clean exit, no GIST' }
            @{ Pattern = '^NO-TRANSCRIPT ticket-4-ddd'; Name = 'never started' }
        )
        $fail = 0
        foreach ($w in $want) {
            if ($out -match $w.Pattern) { Write-Output "  ok   $($w.Name)" }
            else { Write-Output "  FAIL $($w.Name)"; $fail++ }
        }
        if ($out.Count -ne $want.Count) { Write-Output "  FAIL expected $($want.Count) lines, got $($out.Count)"; $fail++ }
        Write-Output ''
        Write-Output $(if ($fail) { "SELFTEST FAILED ($fail)" } else { 'SELFTEST PASSED' })
        if ($fail) { exit 1 }
    } finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
    return
}

# -Once skips the backfill: a one-shot diagnostic pass is asked to report what is there,
# not to suppress it.
if ($Once) { Invoke-Pass $false; return }

Invoke-Pass $true
while ($true) {
    Invoke-Pass $false
    Start-Sleep -Seconds $PollSeconds
}
