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

# ponytail: this process's console codepage can default to ASCII (OEM 437), which
# silently drops every non-ASCII byte gh.exe writes - em dashes and curly quotes in
# ticket titles come back as garbage. frontier.ps1 is frozen, but it runs `& `-called
# in this same process, so fixing the encoding here fixes it there too.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

. (Join-Path $PSScriptRoot 'ticket-state.ps1')
$sweepScript = Join-Path $PSScriptRoot 'frontier.ps1'

if (-not $MapUrl) {
    # --state open is load-bearing: `gh search issues` searches every state by default,
    # so a closed map that still carries caesar:driving is discovered and rendered as a
    # live map. numen-ops#35 did exactly that - closed 2026-07-31, still labelled, still
    # on the board six weeks later. The label is the claim, but the issue's state outranks
    # it: a closed map is never being driven, whatever its labels say.
    $found = gh search issues --owner Dhillvn --label wayfinder:map --label caesar:driving --state open --json url
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
        # The whole decided list, newest first, so the page can show them without a trip
        # to GitHub. $done is ascending by ClosedAt; the dropdown reads most-recent-first.
        $decided = @($done | Sort-Object ClosedAt -Descending | ForEach-Object {
            [pscustomobject]@{
                Number = $_.Number; Title = $_.Title; Url = $_.Url
                Type = $_.Type; ClosedAt = $_.ClosedAt
            }
        })

        [pscustomobject]@{
            Number = $mapNum; Title = $rows[0].MapTitle; Repo = $repo; Url = $url
            DoneCount = $done.Count; OpenCount = $open.Count
            LastDecided = $lastDecided; Decided = $decided; OpenTickets = $open; Error = $null
        }
    } catch {
        [pscustomobject]@{
            Number = $mapNum; Title = $null; Repo = $repo; Url = $url
            DoneCount = 0; OpenCount = 0; LastDecided = $null; Decided = @(); OpenTickets = @()
            Error = $_.Exception.Message
        }
    }
}
$maps = @($maps)

$slots = @($maps | ForEach-Object { $_.OpenTickets } | Where-Object { $_.Who -eq 'Caesar' -and $_.State -eq 'Ongoing' }).Count

# ticket -> owning map number, so a PR's closing issue can be traced back to its
# Dashboard Frame (#183: the gate groups PRs under the map they belong to).
# Decided tickets are in the table too: a PR routinely lands against a ticket that is
# already closed, and a table of open tickets alone answers "no map found" for it.
$ticketMap = @{}
foreach ($m in $maps) {
    foreach ($t in $m.OpenTickets) { $ticketMap[$t.Number] = $m.Number }
    foreach ($t in $m.Decided) { $ticketMap[$t.Number] = $m.Number }
}

$repos = @($maps | Where-Object { $_.Repo } | ForEach-Object { $_.Repo } | Select-Object -Unique)
$prs = foreach ($r in $repos) {
    $json = gh pr list --repo $r --state open --json number,title,url,isDraft,createdAt,headRefName,closingIssuesReferences
    if ($LASTEXITCODE -ne 0) { throw "gh pr list failed for $r" }
    foreach ($pr in ($json | ConvertFrom-Json)) {
        # closingIssuesReferences is populated only by a bare closing keyword - "Closes #71".
        # Every Caesar PR body links its ticket inside a sentence ("Closes the funnel opened
        # by [#71](...)"), which GitHub does not parse, so the array is empty on all of them
        # and every PR rendered as "no map found for this PR's ticket". The branch name is
        # the reliable carrier: spawn-ticket-agent.ps1 names every centurion branch
        # ticket-<n>-<slug>.
        $closes = @($pr.closingIssuesReferences) | Select-Object -First 1
        $ticket = if ($closes) {
            $closes.number
        } elseif ($pr.headRefName -match '^ticket-(\d+)(-|$)') {
            [int]$Matches[1]
        } else { $null }
        $mapNum = if ($ticket -and $ticketMap.ContainsKey($ticket)) { $ticketMap[$ticket] } else { $null }
        [pscustomobject]@{
            Number = $pr.number; Title = $pr.title; Url = $pr.url; Repo = $r; Draft = $pr.isDraft
            Branch = $pr.headRefName; ClosesTicket = $ticket; Map = $mapNum
            AgeSeconds = [int](New-TimeSpan -Start ([datetime]$pr.createdAt) -End (Get-Date).ToUniversalTime()).TotalSeconds
        }
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
