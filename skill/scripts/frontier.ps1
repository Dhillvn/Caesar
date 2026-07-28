<#
.SYNOPSIS
  Frozen frontier sweep. One GraphQL call (1 rate-limit point) returns every child
  ticket of a Wayfinder map with its type, claim state and open blockers.

.DESCRIPTION
  Frozen because the correctness of the sweep depends on one easily-dropped detail:
  GraphQL's blockedBy counts blockers of ANY state, disagreeing with REST's open-only
  semantics (issue #3). A session composing this query from memory reads a ticket as
  blocked when its blocker closed months ago, and the frontier silently shrinks.

.EXAMPLE
  .\frontier.ps1 -MapUrl https://github.com/Dhillvn/caesar/issues/1 -FrontierOnly
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$MapUrl,
    [switch]$FrontierOnly
)

$ErrorActionPreference = 'Stop'

if ($MapUrl -notmatch '^https?://github\.com/([^/]+)/([^/]+)/issues/(\d+)') {
    throw "Not a GitHub issue URL: $MapUrl"
}
$owner = $Matches[1]
$repo = $Matches[2]
$num = [int]$Matches[3]

$query = @'
query($owner:String!,$repo:String!,$num:Int!){
  repository(owner:$owner,name:$repo){
    issue(number:$num){
      number title
      subIssues(first:100){
        nodes{
          number title state url
          assignees(first:5){ nodes{ login } }
          labels(first:10){ nodes{ name } }
          blockedBy(first:50){ nodes{ number state } }
        }
      }
    }
  }
}
'@

$raw = gh api graphql -f query=$query -F owner=$owner -F repo=$repo -F num=$num
if ($LASTEXITCODE -ne 0) { throw "gh api graphql failed for $MapUrl" }

$map = ($raw | ConvertFrom-Json).data.repository.issue
if ($null -eq $map) { throw "No issue #$num in $owner/$repo" }

# ponytail: 100 sub-issues is GitHub's hard cap on children per parent, so no paging.
$rows = foreach ($t in $map.subIssues.nodes) {
    # The one line this script exists for. See .DESCRIPTION.
    $openBlockers = @($t.blockedBy.nodes | Where-Object { $_.state -eq 'OPEN' } | ForEach-Object { $_.number })
    $assignees = @($t.assignees.nodes | ForEach-Object { $_.login })
    $type = ($t.labels.nodes | Where-Object { $_.name -like 'wayfinder:*' } | Select-Object -First 1).name -replace '^wayfinder:', ''

    if ($t.state -ne 'OPEN') { $status = 'closed' }
    elseif ($openBlockers.Count -gt 0) { $status = 'blocked' }
    elseif ($assignees.Count -gt 0) { $status = 'claimed' }
    else { $status = 'frontier' }

    [pscustomobject]@{
        Number    = $t.number
        Status    = $status
        Type      = $type
        ClaimedBy = ($assignees -join ',')
        BlockedBy = ($openBlockers -join ',')
        Title     = $t.title
        Url       = $t.url
    }
}

if ($FrontierOnly) { $rows = @($rows | Where-Object { $_.Status -eq 'frontier' }) }
$rows | Sort-Object Number
