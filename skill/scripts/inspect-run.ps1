<#
.SYNOPSIS
  Frozen failure triage. Prints the facts a failed or suspect ticket run left behind,
  and returns NO verdict (issue #17).

.DESCRIPTION
  Frozen for the same reason as the sweep and the spawn: the fragile part is reading
  the right fields, not making the call. Reading a result JSON by hand during #17's
  grilling produced a wrong rule inside five minutes - a non-empty permission_denials
  is not a failure signal, and a real successful run on disk carries one.

  The judgment - retry a bad roll, flag a wall, one retry maximum - is prose in
  SKILL.md. Nothing here classifies anything.

  Takes the object spawn-ticket-agent.ps1 returns, so it pipes straight from it:
    .\spawn-ticket-agent.ps1 ... | .\inspect-run.ps1
  A later session that no longer holds that object passes -ResultFile alone; liveness
  is then unknown and everything else is still recoverable from disk and GitHub.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)][string]$ResultFile,
    [Parameter(ValueFromPipelineByPropertyName = $true)][int]$ProcessId,
    [Parameter(ValueFromPipelineByPropertyName = $true)][string]$Ticket,
    [Parameter(ValueFromPipelineByPropertyName = $true)][string]$WorktreePath,
    [Parameter(ValueFromPipelineByPropertyName = $true)][string]$StderrFile,
    [Parameter(ValueFromPipelineByPropertyName = $true)][double]$BudgetUsd = 2.0,
    [int]$TailLines = 6
)

$ErrorActionPreference = 'Stop'

function Section([string]$Name) { Write-Output ''; Write-Output $Name }
function Fact([string]$Text) { Write-Output "  $Text" }
function Ago([datetime]$When) {
    $s = [int]((Get-Date) - $When).TotalSeconds
    if ($s -lt 90) { "${s}s ago" } elseif ($s -lt 5400) { "$([int]($s / 60))m ago" } else { "$([math]::Round($s / 3600, 1))h ago" }
}
function Clip([string]$Text, [int]$Max = 200) {
    $Text = ($Text -replace '\s+', ' ').Trim()
    if ($Text.Length -gt $Max) { $Text.Substring(0, $Max) + [char]0x2026 } else { $Text }
}

# --- locate everything from the one path we are guaranteed ---------------------------
# Combine against $PWD, not GetFullPath alone: .NET resolves a relative path against the
# *process* working directory, which is not PowerShell's location, so a run inspected
# from a `cd`-ed session silently reported on a path in a different repo entirely.
$ResultFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PWD.Path, $ResultFile))
$logDir = Split-Path -Parent $ResultFile
$base = [System.IO.Path]::GetFileNameWithoutExtension($ResultFile)
# spawn names files <worktree>-yyyyMMdd-HHmmss.json, so the stamp strips deterministically
$worktreeName = $base -replace '-\d{8}-\d{6}$', ''
if (-not $StderrFile) { $StderrFile = Join-Path $logDir "$base.err" }
$promptFile = Join-Path $logDir "$base.prompt.txt"

if (-not $WorktreePath) {
    $repoPath = Split-Path -Parent (Split-Path -Parent $logDir)   # <repo>\.claude\caesar-runs
    $WorktreePath = Join-Path $repoPath ".claude\worktrees\$worktreeName"
}
if (-not $Ticket -and (Test-Path $promptFile)) {
    # anchored on the url shape, not \S+, so the sentence's full stop is not swallowed
    if ((Get-Content -Raw -LiteralPath $promptFile) -match 'working ticket (\S+/issues/\d+)') { $Ticket = $Matches[1] }
}

Write-Output ("RUN  {0}" -f $worktreeName)
Fact "result   $ResultFile"
Fact "worktree $WorktreePath"
Fact "ticket   $(if ($Ticket) { $Ticket } else { '(unknown - no prompt file)' })"

# --- liveness ------------------------------------------------------------------------
Section 'LIVENESS'
if (-not $ProcessId) {
    Fact 'pid not supplied - liveness unknown, judge on heartbeat and artifact'
} else {
    $proc = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $proc) {
        Fact "pid $ProcessId  DEAD"
    } elseif ($proc.ProcessName -notmatch 'claude|node') {
        # pids are recycled; a live pid owned by something else is not our run
        Fact "pid $ProcessId  ALIVE but is '$($proc.ProcessName)' - pid reused, our run is DEAD"
    } else {
        Fact "pid $ProcessId  ALIVE ($($proc.ProcessName), started $($proc.StartTime), $([math]::Round($proc.WorkingSet64 / 1MB))MB)"
    }
}

# --- heartbeat -----------------------------------------------------------------------
# The only progress signal there is: `claude -p` writes its result JSON at the very end,
# but the transcript .jsonl mtime advances while the agent works.
Section 'HEARTBEAT'
$dashed = $WorktreePath -replace '[:\\/.]', '-'
$transcriptDir = Join-Path "$env:USERPROFILE\.claude\projects" $dashed
$transcript = $null
if (Test-Path $transcriptDir) {
    $transcript = Get-ChildItem $transcriptDir -Filter *.jsonl -File | Sort-Object LastWriteTime | Select-Object -Last 1
}
if ($transcript) {
    Fact "transcript $($transcript.Name)  ($([math]::Round($transcript.Length / 1KB))KB)"
    Fact "last write $($transcript.LastWriteTime)  ($(Ago $transcript.LastWriteTime))"
} elseif (Test-Path $transcriptDir) {
    Fact "$transcriptDir exists but holds no .jsonl - the session never wrote a turn"
} else {
    Fact "no transcript dir at $transcriptDir - the run may never have started"
}

# --- artifact state, from GitHub -----------------------------------------------------
Section 'ARTIFACT (GitHub - the only real evidence of work done)'
if ($Ticket -match '^https?://github\.com/([^/]+)/([^/]+)/issues/(\d+)') {
    $json = gh issue view $Matches[3] --repo "$($Matches[1])/$($Matches[2])" --json state,comments,assignees,labels
    if ($LASTEXITCODE -ne 0) {
        Fact 'gh issue view failed - could not read the ticket'
    } else {
        $issue = $json | ConvertFrom-Json
        Fact "state $($issue.state)   assignees: $(($issue.assignees.login -join ',')) $(if (-not $issue.assignees) { '(none)' })"
        Fact "labels $(($issue.labels.name -join ', '))"
        if ($issue.comments.Count -eq 0) {
            Fact 'comments 0 - no resolution comment'
        } else {
            Fact "comments $($issue.comments.Count), last by $($issue.comments[-1].author.login) at $($issue.comments[-1].createdAt):"
            Fact "  `"$(Clip $issue.comments[-1].body)`""
        }
    }
} else {
    Fact 'no ticket url - cannot read artifact state'
}

# --- result json ---------------------------------------------------------------------
Section 'RESULT JSON'
$resultOk = $false
if (-not (Test-Path $ResultFile)) {
    Fact 'no result file - the process never got as far as writing one'
} elseif ((Get-Item $ResultFile).Length -eq 0) {
    # Redirection creates this file at spawn, and `claude -p` writes it only at the very
    # end - so 0 bytes means "no result yet", and only LIVENESS above says whether that
    # is a run still working or one that died before writing.
    Fact '0 bytes - no result written yet. Alive above = still working; dead = died before writing'
} else {
    $r = Get-Content -Raw -LiteralPath $ResultFile | ConvertFrom-Json
    $resultOk = $true
    Fact "is_error $($r.is_error)   terminal_reason $($r.terminal_reason)   subtype $($r.subtype)   stop_reason $($r.stop_reason)"
    Fact ("cost `$$([math]::Round($r.total_cost_usd, 4)) of `$$BudgetUsd cap{0}" -f $(if ($r.total_cost_usd -ge $BudgetUsd * 0.98) { '  <-- AT CAP' } else { '' }))
    Fact "turns $($r.num_turns)   session_id $($r.session_id)"
    $denials = @($r.permission_denials)
    # NOT a failure signal on its own (#17): a real successful run on disk carries one.
    Fact "permission_denials $($denials.Count)$(if ($denials.Count) { ': ' + (($denials.tool_name | Select-Object -Unique) -join ', ') })"
    if ($r.api_error_status) { Fact "api_error_status $($r.api_error_status)" }
}

# --- tails ---------------------------------------------------------------------------
if ((Test-Path $StderrFile) -and (Get-Item $StderrFile).Length -gt 0) {
    Section "STDERR TAIL ($((Get-Item $StderrFile).Length) bytes)"
    Get-Content -LiteralPath $StderrFile -Tail $TailLines | ForEach-Object { Fact $_ }
}

# For a wedged or killed run there is no result JSON, so the transcript is the only
# evidence of what it was doing when it stopped - exactly the class needing most judgment.
if (-not $resultOk -and $transcript) {
    Section "TRANSCRIPT TAIL (last $TailLines turns - no result JSON, so this is the evidence)"
    Get-Content -LiteralPath $transcript.FullName -Tail $TailLines | ForEach-Object {
        try { $t = $_ | ConvertFrom-Json } catch { Fact (Clip $_); return }
        $text = $t.message.content | ForEach-Object { if ($_.text) { $_.text } elseif ($_.name) { "[$($_.name)] $($_.input | ConvertTo-Json -Compress -Depth 3)" } }
        Fact ("{0}: {1}" -f $t.type, (Clip ($text -join ' ')))
    }
}

Write-Output ''
Write-Output 'No verdict by design. Judge it: SKILL.md, "When a spawned agent fails".'
