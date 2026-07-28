<#
.SYNOPSIS
  Frozen map-body read/write. Body content never passes through a PowerShell string:
  GitHub -> file on fetch, file -> GitHub on write. Every write is backed up first and
  refused if it would shrink the map's structure.

.DESCRIPTION
  Frozen because the unsafe version looks identical to the safe one and destroys the
  map without an error (issue #36). A body round-tripped through
  `gh issue view --jq .body | Set-Content -NoNewline` is captured by PowerShell as an
  ARRAY OF LINES, and -NoNewline joins an array with no separator at all - so all
  25 KB came back as a single line with every heading and bullet gone, and GitHub
  accepted it silently. GitHub keeps no revision history for an API body edit, so
  without a pre-write copy the map is unrecoverable.

  Two rules follow, and both live here rather than in a session's judgment:

  1. The body is moved as bytes, never as a variable. Fetch redirects gh's stdout
     straight to a file; write uses `--body-file`. Nothing in between splits lines.
  2. "Verify" is structural, not a phrase check. The write that destroyed the map
     passed its verify, because the check asked "is the stale phrase gone?" - which
     was true. Heading count, decision-bullet count, ticket links and a byte floor
     are what actually separate a good write from a catastrophic one.

  The shape check runs BEFORE the write as well as after it, so the common case is
  refused on disk rather than repaired on GitHub.

.EXAMPLE
  # fetch the live body to a file, then edit that file
  .\map-body.ps1 -MapUrl https://github.com/Dhillvn/caesar/issues/1

.EXAMPLE
  # write the edited file back, with backup + pre/post shape check
  .\map-body.ps1 -MapUrl https://github.com/Dhillvn/caesar/issues/1 -BodyFile .\map.md

.EXAMPLE
  .\map-body.ps1 -SelfCheck
#>
[CmdletBinding()]
param(
    [string]$MapUrl,
    [string]$BodyFile,
    # A legitimate shrink (a section genuinely deleted) needs saying out loud.
    [switch]$AllowShrink,
    [switch]$SelfCheck
)

$ErrorActionPreference = 'Stop'

# --- shape: the invariants that tell a good write from a catastrophic one ----------

function Get-BodyShape([string]$text) {
    # Normalise first, and measure only the normalised text. `gh --jq` appends a newline
    # to its output, so a fetched body is always one byte and one line longer than the
    # file that produced it - post-verify reported that as damage until this trimmed.
    $text = ($text -replace "`r", '').TrimEnd("`n")
    # Split explicitly. Applying a ^-anchored regex to an array is the sibling bug that
    # made the first damage-check report 0 headings on a healthy map (#36).
    $lines = $text -split "`n"
    [pscustomobject]@{
        Bytes    = [Text.Encoding]::UTF8.GetByteCount($text)
        Lines    = $lines.Count
        Headings = @($lines | Where-Object { $_ -match '^#{1,3} ' }).Count
        Bullets  = @($lines | Where-Object { $_ -match '^- \[' }).Count
        Links    = @([regex]::Matches($text, 'https://github\.com/[^/\s)]+/[^/\s)]+/issues/\d+') |
                    ForEach-Object { $_.Value } | Sort-Object -Unique)
    }
}

function Test-BodyShape($old, $new) {
    $problems = @()
    foreach ($f in 'Lines', 'Headings', 'Bullets') {
        if ($new.$f -lt $old.$f) { $problems += "$f dropped $($old.$f) -> $($new.$f)" }
    }
    # 10% is slack for a rewritten gist, not for a lost section - the failure this
    # guards took 25 KB to one line, and a real edit that sheds a tenth of the map is
    # something Caesar should have to state.
    if ($new.Bytes -lt [int]($old.Bytes * 0.9)) {
        $problems += "bytes dropped $($old.Bytes) -> $($new.Bytes) (>10%)"
    }
    $lost = @($old.Links | Where-Object { $new.Links -notcontains $_ })
    if ($lost.Count) { $problems += "$($lost.Count) ticket link(s) vanished: $($lost -join ', ')" }
    , $problems
}

if ($SelfCheck) {
    $good = "## A`n`n- [t](https://github.com/o/r/issues/2) - gist`n`n## B`n"
    $collapsed = ($good -replace "`n", '')          # the exact #36 failure
    $grown = $good + "- [u](https://github.com/o/r/issues/3) - gist`n"
    $a = Get-BodyShape $good
    if ($a.Headings -ne 2) { throw "SelfCheck: headings $($a.Headings), expected 2" }
    if ($a.Bullets -ne 1) { throw "SelfCheck: bullets $($a.Bullets), expected 1" }
    if ($a.Links.Count -ne 1) { throw "SelfCheck: links $($a.Links.Count), expected 1" }
    if (-not (Test-BodyShape $a (Get-BodyShape $collapsed)).Count) { throw 'SelfCheck: collapse not caught' }
    if ((Test-BodyShape $a (Get-BodyShape $grown)).Count) { throw 'SelfCheck: normal growth refused' }
    if (-not (Test-BodyShape $a (Get-BodyShape ($good -replace 'issues/2', 'issues/9'))).Count) {
        throw 'SelfCheck: lost ticket link not caught'
    }
    Write-Output 'SelfCheck OK'
    return
}

# --- plumbing ---------------------------------------------------------------------

if (-not $MapUrl) { throw 'MapUrl is required (or use -SelfCheck)' }
if ($MapUrl -notmatch '^https?://github\.com/([^/]+)/([^/]+)/issues/(\d+)') {
    throw "Not a GitHub issue URL: $MapUrl"
}
$owner = $Matches[1]; $repo = $Matches[2]; $num = [int]$Matches[3]
$slug = "$owner/$repo"

$gh = (Get-Command gh -ErrorAction Stop).Source
# -C against PowerShell's location, never bare git: a native command inherits the
# PROCESS cwd, which Set-Location does not move, and that gap already made one script
# report confidently on another repo (#26).
$here = (Get-Location).Path
$root = (& git -C $here rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $root) { $root = $here }
$backupDir = Join-Path ([string]$root).Trim() '.claude/caesar-runs/map-backups'
if (-not (Test-Path $backupDir)) { New-Item -ItemType Directory -Path $backupDir -Force | Out-Null }

function Get-LiveBody([string]$destination) {
    # Bytes straight to disk. gh's stdout never becomes a PowerShell value, so there is
    # no array to be joined wrongly and no encoding pass. None of these arguments can
    # contain a space, which is what makes ArgumentList safe here (#24).
    $p = Start-Process -FilePath $gh -NoNewWindow -Wait -PassThru `
        -ArgumentList @('api', "repos/$slug/issues/$num", '--jq', '.body') `
        -RedirectStandardOutput $destination
    if ($p.ExitCode -ne 0) { throw "gh api failed reading $slug#$num (exit $($p.ExitCode))" }
    if (-not (Test-Path $destination)) { throw "no body written to $destination" }
    [IO.File]::ReadAllText($destination)
}

$stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss')
$backup = Join-Path $backupDir "$owner-$repo-$num-$stamp.md"

# --- fetch mode -------------------------------------------------------------------

if (-not $BodyFile) {
    $text = Get-LiveBody $backup
    return [pscustomobject]@{
        Repo  = $slug
        Issue = $num
        Path  = $backup
        Shape = Get-BodyShape $text
    }
}

# --- write mode -------------------------------------------------------------------

if (-not [IO.Path]::IsPathRooted($BodyFile)) { $BodyFile = Join-Path $here $BodyFile }
$BodyFile = [IO.Path]::GetFullPath($BodyFile)
if (-not (Test-Path $BodyFile)) { throw "BodyFile not found: $BodyFile" }

$oldText = Get-LiveBody $backup            # the backup IS the pre-write read
$oldShape = Get-BodyShape $oldText
$newShape = Get-BodyShape ([IO.File]::ReadAllText($BodyFile))

function New-Verdict($written, $reason, $problems) {
    [pscustomobject]@{
        Repo     = $slug
        Issue    = $num
        Written  = $written
        Reason   = $reason
        Backup   = $backup
        Old      = $oldShape
        New      = $newShape
        Problems = @($problems)
        Restore  = "gh issue edit $num --repo $slug --body-file `"$backup`""
    }
}

$problems = Test-BodyShape $oldShape $newShape
if ($problems.Count -and -not $AllowShrink) {
    return New-Verdict $false 'refused before writing - shape shrank' $problems
}

& $gh issue edit $num --repo $slug --body-file $BodyFile | Out-Null
if ($LASTEXITCODE -ne 0) { return New-Verdict $false 'gh issue edit failed' @() }

# Post-verify against what GitHub actually stored, not against what we sent.
$liveText = Get-LiveBody ([IO.Path]::GetTempFileName())
$liveShape = Get-BodyShape $liveText
$drift = @(foreach ($f in 'Lines', 'Headings', 'Bullets', 'Bytes') {
        if ($liveShape.$f -ne $newShape.$f) { "$f sent $($newShape.$f), stored $($liveShape.$f)" }
    })
if ($drift.Count) {
    return New-Verdict $false 'WRITTEN BUT DAMAGED - restore from backup' $drift
}

New-Verdict $true 'written and verified' $problems
