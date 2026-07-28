<#
.SYNOPSIS
  The status view: what Raj reads to see where things stand (issue #24, design #10).

.DESCRIPTION
  Renders over frontier.ps1 — no GraphQL of its own, so the blockedBy open-only filter
  stays in exactly one place. Six facts per open ticket: number, title, Wayfinder type,
  who acts, state, and blockers when blocked. Rows sort by what needs Raj first.

.EXAMPLE
  .\status.ps1 -MapUrl https://github.com/Dhillvn/caesar/issues/1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string[]]$MapUrl,
    [int]$Cap = 4
)

$ErrorActionPreference = 'Stop'

$W = [ordered]@{ Num = 4; Who = 6; Ticket = 50; State = 13; Type = 9 }

function Format-Cell([string]$Text, [int]$Width) {
    if ($Text.Length -gt $Width) { $Text = $Text.Substring(0, $Width - 1) + [char]0x2026 }
    $Text.PadRight($Width)
}

function Format-Row($Num, $Who, $Ticket, $State, $Type) {
    '{0} {1} {0} {2} {0} {3} {0} {4} {0} {5} {0}' -f [char]0x2502,
        (Format-Cell $Num $W.Num), (Format-Cell $Who $W.Who), (Format-Cell $Ticket $W.Ticket),
        (Format-Cell $State $W.State), (Format-Cell $Type $W.Type)
}

function Format-Bar([char]$L, [char]$M, [char]$R) {
    $segments = @($W.Values | ForEach-Object { [string][char]0x2500 * ($_ + 2) })
    [string]$L + ($segments -join [string]$M) + [string]$R
}

# Wayfinder: research is always Caesar's, grilling and prototype always Raj's, and a
# task is Caesar's unless he stamps `caesar:hitl` on it ("the agent drives it alone
# where it can"). Anything unlabelled is Raj's — an unowned ticket should surface.
function Get-Who($Row) {
    if ($Row.Type -eq 'research') { return 'Caesar' }
    if ($Row.Type -eq 'task' -and -not $Row.Hitl) { return 'Caesar' }
    'You'
}

# what needs you, then what is moving, then what is next, then what is stuck
function Get-Rank($Who, $State) {
    switch ("$Who/$State") {
        'You/Queued'     { 0 }
        'You/Ongoing'    { 1 }
        'Caesar/Ongoing' { 2 }
        'Caesar/Queued'  { 3 }
        default          { 4 }
    }
}

function Split-Wrap([string]$Text, [int]$Width) {
    $lines = @()
    foreach ($word in ($Text -split ' +')) {
        if ($lines.Count -eq 0) { $lines = @($word) }
        elseif (($lines[-1] + ' ' + $word).Length -le $Width) { $lines[-1] += ' ' + $word }
        else { $lines += $word }
    }
    # ponytail: a single word wider than the cell is left to Format-Cell to truncate.
    $lines
}

$sweepScript = Join-Path $PSScriptRoot 'frontier.ps1'
$slots = 0
$repos = @()

Write-Output ("CAESAR - {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))

foreach ($url in $MapUrl) {
    if ($url -notmatch '^https?://github\.com/([^/]+)/([^/]+)/issues/(\d+)') {
        throw "Not a GitHub issue URL: $url"
    }
    $repos += "$($Matches[1])/$($Matches[2])"
    $mapNum = $Matches[3]

    $rows = @(& $sweepScript -MapUrl $url)
    $done = @($rows | Where-Object { $_.Status -eq 'closed' } | Sort-Object ClosedAt)
    $open = @($rows | Where-Object { $_.Status -ne 'closed' } | ForEach-Object {
        $state = switch ($_.Status) { 'blocked' { 'Blocked' } 'claimed' { 'Ongoing' } default { 'Queued' } }
        $who = Get-Who $_
        [pscustomobject]@{
            Number = $_.Number; Title = $_.Title; Type = $_.Type
            Who = $who; State = $state; BlockedBy = $_.BlockedBy
            Rank = (Get-Rank $who $state)
        }
    } | Sort-Object Rank, Number)

    $slots += @($open | Where-Object { $_.Who -eq 'Caesar' -and $_.State -eq 'Ongoing' }).Count

    $headline = "{0} decided {1} {2} open" -f $done.Count, [char]0x00B7, $open.Count
    if ($done.Count -gt 0) { $headline += " {0} last was #{1} {2}" -f [char]0x00B7, $done[-1].Number, $done[-1].Title }

    Write-Output ''
    Write-Output ("MAP #{0}  {1}" -f $mapNum, $rows[0].MapTitle)
    Write-Output $headline
    Write-Output ''
    Write-Output (Format-Bar ([char]0x250C) ([char]0x252C) ([char]0x2510))
    Write-Output (Format-Row '#' 'Who' 'Ticket' 'State' 'Type')
    Write-Output (Format-Bar ([char]0x251C) ([char]0x253C) ([char]0x2524))

    if ($open.Count -eq 0) {
        Write-Output (Format-Row '' '' 'nothing open - map is done' '' '')
    }
    foreach ($t in $open) {
        $state = $t.State
        if ($t.BlockedBy) { $state += ' ' + (($t.BlockedBy -split ',' | ForEach-Object { "#$_" }) -join ',') }
        $wrapped = @(Split-Wrap $t.Title $W.Ticket)
        Write-Output (Format-Row "#$($t.Number)" $t.Who $wrapped[0] $state $t.Type)
        foreach ($cont in @($wrapped | Select-Object -Skip 1)) {
            Write-Output (Format-Row '' '' ("  " + $cont) '' '')
        }
    }
    Write-Output (Format-Bar ([char]0x2514) ([char]0x2534) ([char]0x2518))
}

Write-Output ''
Write-Output "Agent slots: $slots of $Cap in use"
Write-Output 'Waiting on your word:'
# ponytail: formatted here rather than with --jq; a jq expression containing spaces is
# mangled on the way through PowerShell's native-argument handling.
$prs = foreach ($r in ($repos | Select-Object -Unique)) {
    $json = gh pr list --repo $r --state open --json number,title,isDraft
    if ($LASTEXITCODE -ne 0) { throw "gh pr list failed for $r" }
    foreach ($pr in ($json | ConvertFrom-Json)) {
        "  PR #{0}  {1}{2}" -f $pr.number, $pr.title, $(if ($pr.isDraft) { '  (draft)' } else { '' })
    }
}
if ($prs) { $prs } else { Write-Output '  nothing - no open PRs' }
