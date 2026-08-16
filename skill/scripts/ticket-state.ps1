<#
.SYNOPSIS
  Shared open-ticket ownership/state rules (issue #24, #17), used by status.ps1 and
  dashboard-data.ps1 so the flagged-owner rule lives in exactly one place.
#>

# Wayfinder: research is always Caesar's, grilling and prototype always Raj's, and a
# task is Caesar's unless he stamps `caesar:hitl` on it ("the agent drives it alone
# where it can"). Anything unlabelled is Raj's - an unowned ticket should surface.
function Get-Who($Row) {
    if ($Row.Type -eq 'research') { return 'Caesar' }
    if ($Row.Type -eq 'task' -and -not $Row.Hitl) { return 'Caesar' }
    'You'
}

# what needs you, then what is moving, then what is next, then what is stuck
function Get-Rank($Who, $State) {
    switch ("$Who/$State") {
        'You/Needs you'  { -1 }
        'You/Queued'     { 0 }
        'You/Ongoing'    { 1 }
        'Caesar/Ongoing' { 2 }
        'Caesar/Queued'  { 3 }
        default          { 4 }
    }
}

# Turns frontier.ps1's rows for one map into the open-ticket view: who owns it, what
# state it reads as, and its rank. A flagged ticket (#17) is back on Raj whatever its
# type says, reads Needs you, and does not count as an agent slot.
function Get-OpenTickets($Rows) {
    @($Rows | Where-Object { $_.Status -ne 'closed' } | ForEach-Object {
        $state = switch ($_.Status) { 'blocked' { 'Blocked' } 'flagged' { 'Needs you' } 'claimed' { 'Ongoing' } default { 'Queued' } }
        $who = if ($_.Status -eq 'flagged') { 'You' } else { Get-Who $_ }
        [pscustomobject]@{
            Number = $_.Number; Title = $_.Title; Type = $_.Type; Url = $_.Url
            Who = $who; State = $state; BlockedBy = $_.BlockedBy
            Rank = (Get-Rank $who $state)
        }
    } | Sort-Object Rank, Number)
}
