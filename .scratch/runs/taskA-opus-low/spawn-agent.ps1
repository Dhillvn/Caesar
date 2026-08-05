<#
.SYNOPSIS
  Spawn one headless agent against a ticket.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$TicketUrl,
    [Parameter(Mandatory = $true)][string]$WorktreePath,
    [double]$BudgetUsd = 5.0
)

$ErrorActionPreference = 'Stop'

$runDir = Join-Path $WorktreePath '.claude\caesar-runs'
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$promptFile = Join-Path $runDir "$stamp.prompt.txt"
$outFile = Join-Path $runDir "$stamp.json"
$errFile = Join-Path $runDir "$stamp.stderr.txt"

$prompt = @"
You are a Wayfinder ticket agent working ticket $TicketUrl.

Read your ticket first and follow it exactly. Open a draft PR and stop.
"@

# The prompt travels to the CLI as a file on stdin, never as an argument.
[IO.File]::WriteAllText($promptFile, $prompt)

$denyList = "Bash(git push:*) Bash(rm:*) Bash(gh pr merge:*)"

$args = @(
    '-p'
    '--output-format', 'json'
    '--max-budget-usd', $BudgetUsd
    '--disallowedTools', $denyList
)

Start-Process -FilePath 'claude' -ArgumentList $args `
    -WorkingDirectory $WorktreePath `
    -RedirectStandardInput $promptFile `
    -RedirectStandardOutput $outFile `
    -RedirectStandardError $errFile `
    -NoNewWindow -Wait

$result = Get-Content $outFile -Raw | ConvertFrom-Json
[pscustomobject]@{
    Ticket = $TicketUrl
    Cost   = $result.total_cost_usd
    Turns  = $result.num_turns
}
