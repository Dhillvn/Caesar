<#
.SYNOPSIS
  Drives a real Caesar session against a disposable fixture map, forces one of Caesar's
  branches, and reports which of the skill's reference files the session actually read.

.DESCRIPTION
  This is the proof mechanism for the skill-restructure map (#109). Every other ticket on
  that map changes skill/SKILL.md; this one watches it. A pointer that nobody can see fire
  is a change nobody can check.

  How the observation works, and why this route:

    - The session is spawned as a headless `claude -p` with an explicit --session-id, so
      its transcript lands at a path this script computes rather than guesses:
      ~/.claude/projects/<cwd with [:\/.] replaced by ->/<session-id>.jsonl. That
      directory derivation is copied from watch-runs.ps1's Get-HeartbeatAge, which is the
      same lookup; the --session-id half is new, because the watcher only ever needs the
      newest transcript and this needs a named one.
    - Every Read/Glob/Grep/Write/Edit in that transcript carries its path in the tool_use
      block, and Bash command text is scanned too. Paths under either the Caesar skill
      junction (~/.claude/skills/caesar) or its target (<repo>/skill) normalise to the
      same skill-relative name, so it does not matter which spelling the session used.
    - Loading SKILL.md itself is a Skill tool call, not a Read, so it is reported
      separately as `skill-loaded` rather than as a reference read.

  What this harness cannot see is written down in docs/harness-blind-spots.md. Read it
  before quoting a result from this script as evidence of anything.

  This script is NOT one of the frozen scripts. It borrows two things by copy and says so
  here: the deny list and the argv-quoting from spawn-ticket-agent.ps1, and the transcript
  directory derivation from watch-runs.ps1. Nothing under skill/scripts/ is modified or
  called for the spawn - spawn-ticket-agent.ps1 hardcodes --permission-mode
  bypassPermissions, which a nested claude call has auto-denied, so it cannot be reused
  here.

.EXAMPLE
  # The whole baseline, all five fixtures, against the installed skill:
  pwsh -File .\scripts\branch-harness.ps1 -All

.EXAMPLE
  pwsh -File .\scripts\branch-harness.ps1 -Fixture drive-dispatch
  pwsh -File .\scripts\branch-harness.ps1 -Cleanup
#>
[CmdletBinding(DefaultParameterSetName = 'One')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'One')][string]$Fixture,
    [Parameter(Mandatory = $true, ParameterSetName = 'All')][switch]$All,
    [Parameter(Mandatory = $true, ParameterSetName = 'Cleanup')][switch]$Cleanup,
    [string]$Repo = 'Dhillvn/Caesar',
    # Resolved in the body, not here: $PSScriptRoot is not reliably populated inside a
    # param block's default under `powershell -File <relative path>`.
    [string]$RepoPath,
    [string]$FixtureDir,
    [string]$Model = 'claude-opus-5',
    [string]$Effort = 'medium',
    [double]$BudgetUsd = 2.0,
    [int]$TimeoutMinutes = 25,
    # Leave the fixture issues open after the run. Off by default: an open fixture map is
    # indistinguishable from real work in a `gh issue list`, which is the whole reason
    # they carry a label and a title prefix.
    [switch]$KeepFixtures
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $RepoPath) { $RepoPath = (Resolve-Path (Split-Path -Parent $scriptDir)).Path }
if (-not $FixtureDir) { $FixtureDir = Join-Path $scriptDir 'branch-fixtures' }

$FixtureLabel = 'caesar:fixture'

# ---------------------------------------------------------------- skill roots

# Both spellings of the same file. The skill is installed as a junction, so a session may
# read C:\Users\rajdh\.claude\skills\caesar\references\x.md or
# C:\Users\rajdh\Projects\caesar\skill\references\x.md and mean the identical byte.
function Get-SkillRoots {
    $link = Join-Path $env:USERPROFILE '.claude\skills\caesar'
    $roots = @()
    $item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
    if ($item) {
        $roots += $item.FullName
        if ($item.LinkType -eq 'Junction') {
            $t = @($item.Target)[0]
            if ($t) { $roots += $t }
        }
    }
    $roots += (Join-Path $RepoPath 'skill')
    ,@($roots | Where-Object { $_ } | Sort-Object -Unique)
}

function ConvertTo-SkillRelative([string]$Path, [string[]]$Roots) {
    if (-not $Path) { return $null }
    $p = ($Path -replace '/', '\')
    foreach ($r in $Roots) {
        $rr = ($r -replace '/', '\').TrimEnd('\') + '\'
        if ($p.StartsWith($rr, [StringComparison]::OrdinalIgnoreCase)) {
            return ($p.Substring($rr.Length) -replace '\\', '/')
        }
    }
    $null
}

# ---------------------------------------------------------------- fixtures

function Get-Fixtures {
    if (-not (Test-Path -LiteralPath $FixtureDir)) { throw "No fixture directory at $FixtureDir" }
    Get-ChildItem -LiteralPath $FixtureDir -Filter *.json -File | Sort-Object Name | ForEach-Object {
        # ReadAllText, not Get-Content: a fixture body is multi-line and must not become
        # an array on the way to ConvertFrom-Json.
        $f = [IO.File]::ReadAllText($_.FullName) | ConvertFrom-Json
        $f | Add-Member -NotePropertyName SourceFile -NotePropertyValue $_.FullName -Force
        $f
    }
}

# ---------------------------------------------------------------- github

function Invoke-Gh([string[]]$GhArgs) {
    # 'Continue' around the call for the same reason as Invoke-GhQuiet: gh's success
    # chatter goes to stderr, and under 'Stop' that alone terminates the script. The exit
    # code is the only failure signal that means anything here.
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $out = & gh @GhArgs 2>&1 } finally { $ErrorActionPreference = $old }
    if ($LASTEXITCODE -ne 0) { throw "gh $($GhArgs -join ' ') failed: $out" }
    @($out) | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
}

# gh writes progress lines to stderr on success ("Closed issue ..."). Under
# $ErrorActionPreference = 'Stop' a native command writing to stderr surfaces as a
# terminating NativeCommandError, so every fire-and-forget gh call goes through here.
function Invoke-GhQuiet([string[]]$GhArgs) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & gh @GhArgs 2>&1 | Out-Null } finally { $ErrorActionPreference = $old }
}

function New-BodyFile([string]$Text, [string]$Dir, [string]$Name) {
    $p = Join-Path $Dir $Name
    # Bodies reach gh through a file, never argv. WriteAllText names its own encoding and
    # emits no BOM; Set-Content -Encoding UTF8 on 5.1 would prepend one.
    [IO.File]::WriteAllText($p, $Text, (New-Object Text.UTF8Encoding $false))
    $p
}

function Assert-FixtureLabel {
    $existing = & gh label list --repo $Repo --limit 200 --json name --jq '.[].name' 2>$null
    if ($existing -contains $FixtureLabel) { return }
    # `gh issue create --label` hard-errors on an unknown label and creates nothing, so
    # this has to happen before any issue does.
    Invoke-GhQuiet @('label', 'create', $FixtureLabel, '--repo', $Repo, '--color', 'ededed',
        '--description', 'Disposable issue created by scripts/branch-harness.ps1. Never real work.')
}

function New-FixtureIssue {
    param([string]$Title, [string[]]$Labels, [string]$Body, [string]$Dir, [string]$Slug)
    $bodyFile = New-BodyFile $Body $Dir "$Slug.body.md"
    $ghArgs = @('issue', 'create', '--repo', $Repo, '--title', $Title, '--body-file', $bodyFile)
    foreach ($l in @($Labels) + @($FixtureLabel)) { $ghArgs += @('--label', $l) }
    $url = (Invoke-Gh $ghArgs | Select-Object -Last 1).ToString().Trim()
    if ($url -notmatch '/issues/(\d+)\s*$') { throw "Could not read an issue number out of: $url" }
    [pscustomobject]@{ Number = [int]$Matches[1]; Url = $url }
}

function Get-IssueDbId([int]$Number) {
    # No space anywhere in the --jq expression, so argv cannot split it.
    [int64](Invoke-Gh @('api', "repos/$Repo/issues/$Number", '--jq', '.id') | Select-Object -Last 1)
}

# ---------------------------------------------------------------- transcript

function Get-TranscriptPath([string]$Cwd, [string]$SessionId) {
    # Copied from watch-runs.ps1 Get-HeartbeatAge - same lookup, named file instead of
    # newest file.
    $dir = Join-Path "$env:USERPROFILE\.claude\projects" (($Cwd -replace '/', '\') -replace '[:\\/.]', '-')
    Join-Path $dir "$SessionId.jsonl"
}

function Read-TranscriptReads([string]$Path, [string[]]$Roots) {
    $reads = [System.Collections.ArrayList]::new()
    $skills = [System.Collections.ArrayList]::new()
    $tools = [System.Collections.ArrayList]::new()
    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{ Reads = @(); Skills = @(); Tools = @(); Lines = 0 }
    }
    $lines = @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)
    foreach ($line in $lines) {
        if (-not $line.Trim()) { continue }
        $e = $null
        try { $e = $line | ConvertFrom-Json } catch { continue }
        $content = $e.message.content
        if ($content -isnot [array]) { continue }
        foreach ($b in $content) {
            if ($b.type -ne 'tool_use') { continue }
            [void]$tools.Add($b.name)
            if ($b.name -eq 'Skill') { [void]$skills.Add([string]$b.input.skill); continue }
            $candidates = @($b.input.file_path, $b.input.path, $b.input.pattern, $b.input.notebook_path)
            if ($b.input.command) {
                # A session can also reach a reference with `cat`/`Get-Content`. Pull any
                # windows-ish or posix-ish path out of the command text.
                $candidates += ([regex]::Matches([string]$b.input.command, '[A-Za-z]:[\\/][^\s"'']+|(?<=\s|^)[\w.\-/\\]*(?:references|skill)[\w.\-/\\]*') |
                    ForEach-Object { $_.Value })
            }
            foreach ($c in $candidates) {
                $rel = ConvertTo-SkillRelative ([string]$c) $Roots
                if ($rel) { [void]$reads.Add($rel) }
            }
        }
    }
    [pscustomobject]@{
        Reads  = @($reads | Sort-Object -Unique)
        Skills = @($skills | Sort-Object -Unique)
        Tools  = @($tools | Group-Object | ForEach-Object { "$($_.Name)x$($_.Count)" } | Sort-Object)
        Lines  = $lines.Count
    }
}

# ---------------------------------------------------------------- the run

# Copied verbatim from spawn-ticket-agent.ps1 (#7). Not imported: that script is frozen
# and this one runs with a different permission mode, so the two must not share a file.
$denied = @(
    'Bash(gh pr merge:*)'
    'Bash(git merge:*)'
    'Bash(git push origin main:*)'
    'Bash(git push --force:*)'
    'Bash(git push -f:*)'
    'Bash(git push --force-with-lease:*)'
    'Bash(git reset --hard:*)'
    'Bash(git clean -fdx:*)'
    'Bash(rm -rf:*)'
    'Bash(gh repo delete:*)'
    'Bash(gh repo archive:*)'
    'Bash(gh api --method DELETE:*)'
    'Bash(gh auth token:*)'
    'Read(~/.ssh/**)'
    'Read(**/.env)'
) + @(
    # Harness-only. A fixture session must not spawn a real centurion or a nested claude,
    # and must not delete the fixtures it is being observed against.
    'Bash(claude:*)'
    'Bash(gh issue delete:*)'
)

$harnessFrame = @'

--- harness note, and it is the truth of this machine, not a hypothetical ---
Dispatching is switched off here: spawn-ticket-agent.ps1 will not run and neither will a
nested `claude` call. When the loop reaches a dispatch, do everything up to the spawn -
pick the ticket, pick the tier, compose the dispatch prompt in full - and print the
prompt instead of firing it. Everything else about this session is normal.
You have one turn and nothing can wake you, so do not wait on anything.
'@

function Invoke-FixtureSession {
    param([string]$Invocation, [string]$Dir, [string]$Slug)

    $sessionId = [guid]::NewGuid().ToString()
    $promptFile = New-BodyFile ($Invocation + "`n" + $harnessFrame) $Dir "$Slug.prompt.txt"
    $outFile = Join-Path $Dir "$Slug.result.json"
    $errFile = Join-Path $Dir "$Slug.err.txt"

    $claudeArgs = @(
        '-p'
        '--output-format', 'json'
        '--session-id', $sessionId
        '--model', $Model
        '--effort', $Effort
        '--max-budget-usd', $BudgetUsd
        # NOT bypassPermissions: a nested claude call inherits this session's permission
        # layer, which auto-denies that flag. acceptEdits plus an explicit allow list is
        # what gets through.
        '--permission-mode', 'acceptEdits'
        '--allowedTools', 'Bash', 'Read', 'Glob', 'Grep', 'Write', 'Edit', 'Skill', 'TodoWrite'
        '--disallowedTools'
    ) + $denied

    # Quoting copied from spawn-ticket-agent.ps1: Start-Process joins -ArgumentList on
    # spaces with no quoting of its own, and a deny specifier contains a space, so
    # unquoted it splits in two and stops matching while still looking present.
    $cmdLine = ($claudeArgs | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ' '

    $p = Start-Process -FilePath 'claude' -ArgumentList $cmdLine `
        -WorkingDirectory $RepoPath -WindowStyle Hidden -PassThru `
        -RedirectStandardInput $promptFile `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    $finished = $p.WaitForExit($TimeoutMinutes * 60 * 1000)
    if (-not $finished) { try { $p.Kill() } catch { } }

    $result = $null
    if ((Test-Path -LiteralPath $outFile) -and (Get-Item -LiteralPath $outFile).Length -gt 0) {
        try { $result = [IO.File]::ReadAllText($outFile) | ConvertFrom-Json } catch { $result = $null }
    }

    [pscustomobject]@{
        SessionId  = $sessionId
        TimedOut   = -not $finished
        Result     = $result
        ResultFile = $outFile
        StderrFile = $errFile
        PromptFile = $promptFile
        Transcript = (Get-TranscriptPath $RepoPath $sessionId)
    }
}

# ---------------------------------------------------------------- fixture staging

function New-FixtureWorld {
    param($Fx, [string]$Dir)

    $created = [System.Collections.ArrayList]::new()
    $numbers = @{}

    foreach ($t in @($Fx.tickets)) {
        $issue = New-FixtureIssue -Title "[FIXTURE $($Fx.id)] $($t.title)" -Labels $t.labels `
            -Body $t.body -Dir $Dir -Slug "$($Fx.id)-$($t.key)"
        $numbers[$t.key] = $issue.Number
        [void]$created.Add($issue)
    }

    $mapIssue = $null
    if ($Fx.map) {
        $mapIssue = New-FixtureIssue -Title "[FIXTURE $($Fx.id)] $($Fx.map.title)" -Labels @('wayfinder:map') `
            -Body $Fx.map.body -Dir $Dir -Slug "$($Fx.id)-map"
        [void]$created.Add($mapIssue)

        foreach ($t in @($Fx.tickets)) {
            $childId = Get-IssueDbId $numbers[$t.key]
            Invoke-Gh @('api', '--method', 'POST', "repos/$Repo/issues/$($mapIssue.Number)/sub_issues",
                '-F', "sub_issue_id=$childId") | Out-Null
        }
    }

    # Second pass: {key} -> #number, everywhere. Issues need ids before they can reference
    # each other, so this cannot fold into the creation pass.
    function Expand-Keys([string]$Text) {
        foreach ($k in $numbers.Keys) { $Text = $Text -replace ("\{" + [regex]::Escape($k) + "\}"), "#$($numbers[$k])" }
        $Text
    }

    if ($mapIssue) {
        $bf = New-BodyFile (Expand-Keys $Fx.map.body) $Dir "$($Fx.id)-map.final.md"
        Invoke-Gh @('issue', 'edit', "$($mapIssue.Number)", '--repo', $Repo, '--body-file', $bf) | Out-Null
    }

    foreach ($t in @($Fx.tickets)) {
        $n = $numbers[$t.key]
        if ($t.body -match '\{\w+\}') {
            $bf = New-BodyFile (Expand-Keys $t.body) $Dir "$($Fx.id)-$($t.key).final.md"
            Invoke-Gh @('issue', 'edit', "$n", '--repo', $Repo, '--body-file', $bf) | Out-Null
        }
        foreach ($b in @($t.blocked_by)) {
            $blockerId = Get-IssueDbId $numbers[$b]
            Invoke-Gh @('api', '--method', 'POST', "repos/$Repo/issues/$n/dependencies/blocked_by",
                '-F', "issue_id=$blockerId") | Out-Null
        }
        if ($t.assign) { Invoke-Gh @('issue', 'edit', "$n", '--repo', $Repo, '--add-assignee', '@me') | Out-Null }
        if ($t.comment) {
            $cf = New-BodyFile (Expand-Keys $t.comment) $Dir "$($Fx.id)-$($t.key).comment.md"
            Invoke-Gh @('issue', 'comment', "$n", '--repo', $Repo, '--body-file', $cf) | Out-Null
        }
        if ($t.close) { Invoke-Gh @('issue', 'close', "$n", '--repo', $Repo, '--reason', 'completed') | Out-Null }
    }

    [pscustomobject]@{ Map = $mapIssue; Numbers = $numbers; Created = @($created) }
}

function Remove-FixtureWorld([object[]]$Issues, [string]$Why) {
    foreach ($i in @($Issues)) {
        if (-not $i) { continue }
        Invoke-GhQuiet @('issue', 'close', "$($i.Number)", '--repo', $Repo, '--reason', 'not planned', '--comment', $Why)
    }
}

# ---------------------------------------------------------------- report

function Write-FixtureReport($Row) {
    $fired = if ($Row.Fired) { 'YES' } else { 'NO ' }
    Write-Host ''
    Write-Host "FIXTURE $($Row.Id)  -  $($Row.Branch)"
    Write-Host "  map          : $(if ($Row.MapUrl) { $Row.MapUrl } else { '(none - branch needs no map)' })"
    Write-Host "  invocation   : $($Row.Invocation -replace "`r?`n", ' / ')"
    Write-Host "  branch fired : $fired  $($Row.FiredWhy)"
    Write-Host "  skill loaded : $(if ($Row.Skills) { $Row.Skills -join ', ' } else { '(none)' })"
    Write-Host "  read         : $(if ($Row.Reads) { $Row.Reads -join ', ' } else { '(no skill file read)' })"
    Write-Host "  expected     : $(if ($Row.Expected) { $Row.Expected -join ', ' } else { '(none)' })"
    Write-Host "  missing      : $(if ($Row.Missing) { $Row.Missing -join ', ' } else { '(none)' })"
    Write-Host "  also touched : $(if ($Row.Unexpected) { $Row.Unexpected -join ', ' } else { '(none)' })"
    Write-Host "  run          : is_error=$($Row.IsError) cost=`$$($Row.Cost) turns=$($Row.Turns) transcript_lines=$($Row.TranscriptLines)"
    Write-Host "  artifacts    : $($Row.Dir)"
}

# ---------------------------------------------------------------- main

if ($Cleanup) {
    $open = & gh issue list --repo $Repo --label $FixtureLabel --state open --limit 200 --json number --jq '.[].number'
    $n = 0
    foreach ($num in @($open)) {
        if (-not "$num".Trim()) { continue }
        Invoke-GhQuiet @('issue', 'close', "$num", '--repo', $Repo, '--reason', 'not planned',
            '--comment', 'Fixture issue, closed by scripts/branch-harness.ps1 -Cleanup. Never real work.')
        $n++
    }
    Write-Host "Closed $n open $FixtureLabel issue(s) in $Repo."
    return
}

$roots = Get-SkillRoots
Write-Host "Caesar skill roots under observation:"
$roots | ForEach-Object { Write-Host "  $_" }

# NOT $all - PowerShell is case-insensitive, so that assignment writes the [switch]$All
# parameter and dies converting an array to a bool.
$allFixtures = @(Get-Fixtures)
$selected = if ($All) { $allFixtures } else { @($allFixtures | Where-Object { $_.id -eq $Fixture }) }
if (-not $selected) { throw "No fixture with id '$Fixture' in $FixtureDir. Have: $(($allFixtures.id) -join ', ')" }

Assert-FixtureLabel

$runId = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir = Join-Path $RepoPath ".claude\caesar-runs\branch-harness\$runId"
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

$rows = foreach ($fx in $selected) {
    $dir = Join-Path $runDir $fx.id
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-Host "`n=== $($fx.id): $($fx.branch) ==="

    $world = New-FixtureWorld $fx $dir
    $mapUrl = if ($world.Map) { $world.Map.Url } else { $null }
    $invocation = $fx.invocation
    if ($mapUrl) { $invocation = $invocation -replace '\{map_url\}', $mapUrl }
    foreach ($k in $world.Numbers.Keys) {
        $invocation = $invocation -replace ("\{" + [regex]::Escape($k) + "\}"), "#$($world.Numbers[$k])"
    }

    Write-Host "  staged: $(@($world.Created).Count) fixture issue(s). Driving a session..."
    $run = Invoke-FixtureSession -Invocation $invocation -Dir $dir -Slug $fx.id

    $obs = Read-TranscriptReads $run.Transcript $roots
    $final = if ($run.Result) { [string]$run.Result.result } else { '' }

    $hit = @()
    foreach ($m in @($fx.expect_markers)) { if ($final -imatch $m) { $hit += $m } }
    $fired = ($hit.Count -eq @($fx.expect_markers).Count) -and @($fx.expect_markers).Count -gt 0

    $expected = @($fx.expect_reads)
    $row = [pscustomobject]@{
        Id              = $fx.id
        Branch          = $fx.branch
        MapUrl          = $mapUrl
        Invocation      = $invocation
        Fired           = $fired
        FiredWhy        = "$($hit.Count)/$(@($fx.expect_markers).Count) marker(s) matched"
        Skills          = $obs.Skills
        Reads           = $obs.Reads
        Expected        = $expected
        Missing         = @($expected | Where-Object { $obs.Reads -notcontains $_ })
        # Everything else the session opened inside the skill directory. Not a failure -
        # a frozen script run out of the skill folder lands here - but it is the column
        # that would show a pointer firing that no fixture predicted.
        Unexpected      = @($obs.Reads | Where-Object { $expected -notcontains $_ -and $_ -ne 'SKILL.md' })
        IsError         = if ($run.Result) { $run.Result.is_error } else { 'no-result' }
        Cost            = if ($run.Result) { [math]::Round([double]$run.Result.total_cost_usd, 2) } else { 0 }
        Turns           = if ($run.Result) { $run.Result.num_turns } else { 0 }
        TimedOut        = $run.TimedOut
        TranscriptLines = $obs.Lines
        Transcript      = $run.Transcript
        FixtureIssues   = @($world.Created | ForEach-Object { $_.Number })
        Dir             = $dir
        FinalText       = $final
    }

    if (-not $KeepFixtures) {
        Remove-FixtureWorld $world.Created 'Fixture issue, closed by scripts/branch-harness.ps1 after the run. Never real work.'
    }

    Write-FixtureReport $row
    $row
}

$reportFile = Join-Path $runDir 'report.json'
[IO.File]::WriteAllText($reportFile,
    ($rows | Select-Object * -ExcludeProperty FinalText | ConvertTo-Json -Depth 6),
    (New-Object Text.UTF8Encoding $false))

Write-Host ''
Write-Host '================ per-branch summary ================'
$rows | Format-Table Id, Fired, @{n='Read';e={ if ($_.Reads) { $_.Reads -join ',' } else { '-' } }},
    @{n='Expected';e={ if ($_.Expected) { $_.Expected -join ',' } else { '-' } }},
    @{n='Missing';e={ if ($_.Missing) { $_.Missing -join ',' } else { '-' } }},
    Cost, IsError -AutoSize
Write-Host "report: $reportFile"
Write-Host "blind spots: docs/harness-blind-spots.md  -  read it before quoting any of this."
