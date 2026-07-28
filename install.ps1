<#
.SYNOPSIS
  Installs Caesar as a global Claude Code skill by junctioning ~/.claude/skills/caesar
  onto this repo's skill source. Idempotent and safe to re-run.

.DESCRIPTION
  A junction, not a copy: ~/.claude is not a git repo, so a copied Caesar would be
  untracked and every edit would need the install re-run  -  guaranteed drift (issue #11).

  Verified on Windows 11: New-Item -ItemType Junction needs no admin (unlike a symlink,
  which needs elevation or Developer Mode), and Claude Code picks a junctioned skill up
  live, with no restart.

  Refuses to touch a real directory at the target. Re-points an existing junction.

.EXAMPLE
  pwsh -File .\install.ps1
  pwsh -File .\install.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [string]$LinkPath = (Join-Path $env:USERPROFILE '.claude\skills\caesar'),
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$source = Join-Path $PSScriptRoot 'skill'
if (-not $Uninstall -and -not (Test-Path (Join-Path $source 'SKILL.md'))) {
    throw "No SKILL.md at $source  -  run this from the Caesar repo root."
}

$existing = Get-Item -LiteralPath $LinkPath -Force -ErrorAction SilentlyContinue
$isJunction = $existing -and $existing.LinkType -eq 'Junction'

if ($Uninstall) {
    if (-not $existing) { Write-Host "Not installed: $LinkPath"; return }
    if (-not $isJunction) { throw "REFUSED: $LinkPath is a real directory, not our junction. Delete it yourself if you mean to." }
    [System.IO.Directory]::Delete($LinkPath)
    Write-Host "Uninstalled: removed junction $LinkPath"
    return
}

if ($existing) {
    if (-not $isJunction) {
        throw "REFUSED: $LinkPath already exists as a real directory. Move or delete it, then re-run."
    }
    # .Target is an array on some PowerShell versions. Resolve it with -ErrorAction
    # SilentlyContinue: a junction whose target has been deleted still exists and still
    # reports a Target, but Resolve-Path throws on it. That dangling state is the normal
    # post-merge case - tearing down the worktree the junction pointed at produces it -
    # so it must re-point, not blow up.
    $target = @($existing.Target)[0]
    $targetResolved = if ($target) { (Resolve-Path $target -ErrorAction SilentlyContinue).Path } else { $null }
    if ($targetResolved -and $targetResolved -eq (Resolve-Path $source).Path) {
        Write-Host "Already installed: $LinkPath -> $source"
        return
    }
    if ($targetResolved) { Write-Host "Re-pointing existing junction (was: $target)" }
    else { Write-Host "Re-pointing dangling junction (target gone: $target)" }
    [System.IO.Directory]::Delete($LinkPath)
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $LinkPath) | Out-Null
New-Item -ItemType Junction -Path $LinkPath -Target $source | Out-Null
Write-Host "Installed: $LinkPath -> $source"
Write-Host "Claude Code loads junctioned skills live. Run /caesar <map-url> to check."
