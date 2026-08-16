<#
.SYNOPSIS
  Whole Caesar picture - every driven map, its tickets, open PRs, agent slots and
  centurion runs - as one JSON document on stdout (issue #181).

.DESCRIPTION
  Renders over frontier.ps1 for the per-map ticket sweep and over ticket-state.ps1
  (issue #24's owner/state/rank rules, including the flagged-owner rule from #17) for
  the open-ticket view, so those rules stay in exactly one place shared with
  status.ps1.

  Duplicates publish-runs.ps1's run classifier rather than sharing it: that script's
  job is rendering markdown into a gist, not returning data, and its classifier is a
  few lines wedged inside a markdown formatter, not a seam worth carving out for this.
  A second small copy of the RUNNING / LANDED / LANDED (no GIST) / ERRORED rule now
  exists - see the PR body.

  A map that errors mid-sweep (bad URL, gh failure) records the error against that map
  and the sweep continues - one bad map cannot take the whole document down.

.EXAMPLE
  .\dashboard-data.ps1
  .\dashboard-data.ps1 -MapUrl https://github.com/Dhillvn/caesar/issues/1
#>
[CmdletBinding()]
param(
    [string[]]$MapUrl,
    [int]$Cap = 4,
    [string]$ProjectsRoot = (Join-Path $env:USERPROFILE 'Projects')
)

$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'ticket-state.ps1')
$sweepScript = Join-Path $PSScriptRoot 'frontier.ps1'

if (-not $MapUrl) {
    $found = gh search issues --owner Dhillvn --label wayfinder:map --label caesar:driving --json url
    if ($LASTEXITCODE -ne 0) { throw "gh search issues failed" }
    $MapUrl = @(($found | ConvertFrom-Json) | ForEach-Object { $_.url })
}

$maps = foreach ($url in $MapUrl) {
    $repo = $null
    $mapNum = $null
    try {
        if ($url -notmatch '^https?://github\.com/([^/]+)/([^/]+)/issues/(\d+)') {
            throw "Not a GitHub issue URL: $url"
        }
        $repo = "$($Matches[1])/$($Matches[2])"
        $mapNum = [int]$Matches[3]

        $rows = @(& $sweepScript -MapUrl $url)
        $done = @($rows | Where-Object { $_.Status -eq 'closed' } | Sort-Object ClosedAt)
        $open = @(Get-OpenTickets $rows | ForEach-Object {
            [pscustomobject]@{
                Number = $_.Number; Title = $_.Title; Url = $_.Url; Type = $_.Type
                Who = $_.Who; State = $_.State
                BlockedBy = @(if ($_.BlockedBy) { $_.BlockedBy -split ',' | ForEach-Object { [int]$_ } } else { @() })
            }
        })
        $lastDecided = if ($done.Count -gt 0) {
            [pscustomobject]@{ Number = $done[-1].Number; Title = $done[-1].Title; Url = $done[-1].Url }
        } else { $null }

        [pscustomobject]@{
            Number = $mapNum; Title = $rows[0].MapTitle; Repo = $repo; Url = $url
            DoneCount = $done.Count; OpenCount = $open.Count
            LastDecided = $lastDecided; OpenTickets = $open; Error = $null
        }
    } catch {
        [pscustomobject]@{
            Number = $mapNum; Title = $null; Repo = $repo; Url = $url
            DoneCount = 0; OpenCount = 0; LastDecided = $null; OpenTickets = @()
            Error = $_.Exception.Message
        }
    }
}
$maps = @($maps)

$slots = @($maps | ForEach-Object { $_.OpenTickets } | Where-Object { $_.Who -eq 'Caesar' -and $_.State -eq 'Ongoing' }).Count

$repos = @($maps | Where-Object { $_.Repo } | ForEach-Object { $_.Repo } | Select-Object -Unique)
$prs = foreach ($r in $repos) {
    $json = gh pr list --repo $r --state open --json number,title,url,isDraft
    if ($LASTEXITCODE -ne 0) { throw "gh pr list failed for $r" }
    foreach ($pr in ($json | ConvertFrom-Json)) {
        [pscustomobject]@{ Number = $pr.number; Title = $pr.title; Url = $pr.url; Repo = $r; Draft = $pr.isDraft }
    }
}
$prs = @($prs)

# ponytail: small duplicate of publish-runs.ps1's classifier - see .DESCRIPTION.
function Get-RunClassification($JsonFile) {
    $info = Get-Item -LiteralPath $JsonFile
    if ($info.Length -eq 0) { return @{ Classification = 'RUNNING'; Result = $null } }
    $r = [IO.File]::ReadAllText($JsonFile) | ConvertFrom-Json
    if ($r.is_error) { return @{ Classification = 'ERRORED'; Result = $r } }
    $gistLine = @($r.result -split "`r?`n") | Where-Object { $_ -match '^\s*GIST:\s' } | Select-Object -First 1
    if ($gistLine) { return @{ Classification = 'LANDED'; Result = $r } }
    return @{ Classification = 'LANDED (no GIST)'; Result = $r }
}

function Get-RunTicket([string]$PromptFile) {
    if (-not $PromptFile -or -not (Test-Path -LiteralPath $PromptFile)) { return $null }
    try {
        $stream = [IO.File]::Open($PromptFile, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
        try {
            $reader = New-Object IO.StreamReader($stream)
            $text = $reader.ReadToEnd()
        } finally { $stream.Dispose() }
    } catch { return $null }
    $m = [regex]::Match($text, 'https://github\.com/[^/\s]+/[^/\s]+/issues/(\d+)')
    if ($m.Success) { [int]$m.Groups[1].Value } else { $null }
}

$runs = foreach ($repoDir in (Get-ChildItem -LiteralPath $ProjectsRoot -Directory -ErrorAction SilentlyContinue)) {
    $runDir = Join-Path $repoDir.FullName '.claude\caesar-runs'
    if (-not (Test-Path -LiteralPath $runDir -PathType Container)) { continue }
    $stems = @(Get-ChildItem -LiteralPath $runDir -Filter '*.json' -File |
        Where-Object { $_.Name -notlike '*.dispatch.json' } |
        ForEach-Object { $_.BaseName })
    foreach ($stem in $stems) {
        $jsonFile = Join-Path $runDir "$stem.json"
        $promptFile = Join-Path $runDir "$stem.prompt.txt"
        $tsMatch = [regex]::Match($stem, '(\d{8})-(\d{6})$')
        $ts = if ($tsMatch.Success) { [datetime]::ParseExact($tsMatch.Value, 'yyyyMMdd-HHmmss', $null).ToString('o') } else { $null }
        $class = Get-RunClassification $jsonFile
        [pscustomobject]@{
            Name = $stem -replace '-\d{8}-\d{6}$', ''
            Repo = $repoDir.Name
            Classification = $class.Classification
            Ticket = Get-RunTicket $promptFile
            Cost = $class.Result.total_cost_usd
            Turns = $class.Result.num_turns
            Timestamp = $ts
        }
    }
}
$runs = @($runs)

[pscustomobject]@{
    GeneratedAt = (Get-Date).ToString('o')
    Maps = $maps
    OpenPrs = $prs
    AgentSlots = [pscustomobject]@{ InUse = $slots; Cap = $Cap }
    CenturionRuns = $runs
} | ConvertTo-Json -Depth 10
