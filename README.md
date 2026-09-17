# Caesar

A Claude Code skill that drives a [Wayfinder](https://github.com/mattpocock/skills) map
for you. You talk to one session; Caesar works through the map's tickets, running the
hands-off ones itself as background agents and pulling you in only for the tickets that
need a human (grilling and prototype work).

## Quickest setup: let Claude Code do it

Open Claude Code and paste:

```
Set up Caesar for me: https://github.com/Dhillvn/caesar
```

### Instructions for Claude Code

If you are Claude Code setting Caesar up for a user, follow these steps in order:

1. **Check the platform.** Caesar runs on Windows only. On any other OS, stop and tell the
   user.
2. **Clone to a permanent folder:** `git clone https://github.com/Dhillvn/caesar.git
   "$env:USERPROFILE\caesar"`. The install links to this folder, so never clone into a
   temp or session directory. If the folder already exists, run
   `git -C "$env:USERPROFILE\caesar" pull` instead.
3. **Script permission.** Run `Get-ExecutionPolicy`. If it returns `Restricted` or
   `AllSigned`, ask the user, then run
   `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force`. Caesar's scripts cannot
   run without it.
4. **Install:** `powershell -NoProfile -ExecutionPolicy Bypass -File
   "$env:USERPROFILE\caesar\install.ps1"`.
5. **Fix every warning it prints, then run step 4 again until there are none:**
   - Git or GitHub CLI missing: ask the user, then run
     `winget install --id Git.Git -e` or `winget install --id GitHub.cli -e`. Installing
     changes PATH, so the user may need to restart Claude Code.
   - GitHub CLI not logged in: this login is interactive, so you cannot do it. Ask the
     user to type `! gh auth login` in the prompt.
   - Wayfinder missing: run `claude plugin marketplace add mattpocock/skills`, then
     `claude plugin install mattpocock-skills@mattpocock`.
6. **Hand over.** Show the user the safety note under *Before you install*, then tell
   them to start with `/caesar <map-issue-url>`, or `/caesar <an idea>` to chart a new
   map. If `/caesar` is not recognised, restart Claude Code.

## Before you install

Caesar is **Windows-only** (PowerShell scripts, Windows junctions). You need:

- [Claude Code](https://claude.com/claude-code), with the `claude` command on your PATH
- [Git](https://git-scm.com/)
- [GitHub CLI](https://cli.github.com/), logged in: `gh auth login`
- The Wayfinder skill, from Matt Pocock's plugin:
  ```powershell
  claude plugin marketplace add mattpocock/skills
  claude plugin install mattpocock-skills@mattpocock
  ```
- PowerShell allowed to run local scripts (one time, no admin needed):
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
  ```

The installer checks these and warns about anything missing.

> **Read this before your first run.** Caesar launches background agents with
> `--permission-mode bypassPermissions`: they run commands without asking you. A short
> deny list blocks merging, force-pushing, `rm -rf` and reading credentials, and each
> agent works in its own git worktree, but Claude Code has no sandbox on Windows. Each
> agent is capped at $5 of API spend by default, and up to 4 run at once. Try it on a
> throwaway repo first.

## Install

```powershell
git clone https://github.com/Dhillvn/caesar.git
cd caesar
.\install.ps1
```

This links `~\.claude\skills\caesar` to the `skill\` folder in your clone, so a `git pull`
updates Caesar with no reinstall. It also adds a `caesar-centre` command. No admin rights
and no restart needed. It is safe to run again; run it again if you move the folder.

To remove it: `.\install.ps1 -Uninstall`.

## Use

From inside the repo that owns the map, in Claude Code:

```
/caesar https://github.com/<owner>/<repo>/issues/<map-number>
```

No map yet? `/caesar <your idea in a sentence>` charts one first.

- `status` in the session shows where every ticket stands.
- `caesar-centre` (any terminal) opens a live dashboard of every map you are driving;
  `caesar-centre stop` stops it. It finds maps owned by your GitHub login that carry the
  `caesar:driving` label.
- Nothing reaches your `main` branch without your say-so: work lands as pull requests,
  and Caesar merges only when you tell it to.

**Optional — run log on your phone.** Create a secret gist, then set its id once:
`setx CAESAR_GIST_ID <gist-id>`. Without it, run logs stay local.

The skill was written by its author for himself, so it calls the user "Raj". It works the
same for anyone.

## Layout

| Path | What |
|---|---|
| `skill/SKILL.md` | The judgment layer — which ticket to take, when to interrupt, the merge gate |
| `skill/scripts/frontier.ps1` | Frozen: one-GraphQL-call frontier sweep of a map |
| `skill/scripts/spawn-ticket-agent.ps1` | Frozen: fire one headless ticket agent, worktree + deny list |
| `skill/scripts/remove-worktree.ps1` | Frozen: fail-closed worktree teardown |
| `skill/scripts/status.ps1` | The status view — renders over the sweep, no query of its own |
| `skill/scripts/publish-runs.ps1` | Renders every discovered `.claude\caesar-runs\` directory into the private run-log gist, one file per repo |
| `install.ps1` | The junction install |
| `docs/research/` | Prior-art and measurement write-ups |

The three scripts are **frozen** because each is a command whose safety is a flag that
improvisation can silently drop. Judgment stays prose; these do not.

## License

MIT - see [LICENSE](LICENSE).
