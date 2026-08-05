<#
.SYNOPSIS
  Pull the map body down, apply a decision bullet, push it back.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$MapUrl,
    [Parameter(Mandatory = $true)][string]$Decision
)

$ErrorActionPreference = 'Stop'

if ($MapUrl -notmatch '^https?://github\.com/([^/]+)/([^/]+)/issues/(\d+)') {
    throw "Not a GitHub issue URL: $MapUrl"
}
$owner = $Matches[1]
$repo = $Matches[2]
$num = [int]$Matches[3]

$work = Join-Path $env:TEMP "map-sync-$num"
New-Item -ItemType Directory -Force -Path $work | Out-Null
$bodyFile = Join-Path $work 'body.md'

# Fetch the current body so we can append to it.
$body = gh issue view $num --repo "$owner/$repo" --json body --jq .body
if ($LASTEXITCODE -ne 0) { throw "gh issue view failed for #$num" }
Set-Content -Path $bodyFile -Value $body -NoNewline

# Count the section headings so we can be sure the body arrived intact.
$existing = Get-Content $bodyFile
$headingCount = ([regex]::Matches($existing, '^## ')).Count
if ($headingCount -lt 1) {
    throw "Map #$num has no '## ' sections; refusing to write."
}

$updated = "$body`n- $Decision"

# Push the new body back to GitHub.
gh issue edit $num --repo "$owner/$repo" --body $updated
if ($LASTEXITCODE -ne 0) { throw "gh issue edit failed for #$num" }

# Confirm the write landed.
$after = gh issue view $num --repo "$owner/$repo" --json body --jq .body
if ($after -like "*$Decision*") {
    Write-Host "Map #$num updated."
} else {
    throw "Map #$num write did not land."
}
