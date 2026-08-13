<#
.SYNOPSIS
  Render every Caesar run directory on this machine into the private gist, one
  markdown file per repo (issue #160).

.DESCRIPTION
  Discovers every `<ProjectsRoot>\*\.claude\caesar-runs` directory - presence of the
  directory is the only test, so a repo added later needs no edit here. Groups the
  files in each by stem (`<name>-<yyyyMMdd>-<HHmmss>`), classifies each stem RUNNING /
  LANDED / LANDED (no GIST) / ERRORED from its result JSON (mirrors watch-runs.ps1's
  classifier), and writes one `<repo>.md` per directory to the gist whose id is read
  from `caesar\.claude\caesar-runs\.gist-id` (falls back to the known id if that file
  is missing).

  Every timestamp in the render comes from the run data itself, never the clock, so
  two consecutive runs over unchanged directories produce byte-identical gist content
  (#160's idempotence requirement - a clock-derived "Updated" header cannot pass it).

.EXAMPLE
  .\publish-runs.ps1
#>
[CmdletBinding()]
param(
    [string]$ProjectsRoot = (Join-Path $env:USERPROFILE 'Projects'),
    [string]$GistId,
    [int]$Cap = 40
)

$ErrorActionPreference = 'Stop'

if (-not $GistId) {
    $idFile = Join-Path $ProjectsRoot 'caesar\.claude\caesar-runs\.gist-id'
    $GistId = if (Test-Path -LiteralPath $idFile) { ([IO.File]::ReadAllText($idFile)).Trim() }
              else { '12fdf235c41ddc3f74a4847bdb89dc8c' }
}

function Get-StderrTail([string]$ErrFile) {
    if (-not $ErrFile -or -not (Test-Path -LiteralPath $ErrFile)) { return 'stderr empty' }
    $last = @(Get-Content -LiteralPath $ErrFile -Tail 40 -ErrorAction SilentlyContinue) |
        Where-Object { $_.Trim() } | Select-Object -Last 1
    if (-not $last) { return 'stderr empty' }
    $tail = 'stderr: ' + ($last.Trim() -replace '\s+', ' ')
    if ($tail.Length -gt 200) { $tail = $tail.Substring(0, 200) + '...' }
    $tail
}

function Get-IssueLink([string]$PromptFile) {
    if (-not $PromptFile -or -not (Test-Path -LiteralPath $PromptFile)) { return $null }
    # A prompt file for a run still in flight is open for write by the centurion
    # process (redirected stdin) - share Read/Write so a live run does not blow up
    # the whole render, and skip the link rather than fail the pass.
    try {
        $stream = [IO.File]::Open($PromptFile, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            $reader = New-Object IO.StreamReader($stream)
            $text = $reader.ReadToEnd()
        } finally { $stream.Dispose() }
    } catch { return $null }
    $m = [regex]::Match($text, 'https://github\.com/[^/\s]+/[^/\s]+/issues/(\d+)')
    if (-not $m.Success) { return $null }
    "[#$($m.Groups[1].Value)]($($m.Value))"
}

# One run block, as a list of content lines - blocks join on "`n", the render joins
# blocks on "`n`n" so each pair ends up separated by exactly one blank line, matching
# the hand-written gist's shape.
function Format-Run($RunDir, $Stem) {
    $name = $Stem -replace '-\d{8}-\d{6}$', ''
    $tsMatch = [regex]::Match($Stem, '(\d{8})-(\d{6})$')
    $ts = [datetime]::ParseExact($tsMatch.Value, 'yyyyMMdd-HHmmss', $null)
    $when = $ts.ToString('ddd dd MMM HH:mm')

    $jsonFile = Join-Path $RunDir "$Stem.json"
    $dispatchFile = Join-Path $RunDir "$Stem.dispatch.json"
    $promptFile = Join-Path $RunDir "$Stem.prompt.txt"
    $errFile = Join-Path $RunDir "$Stem.err"

    $tierModel = $null
    if (Test-Path -LiteralPath $dispatchFile) {
        try {
            $d = [IO.File]::ReadAllText($dispatchFile) | ConvertFrom-Json
            if ($d.Tier -and $d.Model) { $tierModel = "$($d.Tier)/$($d.Model)" }
        } catch { }
    }
    $link = Get-IssueLink $promptFile

    $info = Get-Item -LiteralPath $jsonFile
    if ($info.Length -eq 0) {
        $status = "$when - RUNNING"
        if ($tierModel) { $status += " - $tierModel" }
        $lines = @("### $name", $status)
        if ($link) { $lines += $link }
        return ,$lines
    }

    $r = [IO.File]::ReadAllText($jsonFile) | ConvertFrom-Json
    $cost = '{0:0.00}' -f $r.total_cost_usd
    $costTurns = "`$$cost - $($r.num_turns) turns"

    if ($r.is_error) {
        $status = "$when - ERRORED - $costTurns"
        if ($tierModel) { $status += " - $tierModel" }
        $lines = @("### $name", $status, '',
            "terminal_reason ``$($r.terminal_reason)``",
            "``$(Get-StderrTail $errFile)``")
        return ,$lines
    }

    $gistLine = @($r.result -split "`r?`n") | Where-Object { $_ -match '^\s*GIST:\s' } | Select-Object -First 1
    if ($gistLine) {
        $status = "$when - LANDED - $costTurns"
        if ($tierModel) { $status += " - $tierModel" }
        $lines = @("### $name", $status)
        if ($link) { $lines += $link }
        $lines += @('', $gistLine.Trim())
        return ,$lines
    }

    $status = "$when - LANDED (no GIST) - $costTurns"
    if ($tierModel) { $status += " - $tierModel" }
    $lines = @("### $name", $status)
    if ($link) { $lines += $link }
    $lines += @('', 'exit clean but printed no GIST line')
    ,$lines
}

function Format-Repo($RepoName, $RunDir) {
    $stems = @(Get-ChildItem -LiteralPath $RunDir -Filter '*.json' -File |
        Where-Object { $_.Name -notlike '*.dispatch.json' } |
        ForEach-Object { $_.BaseName } |
        Sort-Object { [regex]::Match($_, '(\d{8}-\d{6})$').Value } -Descending |
        Select-Object -First $Cap)

    $blocks = @($stems | ForEach-Object { ,(Format-Run $RunDir $_) })
    $newestTs = [regex]::Match($stems[0], '(\d{8})-(\d{6})$')
    $updated = [datetime]::ParseExact($newestTs.Value, 'yyyyMMdd-HHmmss', $null).ToString('ddd dd MMM yyyy HH:mm')

    $header = @("# $RepoName runs", '', "Updated $updated - newest first, last $Cap.")
    $body = ($blocks | ForEach-Object { $_ -join "`n" }) -join "`n`n"
    ($header -join "`n") + "`n`n" + $body + "`n"
}

$repoDirs = Get-ChildItem -LiteralPath $ProjectsRoot -Directory -ErrorAction SilentlyContinue |
    ForEach-Object {
        $runDir = Join-Path $_.FullName '.claude\caesar-runs'
        if (Test-Path -LiteralPath $runDir -PathType Container) {
            [pscustomobject]@{ Name = $_.Name; RunDir = $runDir }
        }
    }

if (-not $repoDirs) { throw "No .claude\caesar-runs directory found under $ProjectsRoot" }

$tmp = Join-Path ([IO.Path]::GetTempPath()) "caesar-publish-runs-$(Get-Random)"
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

$desired = @{}
foreach ($repo in $repoDirs) {
    $fileName = "$($repo.Name).md"
    $content = Format-Repo $repo.Name $repo.RunDir
    $path = Join-Path $tmp $fileName
    [IO.File]::WriteAllText($path, $content, (New-Object System.Text.UTF8Encoding $false))
    $desired[$fileName] = $path
}

$existing = @(gh api "gists/$GistId" --jq '.files | keys[]')

foreach ($fileName in $desired.Keys) {
    if ($existing -contains $fileName) {
        gh gist edit $GistId --filename $fileName $desired[$fileName] | Out-Null
    } else {
        gh gist edit $GistId --add $desired[$fileName] | Out-Null
    }
}

# The hand-written gist's one file was `caesar-runs.md`; the caesar repo now renders
# as `caesar.md` like every other repo, so the old name is retired once its content
# has a home under the new one.
if (($existing -contains 'caesar-runs.md') -and -not $desired.ContainsKey('caesar-runs.md')) {
    gh gist edit $GistId --remove 'caesar-runs.md' | Out-Null
}

Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
Write-Output "Published $($desired.Keys.Count) file(s) to gist $GistId"
