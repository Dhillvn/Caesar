<#
.SYNOPSIS
  Frozen spawn. Fires one headless `claude -p` ticket agent in its own git worktree,
  permissive minus the deny list, capped by a dollar budget, and returns immediately.

.DESCRIPTION
  Frozen because this command's safety IS its flag set (issue #11). A session that
  composes it from prose can drop --disallowedTools, and an unattended agent with no
  one reading its output then has free rein on a machine with no sandboxing
  (Claude Code has none on native Windows  -  issue #2).

  Verified live on this repo before freezing:
    - --disallowedTools "Bash(rm -rf:*)" is enforced from the CLI, and the blocked
      call is reported in the result JSON's permission_denials.
    - It stays enforced under --permission-mode bypassPermissions, which is what
      makes "permissive minus a deny list" a single invocation with no settings.json.

  The caller does NOT wait. Poll the result file, and verify the work against GitHub
  (is the issue closed, does it carry a resolution comment)  -  never against the exit
  code, which issue #15 proved is a liar: a run that silently did nothing exits 0.

.EXAMPLE
  .\spawn-ticket-agent.ps1 -RepoPath C:\Users\rajdh\Projects\caesar `
      -TicketUrl https://github.com/Dhillvn/caesar/issues/17 -PromptFile .\prompt.txt
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [Parameter(Mandatory = $true)][string]$TicketUrl,
    [Parameter(Mandatory = $true, ParameterSetName = 'Inline')][string]$Prompt,
    [Parameter(Mandatory = $true, ParameterSetName = 'File')][string]$PromptFile,
    [string]$WorktreeName,
    [double]$BudgetUsd = 2.0
)

$ErrorActionPreference = 'Stop'

if ($TicketUrl -notmatch '/issues/(\d+)') { throw "Not a GitHub issue URL: $TicketUrl" }
$ticketNumber = $Matches[1]
if (-not (Test-Path (Join-Path $RepoPath '.git'))) { throw "Not a git repo: $RepoPath" }
if ($PromptFile) {
    if (-not (Test-Path $PromptFile)) { throw "No prompt file at $PromptFile" }
    $Prompt = Get-Content -Raw -LiteralPath $PromptFile
}
if (-not $WorktreeName) { $WorktreeName = "ticket-$ticketNumber-$(Get-Random -Maximum 9999)" }

# The deny list (issue #7). Short by design: it covers only what escapes git's safety
# net or crosses a locked boundary. The realistic threat is a confused agent, not a
# malicious one, and a confused agent reaches for `rm -rf`, not an obfuscated variant.
$denied = @(
    # Merge boundary  -  only Caesar merges, and only on Raj's explicit word (#6, #16).
    # The agent has no channel to receive that word, so this gate is structural.
    'Bash(gh pr merge:*)'
    'Bash(git merge:*)'
    'Bash(git push origin main:*)'
    'Bash(git push --force:*)'
    'Bash(git push -f:*)'
    'Bash(git push --force-with-lease:*)'
    # Unrecoverable  -  past the point git can undo it.
    'Bash(git reset --hard:*)'
    'Bash(git clean -fdx:*)'
    'Bash(rm -rf:*)'
    'Bash(gh repo delete:*)'
    'Bash(gh repo archive:*)'
    'Bash(gh api --method DELETE:*)'
    # Credentials.
    'Bash(gh auth token:*)'
    'Read(~/.ssh/**)'
    'Read(**/.env)'
)

$logDir = Join-Path $RepoPath '.claude\caesar-runs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$resultFile = Join-Path $logDir "$WorktreeName-$stamp.json"
$stderrFile = Join-Path $logDir "$WorktreeName-$stamp.err"
$promptPath = Join-Path $logDir "$WorktreeName-$stamp.prompt.txt"

# Carried in the prompt, not the permission layer: no permission specifier can express
# "don't write to the map issue", and Caesar is sole writer to the map body (#5).
$guardrail = @"
You are a Wayfinder ticket agent working ticket $TicketUrl.

Write ONLY to your own ticket ($TicketUrl) and to your own git branch. Never edit the
map issue body, and never edit another ticket. You cannot merge anything; open a draft
PR and stop.

When you are done, post your resolution as a comment on your ticket and close the
ticket yourself. Then print, as the last line of your reply, a single line starting
with 'GIST: '  -  30 to 60 words stating the answer. That sentence is what will
represent this decision on the map forever, so make it judgeable on its own.

--- ticket instructions follow ---
$Prompt
"@

# The prompt goes in on stdin, not as an argv element. It is multi-line, and
# Start-Process flattens -ArgumentList into a single command line, so a prompt passed
# as an argument gets shredded at its first newline ("error: unknown option").
Set-Content -LiteralPath $promptPath -Value $guardrail -Encoding UTF8

$claudeArgs = @(
    '-p'
    '--output-format', 'json'
    '--worktree', $WorktreeName
    '--permission-mode', 'bypassPermissions'
    '--max-budget-usd', $BudgetUsd
    '--disallowedTools'
) + $denied
# NOTE: --bare is banned (#7)  -  it forces API-key auth. Plain `claude -p` keeps
# subscription auth, which is what the cost measurement in #15 reflects.

# Every argument is quoted explicitly. Start-Process joins the array on spaces with no
# quoting of its own, and deny specifiers like 'Bash(rm -rf:*)' contain a space - so
# unquoted they split into two arguments and the rule silently stops matching. A deny
# list that fails open is worse than no deny list, because it looks present.
$cmdLine = ($claudeArgs | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ' '

$proc = Start-Process -FilePath 'claude' -ArgumentList $cmdLine `
    -WorkingDirectory $RepoPath -WindowStyle Hidden -PassThru `
    -RedirectStandardInput $promptPath `
    -RedirectStandardOutput $resultFile -RedirectStandardError $stderrFile

[pscustomobject]@{
    Ticket       = $TicketUrl
    WorktreeName = $WorktreeName
    WorktreePath = Join-Path $RepoPath ".claude\worktrees\$WorktreeName"
    ProcessId    = $proc.Id
    ResultFile   = $resultFile
    StderrFile   = $stderrFile
    PromptFile   = $promptPath
    BudgetUsd    = $BudgetUsd
}
