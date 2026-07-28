# Spawn capabilities of a single Claude Code session on Windows

Research for [issue #2](https://github.com/Dhillvn/caesar/issues/2) (part of map [#1](https://github.com/Dhillvn/caesar/issues/1)). Ground truth only — no recommendation, no decision.

Sources: `claude --help`, `claude -p --help`, `claude agents --help` run locally (Windows 11, native install, version not pinned here — run `claude --version` to check at read time), plus current Claude Code docs at `code.claude.com/docs/en/*` (fetched 2026-07-28; `docs.claude.com/en/docs/claude-code/*` 301-redirects there, so that's the same content, not a second source). Every claim below is tagged with where it came from. Anything not confirmed against one of these is marked **UNVERIFIED**.

---

## 1. The Agent/subagent tool

**Concurrency limits** — three independent caps ([sub-agents doc](https://code.claude.com/docs/en/sub-agents#session-subagent-limit)):

- **Session total**: 200 subagents per session by default (`CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION` to raise; no upper bound but can't be disabled; requires v2.1.212+). `/clear` resets the counter.
- **Concurrent**: 20 running at once by default (`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`; requires v2.1.217+). Exceeding it fails the `Agent` call with `Concurrent subagent limit reached` and Claude is told not to retry; it clears once a slot frees up. Sessions with "ultracode" effort are exempt.
- **Depth**: subagents can spawn subagents up to 3 layers below the main conversation by default (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`, requires v2.1.217+; set to 1 to disable nesting entirely). At the limit, Claude Code withholds the `Agent` tool from every subagent except a fork.

**Can a subagent spawn its own subagents?** Yes, by default, up to the depth limit above. A subagent's own `tools` field can restrict this (omit `Agent` or add it to `disallowedTools`). A `coordinator`-style subagent running as the main thread (`claude --agent`) can additionally scope *which* subagent types it's allowed to spawn via `Agent(worker, researcher)` allowlist syntax in its own `tools` field — but that allowlist syntax only applies when the agent itself is the main thread, not to an ordinary spawned subagent.

**How results return:**
- Foreground subagents block the main conversation and return their result directly when they finish.
- Background subagents (the default since v2.1.198) run concurrently; "a background subagent's results reach Claude as a completion notification in a later turn" — Claude waits for that notification before reporting results, and will say "still running" if asked before it lands.
- Every subagent's final report passes through an output-scanning step before Claude reads it (backslash-escapes anything that imitates a `<system-reminder>` tag or `Human:`/`Assistant:` line; prepends a `[harness: ...]` marker line if the report imitates instruction-shaped content or mentions permission bypass flags). This doesn't change what a tool call can do — normal permission checks still apply.
- A fork (`/subtask`, or Claude requesting the `fork` subagent type when `CLAUDE_CODE_FORK_SUBAGENT=1`) inherits the *entire* parent conversation instead of starting fresh, and its result likewise returns as a single message when done.

**Can a subagent be resumed later with context intact?** Yes, with caveats:
- Named/custom subagents and `general-purpose` return an **agent ID** on completion; resuming (Claude sends via `SendMessage` with that ID or name as `to`) restores full conversation history — all prior tool calls, results, reasoning — and the subagent "picks up exactly where it stopped."
- The built-in `Explore` and `Plan` subagents are one-shot and return **no agent ID** — they cannot be resumed. Use `general-purpose` or a custom subagent if resumability matters.
- A subagent you stopped yourself (`x` in `/tasks`, or SDK `stop_task`) does **not** auto-resume on a later `SendMessage` (as of v2.1.191) — it needs a manual nudge in its transcript first.
- Subagent transcripts live at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`, are unaffected by main-conversation compaction (separate files), persist across a Claude Code restart (resume the same session), and are garbage-collected per `cleanupPeriodDays` (default 30 days).
- `SendMessage` also carries ordinary "mid-task course corrections" from whichever agent sent it, but two things never change via an agent message: no agent message counts as your (the human's) approval for a pending permission prompt, and no agent message can alter a subagent's permission settings, CLAUDE.md, or configuration.

---

## 2. Background tasks

Two distinct things share the phrase "background" — worth not conflating (per [sub-agents doc](https://code.claude.com/docs/en/sub-agents#run-subagents-in-foreground-or-background) and [agent-view doc](https://code.claude.com/docs/en/agent-view)):

**(a) Background subagents** (inside one session): launched automatically (default since v2.1.198) or by asking Claude / pressing Ctrl+B. Output does not appear in the parent's context as it happens — Claude gets a completion notification on a later turn, as above. These do **not** survive the parent session ending; they're part of that session's process.

**(b) Background *sessions*** (`claude agents`, `claude --bg`, `/bg`, `/fork`): a fully separate, independently supervised Claude Code process.
- **How launched**: `claude --bg "prompt"`, `claude agents` (interactive dashboard, type a prompt), `/bg`/`/background` (move current session to background), `/fork` (copy conversation to a new background session while the original keeps running), `claude --agent <name> --bg "prompt"` for a specific subagent definition, `--name` to label it.
- **Concurrency**: no built-in limit, but every background session consumes the same subscription-quota rate limit as an interactive session — 10 running in parallel burns quota ~10x faster than 1.
- **Parent notification**: `claude agents` dashboard polls/refreshes a one-line status summary every ~15 seconds per session and shows state (Working / Needs input / Completed / Failed). Scriptable via `claude agents --json` (add `--all` to include completed ones), which returns `id`, `state` (`working`/`blocked`/`done`/`failed`/`stopped`), `pid`, `waitingFor`, `sessionId`, `name`, `cwd`, `startedAt`.
- **Output isolation**: confirmed — "Dispatched sessions run independently; output doesn't appear in parent context."
- **Survives parent session ending**: confirmed, explicitly — "Background sessions don't need any terminal open to keep working. A separate supervisor process runs them, so you can close agent view, close your shell, or start a new interactive session and your dispatched work keeps going." A per-user supervisor process hosts all background sessions.
- **State on disk**: `~/.claude/jobs/<id>/state.json`, `~/.claude/jobs/<id>/tmp/`, `~/.claude/daemon/roster.json`. Sessions survive machine sleep but not shutdown; the supervisor reconnects after a restart; idle sessions auto-stop after ~1 hour unless pinned (Ctrl+T).
- **Reading results back into another session**: `claude attach <id>` (take over the terminal), `claude logs <id>` (print recent output — this is the mechanism another Claude Code session could shell out to, to read a background job's output as text/Bash output), `claude respawn <id>`, `claude stop <id>`, `claude rm <id>`.
- Confirmed from `claude agents --help` (run locally): flags carried into dispatched sessions include `--add-dir`, `--agent`, `--effort`, `--mcp-config`, `--model`, `--permission-mode`, `--plugin-dir`, `--setting-sources`, `--settings`, `--strict-mcp-config`, `--dangerously-skip-permissions` (alias for `--permission-mode bypassPermissions`), `--allow-dangerously-skip-permissions`, `--json`/`--all`/`--cwd` for scripted listing.
- **`claude -p` and background Bash**: if a `claude -p` run starts a background Bash task (e.g. a dev server), that shell is killed ~5 seconds after Claude returns its final result and stdin closes (grace period so a task finishing just after still delivers output; fixed in v2.1.163 — before that, a never-exiting background process held the invocation open forever). Background **subagents** and workflows are exempt from that 5-second grace — `claude -p` waits for them to finish, capped at 10 minutes by default from v2.1.182 (`CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS`, `0` = unlimited).

---

## 3. Headless `claude -p`

Full flag surface confirmed by running `claude -p --help` locally (identical flag set to `claude --help`, since `-p` is a flag not a subcommand):

- **Output formats** (`--output-format`, only with `-p`): `text` (default), `json` (single result — includes `session_id`, `result`, `total_cost_usd`, per-model cost breakdown), `stream-json` (newline-delimited JSON events). `--json-schema '<schema>'` alongside `--output-format json` validates/shapes the response into a `structured_output` field; an invalid schema makes `claude` exit with `Error: --json-schema is not a valid JSON Schema`.
- **`--resume`/`-r [value]`**: resume by session ID or name, or open an interactive picker if no value given. ID lookup is scoped to the current project directory and its git worktrees. **`--continue`/`-c`**: resume the most recent conversation in the current directory. **`--fork-session`**: when resuming, mint a new session ID instead of reusing the original. Capture a session ID for later resume: `session_id=$(claude -p "..." --output-format json | jq -r '.session_id')`.
- **`--permission-mode <mode>`**: `default`/`manual` (alias, v2.1.200+), `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan`.
- **`--append-system-prompt <prompt>`**: appends to the default system prompt (there's also `--system-prompt` to replace it wholesale, and file variants `--append-system-prompt-file`/`--system-prompt-file` per the docs, though these weren't visible verbatim in the local `--help` output — **UNVERIFIED** file-flag names, but the behavior of `--append-system-prompt` itself is confirmed both locally and in docs).
- **`--mcp-config <configs...>`**: load MCP servers from JSON files or inline strings, space-separated. **`--strict-mcp-config`**: only use servers from `--mcp-config`, ignoring everything else (`.mcp.json`, settings, etc.).
- **`--bare`**: recommended mode for scripted/SDK calls — skips hooks, LSP, plugin sync, auto-memory, CLAUDE.md auto-discovery, keychain reads; forces `ANTHROPIC_API_KEY`/`apiKeyHelper` auth only (no OAuth/keychain). Reduces startup latency; "will become the default for `-p` in a future release" per docs.
- **`--max-turns`**, **`--max-budget-usd`**: budget/turn caps for `-p` runs.
- **Exit codes** — only partially documented, not a full table:
  - `0` success.
  - `1` general failure; also returned by `claude auth status` when logged out; also on hitting `--max-turns`; also when `--max-budget-usd` is hit and spawning another subagent would exceed it.
  - `143` when the `claude -p` process is stopped via SIGTERM (e.g. `kill`, a supervisor, or an SDK host closing the session) — Claude Code aborts the in-progress turn, kills the process tree of any running Bash command, runs `SessionEnd` hooks, then exits 143.
  - No other exit codes are enumerated in current docs — **UNVERIFIED / incomplete** beyond these.
- **Can a session shell out to `claude -p` and read structured JSON back?** Yes, confirmed pattern from docs: `claude -p "Summarize this project" --output-format json | jq -r '.result'`, or with `--json-schema` for a typed `structured_output` field. This is exactly a Bash tool call from within a session (`claude -p ... | jq ...`) — nothing special is needed on the calling side.
- **Piped stdin**: capped at 10MB (v2.1.128+) — over that, `claude -p` exits non-zero with an error; write large input to a file and reference the path instead. Before v2.1.211, unreadable stdin on Windows could crash the session or exit silently with no output — now prints a warning to stderr and continues from the CLI-arg prompt.
- **Rough token cost vs. a subagent — UNVERIFIED, no primary-source number found.** Directionally: a subagent inherits the parent's system prompt/tools/CLAUDE.md context already loaded (cheap to add), and non-fork subagent output only returns a summary to the parent's context. A fresh `claude -p` shell-out starts an entirely new process that reloads CLAUDE.md, skills, and (unless `--bare`) hooks/MCP from scratch — separate token accounting, separate context window, no shared prompt cache with the calling session (prompt cache is shared between a *fork* and its parent per the sub-agents doc, but a `claude -p` subprocess is not a fork). No documented figure quantifies the delta; this needs a live smoke test (e.g. compare `total_cost_usd` from a `claude -p --output-format json` call against a subagent's reported cost) to get a real number, not training-data recall.

---

## 4. Hooks

Source: fetched summary of `code.claude.com/docs/en/hooks` (WebFetch synthesis of the live page, not a verbatim quote — treat field names as reliable, prose framing as paraphrase) cross-checked against the sub-agents doc's hook sections, which quote the docs directly.

- **SessionStart**: fires on new session, `--resume`/`--continue`/`/resume` (matcher `resume`), `/clear` (matcher `clear`), after compaction (matcher `compact`), or a forked session (matcher `fork`). Receives `session_id`, `transcript_path`, `cwd`, `source`, optionally `model`/`agent_type`/`session_title`. Only `command` and `mcp_tool` hook types are supported here (no `prompt`/`agent` types). Can return `additionalContext`, `sessionTitle`, `initialUserMessage`, `watchPaths`, `reloadSkills` — these get injected/replayed but there's no generic "read arbitrary state" mechanism beyond what the hook script itself does.
- **Stop**: fires once per turn when Claude finishes responding. Can block Claude from stopping (exit code 2 or `decision: "block"`) or inject `additionalContext` for that turn only. On resume/continue, the *saved* injected text is replayed rather than the hook re-running.
- **SubagentStop**: fires once per subagent completion, matchable by agent type name (including plugin-scoped `my-plugin:reviewer`, anchor with `^...$` for exact match pre-v2.1.195-style safety). Can block the subagent from stopping, or inject `additionalContext` into the **parent** conversation — this is the one hook event that explicitly forwards feedback from child to parent, but only as an injected text blurb for that turn, not a general data channel. Per the sub-agents doc, `Stop` hooks defined in a subagent's own frontmatter are automatically converted to `SubagentStop` at runtime.
- **Notification**: fires on permission prompts, idle alerts, auth success, elicitation, `agent_needs_input`, `agent_completed`, etc. Side-effect only (log, desktop notification, terminal bell) — no state carries forward into the conversation.
- **Can a hook write a file a parent session later reads?** Yes — a hook is just a shell command with normal filesystem access, so it can write anywhere on disk. What it *cannot* do is hand that file's content directly back into a running conversation's context automatically; the *reading* side has to be deliberate: either the file is read back by a later `SessionStart` hook (e.g. into `additionalContext`) or a session/subagent reads it explicitly with the Read/Bash tool. There's no automatic "hook output becomes context in the next session" wiring beyond `SessionStart`'s `additionalContext`/`initialUserMessage` fields.
- **Windows note on hooks**: per the sub-agents doc's `PreToolUse` example, "On Windows, write hook scripts in PowerShell and add `shell: powershell` to the hook entry" — a bash-shebang hook script isn't guaranteed to run without Git Bash present; PowerShell is the documented cross-Windows-install-mode path.

---

## 5. Windows specifics — what assumes POSIX shell, tmux, or symlinks

From `code.claude.com/docs/en/setup` and cross-references:

- **Shells**: native Windows Claude Code needs *either* PowerShell/CMD *or* Git for Windows (for Git Bash/the Bash tool). Without Git for Windows, Claude Code falls back to the **PowerShell tool** for shell commands instead of Bash. Raj has Git Bash, so the Bash tool is available — but any doc example written as a POSIX one-liner (`chmod +x`, `$(cmd)` command substitution assuming bash semantics, `jq` piping) needs Git Bash specifically, not vanilla CMD/PowerShell.
- **Sandboxing**: **not supported on native Windows at all** — only WSL 2 supports it (WSL 1 and native Windows both show "Not supported" in the docs' comparison table). Anything gated behind Claude Code's sandboxing feature (isolated command execution) is unavailable to a native-Windows session; only WSL 2 gets it.
- **tmux**: the `--tmux` flag exists but requires `--worktree`, and "Uses iTerm2 native panes when available; use `--tmux=classic` for traditional tmux" (from local `claude --help`) — this is explicitly a macOS/iTerm2-first feature with a `tmux` binary fallback. Raj has no tmux on Windows, so `--tmux` is very likely non-functional or unavailable to him — **not directly stated as "unsupported on Windows" in docs, so flagged UNVERIFIED rather than asserted**; a cheap smoke test (`claude --worktree --tmux` and read the error) would confirm.
- **Symlinks**: not mentioned as a live blocker in the docs pages read for this ticket, but the update-mechanism docs note that on macOS/Linux the native installer manages `~/.local/bin/claude` "as a symlink into `~/.local/share/claude/versions/`" — that specific mechanism is POSIX-only phrasing; the Windows uninstall/install instructions use plain `Remove-Item`/binary paths instead (`$env:USERPROFILE\.local\bin\claude.exe`), implying Windows native install does **not** rely on a symlink launcher the way macOS/Linux do. No other symlink dependency was found in the pages read — **not exhaustively verified**, since worktree/plugin internals weren't inspected for symlink use.
- **Git Bash path**: if Claude Code can't auto-find Git Bash, set `CLAUDE_CODE_GIT_BASH_PATH` in `settings.json` (`env` block) — relevant if Raj's install can't locate it automatically.
- **Background agents / `claude agents`**: nothing in the fetched agent-view doc is flagged as POSIX-only; sessions are described as local processes with a per-user supervisor, and the doc's own examples are OS-agnostic. Not explicitly confirmed working on native Windows vs. only WSL, though — **UNVERIFIED**, worth a direct smoke test (`claude --bg "echo hi"` then `claude agents --json`) before relying on it in Caesar.

---

## Open / unverified items (do not treat as ground truth without a follow-up check)

1. Exact token/cost delta between a `claude -p` shell-out and an in-session subagent — no documented number; needs a live smoke test comparing `total_cost_usd`.
2. Whether `--tmux` / `--worktree --tmux` errors cleanly or partially works on native Windows with no tmux binary installed.
3. Whether `claude agents` / background sessions have any Windows-specific degradation (supervisor process behavior wasn't tested locally, only read from docs).
4. `--append-system-prompt-file` / `--system-prompt-file` flag names — mentioned in the headless doc's `--bare` table but not seen verbatim in the local `--help` output; possibly gated behind a version newer than what's installed, or docs paraphrase. Confirm with `claude --help | grep system-prompt` against the installed version at implementation time.
5. Full enumerated exit-code table for `claude -p` beyond `0`, `1`, `143` — docs only give conditions, not a complete list.
