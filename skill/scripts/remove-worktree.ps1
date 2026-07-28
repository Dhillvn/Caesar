<#
.SYNOPSIS
  Frozen worktree teardown. Fail-closed: refuses to delete a worktree holding
  uncommitted changes or unpushed commits.

.DESCRIPTION
  Frozen because the dangerous version of this command is one word shorter than the
  safe one. `git worktree remove --force` on a worktree an agent died inside destroys
  the only copy of its work, and issue #8's rule is explicit: silent loss of work is
  worse than a stale directory.

  Returns an object; it never throws on a refusal. Removed=$false plus a Reason is the
  expected outcome for a crashed agent, not an error. Report a leftover to Raj exactly
  once, and with the ticket's resolution attached  -  "there is a folder here" is
  unactionable and counts as a bug in Caesar (#8).

.EXAMPLE
  .\remove-worktree.ps1 -RepoPath C:\Users\rajdh\Projects\caesar -WorktreeName ticket-17-4821
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [Parameter(Mandatory = $true)][string]$WorktreeName
)

$ErrorActionPreference = 'Stop'

$wt = Join-Path $RepoPath ".claude\worktrees\$WorktreeName"

function New-Verdict($removed, $reason) {
    [pscustomobject]@{
        WorktreeName = $WorktreeName
        WorktreePath = $wt
        Removed      = $removed
        Reason       = $reason
    }
}

if (-not (Test-Path $wt)) { return New-Verdict $true 'already gone' }

# Guard 1  -  uncommitted work, including untracked files an agent was mid-write on.
$dirty = @(git -C $wt status --porcelain)
if ($dirty.Count -gt 0) {
    return New-Verdict $false "$($dirty.Count) uncommitted change(s)  -  kept"
}

# Guard 2  -  commits that exist nowhere else. No upstream counts as unpushed unless the
# branch is identical to something already on the remote, so the default is to keep.
$branch = (git -C $wt rev-parse --abbrev-ref HEAD).Trim()
$unpushed = @(git -C $wt log --format='%h' HEAD --not --remotes)
if ($unpushed.Count -gt 0) {
    return New-Verdict $false "$($unpushed.Count) unpushed commit(s) on '$branch'  -  kept"
}

# Clean. `--worktree` creates the worktree locked, so the unlock is not optional:
# `git worktree remove` fails outright on a locked worktree.
#
# PowerShell 5.1 turns a native command's stderr into a terminating ErrorRecord under
# ErrorActionPreference = Stop, so the two commands allowed to fail harmlessly (an
# already-unlocked worktree, an absent auto-branch) are run with it relaxed and are
# judged on $LASTEXITCODE instead.
$ErrorActionPreference = 'Continue'

git -C $RepoPath worktree unlock $wt *> $null
git -C $RepoPath worktree remove $wt *> $null
if ($LASTEXITCODE -ne 0) { return New-Verdict $false 'git worktree remove failed  -  kept' }

# Delete the throwaway auto-branch only. -d refuses an unmerged branch, which is the
# same fail-closed posture as the guards above; the agent's real renamed branch lives
# on the remote behind its PR and is not ours to bin.
$autoBranch = "worktree-$WorktreeName"
git -C $RepoPath branch -d $autoBranch *> $null

New-Verdict $true 'clean  -  removed'
