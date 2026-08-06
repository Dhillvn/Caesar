<#
.SYNOPSIS
  Frozen watcher. Emits one line per centurion event - landed, errored, died at spawn,
  gone quiet - so Caesar is woken by the harness instead of waiting to be asked.

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
    [switch]$Once,
    # -Once -Rearm reproduces exactly what the persistent watcher does when it starts:
    # one silent backfill pass, then one reporting pass. Only the self-test uses it,
    # to prove a re-arm replays nothing.
    [switch]$Rearm
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

# Refuse a -RepoPath that does not exist, loudly and at once. Invoke-Pass opens with
# `if (-not (Test-Path $logDir)) { return }`, so before this check a watcher aimed at a
# path that can never exist polled in silence and looked perfectly healthy - which is
# exactly how one ran for 75 minutes across two real landings and reported neither.
# The realistic cause is quoting, not typos: the Monitor tool runs its command through
# bash, and bash strips the backslashes from an unquoted Windows path, turning
# C:\Users\rajdh\Projects\caesar into C:UsersrajdhProjectscaesar.
# An existing repo with no dispatches yet still has no run directory, and that is a
# healthy silence - so this checks the repo path, never the run directory.
if ($RepoPath -and -not (Test-Path -LiteralPath $RepoPath -PathType Container)) {
    Emit "WATCHER-BAD-REPOPATH $RepoPath -- no such directory, so no landing can ever be seen. Quote the path in the Monitor command; bash strips backslashes from an unquoted Windows path."
    exit 1
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

        # Dead PID + empty result + no transcript is not "quiet", it is finished and
        # failed, and it is knowable on the next poll instead of at the 30m timer (#94).
        # This sits ABOVE the -Silent bail on purpose: a re-armed watcher must adopt a
        # dead run as already-reported exactly as it adopts a landing, otherwise the
        # same corpse re-alarms every RecheckMinutes forever (#94 defect B).
        # PID reuse can only make a dead run look alive, never the reverse, and that
        # falls back to the old NO-TRANSCRIPT path - so no start-time check.
        $dispatchFile = $f.FullName -replace '\.json$', '.dispatch.json'
        if (Test-Path -LiteralPath $dispatchFile) {
            $d = $null
            try { $d = [IO.File]::ReadAllText($dispatchFile) | ConvertFrom-Json } catch { $d = $null }
            if ($d -and $d.ProcessId -and
                -not (Get-Process -Id $d.ProcessId -ErrorAction SilentlyContinue) -and
                $null -eq (Get-HeartbeatAge $name)) {
                $reported[$f.Name] = 'done'
                if ($Silent) { continue }
                # One event = one notification line, so the tail is the last non-empty
                # stderr line with its whitespace collapsed, never the raw block.
                $tail = 'stderr empty'
                if ($d.StderrFile -and (Test-Path -LiteralPath $d.StderrFile)) {
                    $last = @(Get-Content -LiteralPath $d.StderrFile -Tail 40 -ErrorAction SilentlyContinue) |
                        Where-Object { $_.Trim() } | Select-Object -Last 1
                    if ($last) { $tail = 'stderr: ' + ($last.Trim() -replace '\s+', ' ') }
                }
                if ($tail.Length -gt 200) { $tail = $tail.Substring(0, 200) + '...' }
                Emit "DIED-AT-SPAWN $name  pid $($d.ProcessId) is gone, result file empty, session never wrote a turn -- $tail"
                continue
            }
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
    # Run a pass out-of-process with stdout REDIRECTED, which is the shape the Monitor
    # tool uses and the only shape in which the buffering defect is visible. Every
    # argument is quoted: Start-Process joins ArgumentList on spaces with no quoting of
    # its own, so an unquoted temp path with a space silently splits into two arguments.
    function Invoke-SelfTestPass([string[]]$Arguments) {
        $o = [System.IO.Path]::GetTempFileName()
        try {
            $all = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath) + $Arguments
            $line = ($all | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ' '
            Start-Process -FilePath 'powershell' -NoNewWindow -Wait `
                -ArgumentList $line -RedirectStandardOutput $o | Out-Null
            @(Get-Content -LiteralPath $o | Where-Object { $_ -ne '' })
        } finally { Remove-Item -LiteralPath $o -Force -ErrorAction SilentlyContinue }
    }

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

        # A PID nothing owns. Probed rather than assumed - a hardcoded number is a test
        # that passes for the wrong reason the day something happens to hold it.
        $deadPid = 1
        do { $deadPid = Get-Random -Minimum 100000 -Maximum 999999 }
        while (Get-Process -Id $deadPid -ErrorAction SilentlyContinue)

        # Sidecars go in BOM-less, the same way spawn-ticket-agent.ps1 writes them:
        # PS 5.1's `Set-Content -Encoding UTF8` prepends EF BB BF and ConvertFrom-Json
        # over [IO.File]::ReadAllText then dies on it.
        function Write-Dispatch($Path, $Object) {
            [System.IO.File]::WriteAllText($Path, ($Object | ConvertTo-Json),
                (New-Object System.Text.UTF8Encoding $false))
        }

        # Defect A: died in the first second. Deliberately NOT aged past the quiet timer -
        # if this only fires because the clock ran, the fix did nothing.
        $died = Join-Path $runs 'ticket-5-eee-20260101-000000.json'
        New-Item -ItemType File -Path $died | Out-Null
        $diedErr = Join-Path $runs 'ticket-5-eee-20260101-000000.err'
        Set-Content -LiteralPath $diedErr -Value @('', 'fatal: worktree creation refused')
        Write-Dispatch (Join-Path $runs 'ticket-5-eee-20260101-000000.dispatch.json') @{
            ProcessId = $deadPid; StderrFile = $diedErr }

        # A live PID with an empty result is still running, whatever the clock says. It
        # must keep the old NO-TRANSCRIPT wording and never be called dead.
        $live = Join-Path $runs 'ticket-6-fff-20260101-000000.json'
        New-Item -ItemType File -Path $live | Out-Null
        (Get-Item $live).CreationTime = (Get-Date).AddMinutes(-($QuietMinutes + 10))
        Write-Dispatch (Join-Path $runs 'ticket-6-fff-20260101-000000.dispatch.json') @{
            ProcessId = $PID; StderrFile = 'nonexistent.err' }

        # Out-of-process, with stdout redirected - the same shape the Monitor tool uses.
        # Emit writes to the console writer, not the pipeline, so an in-process `&` call
        # captures nothing; and testing in-process is what let the buffering defect ship.
        $out = @(Invoke-SelfTestPass @('-RepoPath', $tmp, '-Once'))
        $want = @(
            @{ Pattern = '^LANDED ticket-1-aaa\s+GIST: a judgeable sentence\.$'; Name = 'landed with gist' }
            @{ Pattern = '^ERRORED ticket-2-bbb\s+terminal_reason=budget'; Name = 'errored' }
            @{ Pattern = '^LANDED-NO-GIST ticket-3-ccc'; Name = 'clean exit, no GIST' }
            @{ Pattern = '^NO-TRANSCRIPT ticket-4-ddd'; Name = 'never started, no dispatch sidecar' }
            @{ Pattern = '^DIED-AT-SPAWN ticket-5-eee.+stderr: fatal: worktree creation refused$'; Name = 'died at spawn, reported off the clock with its stderr tail' }
            @{ Pattern = '^NO-TRANSCRIPT ticket-6-fff'; Name = 'live pid past the timer is quiet, not dead' }
        )
        $fail = 0
        foreach ($w in $want) {
            if ($out -match $w.Pattern) { Write-Output "  ok   $($w.Name)" }
            else { Write-Output "  FAIL $($w.Name)"; $fail++ }
        }
        if ($out.Count -ne $want.Count) { Write-Output "  FAIL expected $($want.Count) lines, got $($out.Count)"; $fail++ }

        # Defect B: a re-armed watcher backfills the corpse silently, same as a landing.
        # The two timer-driven alarms are not backfilled and must still speak - they
        # describe runs that are still open, and suppressing those is the missed landing.
        $rearmOut = @(Invoke-SelfTestPass @('-RepoPath', $tmp, '-Once', '-Rearm'))
        $rearmWant = @('^NO-TRANSCRIPT ticket-4-ddd', '^NO-TRANSCRIPT ticket-6-fff')
        if ($rearmOut -match '^DIED-AT-SPAWN') { Write-Output '  FAIL re-arm re-reports a dead run'; $fail++ }
        elseif ($rearmOut -match '^LANDED|^ERRORED') { Write-Output '  FAIL re-arm re-reports a landing'; $fail++ }
        # -not (array -match p), never (array -notmatch p): over an array -notmatch is a
        # filter, so it returns every OTHER line and reads as a failure on a clean pass.
        elseif ($rearmOut.Count -ne 2 -or ($rearmWant | Where-Object { -not ($rearmOut -match $_) })) {
            Write-Output "  FAIL re-arm should say only the two open runs, said: $($rearmOut -join ' | ')"; $fail++
        }
        else { Write-Output '  ok   re-arm replays nothing terminal, only the runs still open' }

        # Defect C: a watcher aimed at a path that cannot exist must refuse, not idle.
        # The mangled path is the real one bash produced from an unquoted argument.
        $bad = @(Invoke-SelfTestPass @('-RepoPath', 'C:UsersrajdhProjectscaesar', '-Once'))
        if ($bad -match '^WATCHER-BAD-REPOPATH') { Write-Output '  ok   a nonexistent RepoPath is refused out loud, not polled in silence' }
        else { Write-Output "  FAIL bad RepoPath said nothing, it would poll forever: $($bad -join ' | ')"; $fail++ }

        # Defect D: a LIVE watcher's line must reach a redirected stdout before it exits.
        # A one-shot pass flushes on exit whatever writer it used, so -Once cannot show
        # this - persistence is the discriminator, not redirection. Poll fast so the
        # check costs seconds rather than a poll interval.
        $liveRuns = New-Item -ItemType Directory -Force -Path (Join-Path $tmp 'live\.claude\caesar-runs')
        $liveOut = Join-Path $tmp 'live-stdout.txt'
        New-Item -ItemType File -Path $liveOut -Force | Out-Null
        $args2 = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath,
                   '-RepoPath', (Join-Path $tmp 'live'), '-PollSeconds', '1')
        $line2 = ($args2 | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ' '
        $watcher = Start-Process -FilePath 'powershell' -NoNewWindow -PassThru `
            -ArgumentList $line2 -RedirectStandardOutput $liveOut
        try {
            Start-Sleep -Seconds 3   # let the silent backfill pass finish first
            '{"is_error":false,"result":"GIST: a live landing."}' |
                Set-Content -LiteralPath (Join-Path $liveRuns 'ticket-7-ggg-20260101-000000.json')
            $seen = $false
            foreach ($i in 1..20) {
                Start-Sleep -Seconds 1
                if ((Get-Content -LiteralPath $liveOut -ErrorAction SilentlyContinue) -match '^LANDED ticket-7-ggg') {
                    $seen = $true; break
                }
            }
            if ($seen) { Write-Output '  ok   a live watcher''s landing reaches redirected stdout without exiting' }
            else { Write-Output '  FAIL live watcher emitted nothing - Emit is buffering again'; $fail++ }
        } finally {
            Stop-Process -Id $watcher.Id -Force -ErrorAction SilentlyContinue
        }

        Write-Output ''
        Write-Output $(if ($fail) { "SELFTEST FAILED ($fail)" } else { 'SELFTEST PASSED' })
        if ($fail) { exit 1 }
    } finally { Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
    return
}

# -Once skips the backfill: a one-shot diagnostic pass is asked to report what is there,
# not to suppress it.
if ($Once) {
    if ($Rearm) { Invoke-Pass $true }
    Invoke-Pass $false
    return
}

Invoke-Pass $true
while ($true) {
    Invoke-Pass $false
    Start-Sleep -Seconds $PollSeconds
}
