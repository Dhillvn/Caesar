<#
.SYNOPSIS
  Frozen veto sweep. Lists every issue that cross-references a decision Raj has vetoed,
  and returns NO verdict (issue #30).

.DESCRIPTION
  Frozen for the same reason as inspect-run: the fragile part is reaching for the right
  command, not making the call. During #30's grilling the wrong command was reached for
  first and looked entirely convincing - `gh search issues` returned 12 hits of ~20
  where the timeline returns 5, and the noise reads exactly like a real report. A
  one-line veto acted on that would have blown up half the map.

  So: the issue timeline, filtered to `cross-referenced`. One hop only. Which hits are
  load-bearing dependants and which are passing citation is judgment - the API cannot
  tell them apart, and neither can this script.

  Known gap, accepted in #30: the sweep sees only tickets that actually wrote the link.

.EXAMPLE
  .\veto-sweep.ps1 -Ticket https://github.com/Dhillvn/caesar/issues/7
  .\veto-sweep.ps1 -Ticket 7 -Repo Dhillvn/caesar
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Ticket,
    [string]$Repo,
    [string]$RepoPath = $PWD.Path
)

$ErrorActionPreference = 'Stop'

if ($Ticket -match '^https?://github\.com/([^/]+/[^/]+)/issues/(\d+)') {
    if (-not $Repo) { $Repo = $Matches[1] }
    $number = [int]$Matches[2]
} elseif ($Ticket -match '^#?(\d+)$') {
    $number = [int]$Matches[1]
    if (-not $Repo) { $Repo = (gh repo view --json nameWithOwner --jq '.nameWithOwner') }
} else {
    throw "Not an issue URL or number: $Ticket"
}
if (-not $Repo) { throw 'Could not determine owner/repo - pass -Repo.' }

# --- the vetoed decision itself ------------------------------------------------------
$subject = gh issue view $number --repo $Repo --json number,title,state,labels | ConvertFrom-Json
Write-Output ("VETO SWEEP  {0}#{1}  {2}" -f $Repo, $subject.number, $subject.title)
Write-Output ("  state {0}   labels {1}" -f $subject.state, (($subject.labels.name -join ', ')))

# --- one hop of cross-references -----------------------------------------------------
# NOT `gh search issues` (#30). --slurp merges the paginated arrays into one array of
# arrays, hence the flattening pass. No --jq anywhere: a space-bearing filter expression
# is shredded when it travels through argv to a native tool (#24).
$pages = gh api "repos/$Repo/issues/$number/timeline?per_page=100" --paginate --slurp | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw "gh api timeline failed for $Repo#$number" }

$hits = $pages |
    ForEach-Object { $_ } |
    Where-Object { $_.event -eq 'cross-referenced' -and $_.source.issue } |
    ForEach-Object {
        $i = $_.source.issue
        [pscustomobject]@{
            Number = $i.number
            State  = $i.state
            Kind   = if ($i.pull_request) { 'pr' }
                     elseif ($i.labels.name -contains 'wayfinder:map') { 'map' }
                     else { (($i.labels.name | Where-Object { $_ -like 'wayfinder:*' }) -replace 'wayfinder:', '') -join ',' }
            Title  = $i.title
            InFlight = ''
        }
    } |
    Sort-Object Number -Unique

# --- which of them have an agent running right now ------------------------------------
# No state file (#11): a spawned agent's own command line carries `--worktree
# ticket-<n>-<rand>`, so the process table is the truth about what is in flight.
$live = @{}
foreach ($p in Get-CimInstance Win32_Process -ErrorAction SilentlyContinue) {
    if ($p.CommandLine -match 'ticket-(\d+)-\d+') {
        $n = [int]$Matches[1]
        if (-not $live[$n]) { $live[$n] = @() }
        $live[$n] += $p.ProcessId
    }
}
foreach ($h in $hits) { if ($live[$h.Number]) { $h.InFlight = "pid $($live[$h.Number] -join ',')" } }

Write-Output ''
if (-not $hits) {
    Write-Output 'No cross-references. Nothing cites this decision.'
} else {
    Write-Output ("{0} cross-reference(s), one hop:" -f @($hits).Count)
    $hits | Format-Table Number, State, Kind, InFlight, Title -AutoSize | Out-String -Width 200 | Write-Output
}

# An in-flight dependant is the one hit that cannot simply be re-read later: it is
# writing right now, on a premise that has just been withdrawn.
if ($live.Count) {
    Write-Output ("IN FLIGHT: ticket(s) {0} have a live agent. Drain or kill is Raj's call (#30)." -f (($live.Keys | Sort-Object) -join ', '))
    Write-Output ''
}

Write-Output 'No verdict by design. Judge it: SKILL.md, "When Raj vetoes a closed decision".'
Write-Output 'The map issue is always a hit - it links every ticket. That is the map line, not a dependant.'
