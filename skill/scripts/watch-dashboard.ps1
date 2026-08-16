<#
.SYNOPSIS
  The regenerator loop (issue #183 step 8, ruled by docs\research\command-centre-refresh.md).
  Sweeps dashboard-data.ps1 every 60s and rewrites the command centre page.

.DESCRIPTION
  Single-instance via a named Mutex - a second copy exits with a message instead of
  racing the first on the output file. Each tick renders to a .tmp file and swaps it
  in with an atomic NTFS rename (MoveFileEx/MOVEFILE_REPLACE_EXISTING - see the note
  by Swap-In below for why this isn't [IO.File]::Replace), so a browser mid-reload
  never sees a half-written file.
  A failed sweep still rewrites the page: it keeps the last good JSON and re-renders
  it with a banner carrying the exception, the failure time and the consecutive-
  failure count, so a dead loop reads as "failing", never as "fresh".

  This ticket owns the renderer and this loop. Ticket #184 owns turning this into
  one command that stays running (install, process management, the wrapper).

.EXAMPLE
  powershell.exe -WindowStyle Hidden -File skill\scripts\watch-dashboard.ps1
#>
[CmdletBinding()]
param(
    [string]$OutFile = (Join-Path $PSScriptRoot 'dashboard-output\index.html'),
    [int]$IntervalSeconds = 60
)

$ErrorActionPreference = 'Stop'
$dataScript = Join-Path $PSScriptRoot 'dashboard-data.ps1'
$renderScript = Join-Path $PSScriptRoot 'render-dashboard.ps1'

$OutFile = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutFile))
$tmpFile = "$OutFile.tmp"

$outDir = Split-Path -Parent $OutFile
if (-not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

# ponytail: [IO.File]::Replace, the atomic swap the refresh doc (docs\research\
# command-centre-refresh.md section 5) calls for, throws "the path is not of a
# legal form" on every call on this exact machine/PS build (5.1.26100.9168) - a
# minimal two-file repro in a fresh temp dir reproduces it with no path involved
# from this script. MoveFileEx with MOVEFILE_REPLACE_EXISTING is the same NTFS
# atomic rename File.Replace wraps, called directly via P/Invoke instead.
Add-Type -Namespace Caesar -Name NativeIO -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
public static extern bool MoveFileEx(string lpExistingFileName, string lpNewFileName, uint dwFlags);
'@
$MOVEFILE_REPLACE_EXISTING = 0x1
$MOVEFILE_WRITE_THROUGH = 0x8

# single instance: a second copy started after a reboot would double the GraphQL
# spend and race the first on the swap (refresh doc, failure mode 6).
$mutex = New-Object System.Threading.Mutex($false, 'Global\CaesarDashboardLoop')
if (-not $mutex.WaitOne(0)) {
    Write-Host "Another dashboard loop already holds Global\CaesarDashboardLoop. Exiting."
    exit 1
}

function Swap-In {
    $ok = [Caesar.NativeIO]::MoveFileEx($tmpFile, $OutFile, $MOVEFILE_REPLACE_EXISTING -bor $MOVEFILE_WRITE_THROUGH)
    if (-not $ok) {
        $code = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "MoveFileEx($tmpFile -> $OutFile) failed, Win32 error $code"
    }
}

try {
    $lastGoodJson = $null
    $consecutiveFailures = 0

    Write-Host "Caesar command centre loop started. Writing to $OutFile every ${IntervalSeconds}s. Ctrl+C to stop."

    while ($true) {
        try {
            $json = & $dataScript
            & $renderScript -Json $json -OutFile $tmpFile
            Swap-In
            $lastGoodJson = $json
            $consecutiveFailures = 0
        } catch {
            $consecutiveFailures++
            $failTime = Get-Date
            $msg = $_.Exception.Message
            Write-Host "[$failTime] sweep failed ($consecutiveFailures consecutive): $msg"
            if ($lastGoodJson) {
                try {
                    & $renderScript -Json $lastGoodJson -OutFile $tmpFile `
                        -ErrorMessage $msg -ErrorTime $failTime.ToString('yyyy-MM-dd HH:mm:ss') -FailureCount $consecutiveFailures
                    Swap-In
                } catch {
                    Write-Host "also failed to render the failure banner: $($_.Exception.Message)"
                }
            } else {
                # no good sweep yet this run - write a minimal banner-only page rather
                # than leaving no file at all for the first tick.
                $placeholder = "<!doctype html><html><body style='background:#101010;color:#C87941;" +
                    "font-family:monospace;padding:40px'>sweep failed at $failTime " +
                    "($consecutiveFailures consecutive): $([System.Net.WebUtility]::HtmlEncode($msg))</body></html>"
                [IO.File]::WriteAllText($tmpFile, $placeholder)
                Swap-In
            }
        }
        Start-Sleep -Seconds $IntervalSeconds
    }
} finally {
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
