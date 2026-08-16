<#
.SYNOPSIS
  The one command that opens the Caesar command centre (issue #184). Starts the
  regenerator loop if it is not already running, then opens the page in the browser.

.DESCRIPTION
  A thin wrapper around watch-dashboard.ps1 (#183). It owns three things the loop
  does not: where the page lives, how a second invocation attaches instead of
  starting a second writer, and how the loop stops.

  WHERE THE PAGE LIVES
  %LOCALAPPDATA%\Caesar\command-centre\index.html - by default
  C:\Users\<user>\AppData\Local\Caesar\command-centre\index.html.
  The loop's own default is dashboard-output\index.html beside the script, which is
  inside the repo working tree: a git clean deletes the page out from under an open
  browser tab, and every worktree writes a different absolute path so the tab's URL
  changes per checkout. %LOCALAPPDATA% is the Windows-sanctioned per-user
  machine-local state directory: one fixed absolute path, unaffected by git, and -
  unlike %APPDATA% - never roamed and never on the H:\ / C:\Numen Google Drive
  letter, which corrupts file handles. So the browser tab survives a restart, a
  reinstall and a branch switch.

  LIVENESS
  The loop's single-instance lock, the named mutex Global\CaesarDashboardLoop, is
  the liveness test - it is probed cross-process with Mutex::OpenExisting, which
  throws WaitHandleCannotBeOpenedException when no loop holds it. No PID file, no
  second source of truth to go stale. The kill target is found separately, by
  command line, because a mutex names no process.

  AUTOSTART: RULED NO - the command centre does not start with Windows.
  The refresh ruling (docs\research\command-centre-refresh.md section 4, loser c1)
  already weighed a Scheduled Task and named it the upgrade path, not the shipping
  shape, and nothing found here changes that. Two reasons it stays manual:
  a logon-triggered loop spends the GraphQL budget - 1320 points/hour at the live
  6-map set - on every day Raj never opens the board, and the budget is the binding
  constraint the 60s interval was derived from; and a board nobody is looking at is
  exactly where the refresh doc's worst failure mode (a stale page that reads as
  healthy) does its damage unobserved. Starting it is one word, and that word is
  said at the moment Raj actually wants to look.
  What would change the call: Raj opening the board most days, or forgetting to
  start it and reading stale numbers. Then register a logon-triggered task -
  Register-ScheduledTask -TaskName 'Caesar Command Centre' -Trigger (New-ScheduledTaskTrigger -AtLogOn)
    -Action (New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -File "<this script>" start')
    -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable)
  - and nothing else in this file moves.

.EXAMPLE
  caesar-centre
.EXAMPLE
  caesar-centre stop
.EXAMPLE
  powershell -File skill\scripts\command-centre.ps1 status
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('start', 'stop', 'status')]
    [string]$Verb = 'start',

    [string]$OutFile = (Join-Path $env:LOCALAPPDATA 'Caesar\command-centre\index.html'),

    [int]$IntervalSeconds = 60,

    # How long a cold start waits for the loop's first sweep to produce a page before
    # opening the browser. A whole sweep measures 9-14s at 6 maps (refresh doc section 1);
    # this is the pessimistic ceiling, not the expectation.
    [int]$FirstPageTimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'

$MutexName = 'Global\CaesarDashboardLoop'
$loopScript = Join-Path $PSScriptRoot 'watch-dashboard.ps1'
if (-not (Test-Path -LiteralPath $loopScript)) { throw "No watch-dashboard.ps1 beside this script at $loopScript" }

$OutFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine((Get-Location).Path, $OutFile))

function Test-LoopAlive {
    try {
        $m = [System.Threading.Mutex]::OpenExisting($MutexName)
        $m.Dispose()
        return $true
    } catch [System.Threading.WaitHandleCannotBeOpenedException] {
        # the only "no loop" answer. Anything else - an access denial on a mutex that
        # does exist - means something holds it, so it is not ours to start over.
        return $false
    }
}

# The mutex proves a loop is alive but names no process, so the kill target is found by
# command line. Our own process does not match: it carries command-centre.ps1.
function Get-LoopProcess {
    @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -like '*watch-dashboard.ps1*' })
}

function Show-Status {
    $alive = Test-LoopAlive
    # @() again at the call site: a single-element array returned from a function is
    # unrolled to the bare object, and .Count on a CimInstance is empty, not 1.
    $procs = @(Get-LoopProcess)
    Write-Host "Loop holding ${MutexName}: $alive"
    Write-Host "watch-dashboard.ps1 processes: $($procs.Count)$(if ($procs) { ' (pid ' + (($procs | ForEach-Object { $_.ProcessId }) -join ', ') + ')' })"
    Write-Host "Page: $OutFile$(if (Test-Path -LiteralPath $OutFile) { ' (generated ' + (Get-Item -LiteralPath $OutFile).LastWriteTime + ')' } else { ' (not generated yet)' })"
}

switch ($Verb) {

    'status' { Show-Status }

    'stop' {
        $procs = @(Get-LoopProcess)
        if (-not $procs) {
            Write-Host "No command centre loop running."
        } else {
            foreach ($p in $procs) {
                Stop-Process -Id $p.ProcessId -Force
                Write-Host "Stopped loop process $($p.ProcessId)."
            }
            # Killing the process is what releases the mutex and the .tmp handle - the OS
            # closes both handles at exit - so the mutex going unopenable is the receipt
            # that the stop was clean, not just that the pid is gone.
            $deadline = (Get-Date).AddSeconds(10)
            while ((Test-LoopAlive) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 200 }
        }
        if (Test-LoopAlive) { throw "$MutexName is still held after the stop - something else owns it." }
        Write-Host "$MutexName released. No loop running."
    }

    'start' {
        if (Test-LoopAlive) {
            Write-Host "Command centre loop already running (pid $((Get-LoopProcess | ForEach-Object { $_.ProcessId }) -join ', ')). Attaching."
        } else {
            $outDir = Split-Path -Parent $OutFile
            if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

            # Quoted explicitly: these are argv, and the repo's PowerShell rule is that a
            # path with a space is shredded on the way through if it is not.
            $loopArgs = @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
                '-File', "`"$loopScript`"",
                '-OutFile', "`"$OutFile`"",
                '-IntervalSeconds', $IntervalSeconds
            )
            Start-Process -FilePath 'powershell.exe' -ArgumentList $loopArgs -WindowStyle Hidden
            Write-Host "Started the command centre loop. Writing $OutFile every ${IntervalSeconds}s."

            # Block until the child actually holds the mutex. It compiles the MoveFileEx
            # P/Invoke with Add-Type before it locks, so for a few seconds after
            # Start-Process the liveness probe still answers "no loop" - and a second
            # start inside that window spawns a process that immediately exits 1.
            $deadline = (Get-Date).AddSeconds(30)
            while (-not (Test-LoopAlive) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 250 }
            if (-not (Test-LoopAlive)) { throw "The loop process was started but never took $MutexName. Run it in the foreground to see why: powershell -File `"$loopScript`" -OutFile `"$OutFile`"" }

            if (-not (Test-Path -LiteralPath $OutFile)) {
                Write-Host "Waiting for the first sweep (up to ${FirstPageTimeoutSeconds}s)..."
                $deadline = (Get-Date).AddSeconds($FirstPageTimeoutSeconds)
                while (-not (Test-Path -LiteralPath $OutFile) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2 }
            }
        }

        if (-not (Test-Path -LiteralPath $OutFile)) {
            throw "The loop is running but no page appeared at $OutFile. Run '$($MyInvocation.MyCommand.Name) status', then start the loop in the foreground to see its output: powershell -File `"$loopScript`" -OutFile `"$OutFile`""
        }
        Start-Process -FilePath $OutFile
        Write-Host "Opened $OutFile"
    }
}
