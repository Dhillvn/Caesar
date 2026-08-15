# Driving a local Claude Code session from a phone — surface survey

Ticket: https://github.com/Dhillvn/caesar/issues/164
Surveyed: 2026-08-15. Every third-party claim below carries a URL fetched during that run.

## The question

Caesar runs on a Windows 11 box (8 cores, 15.7 GB) and spawns up to four concurrent
headless `claude -p` processes on it. That installation carries local skills, `gh` auth,
PowerShell scripts and a filesystem that nothing else has. So the deciding axis is not
"can I talk to Claude from my phone" — several things do that. It is **does this surface
reach *that* installation, or does it start something fresh and separate somewhere else.**

Everything here is judged from documentation. Nothing was provisioned, installed,
signed up for or configured.

## Comparison

Axes: **Reach** (does it drive the local Windows session?), **Cost**, **Auth/exposure**,
**Windows**, **Maturity**, **VPS portability** (does the same setup move to a Linux VPS later?).

| Candidate | Reach | Cost | Auth / exposure | Windows | Maturity | VPS portability |
|---|---|---|---|---|---|---|
| **Claude Code Remote Control** (`/remote-control`, attach from claude.ai/code or Claude mobile app) | **Full local.** "lets you use your full local environment, including your filesystem, tools, and project configuration… code execution and filesystem access stay on your machine" | Included in Pro $20/mo, Max from $100/mo; no extra charge | Anthropic account only; API keys unsupported. **Outbound HTTPS only, never opens inbound ports.** Traffic via Anthropic API over TLS; short-lived scoped credentials; transcript stored on Anthropic servers while connected | CLI supports "Windows 10 1809+"; the Remote Control page itself does not name an OS (see risks) | GA on Pro/Max/Team/Enterprise; first-party | Yes — same command on any host the CLI runs on |
| **Claude Code on the web** (claude.ai/code, `claude --cloud`) | **None.** Runs in "an isolated, Anthropic-managed VM" that clones "your current directory's GitHub remote at your current branch, not your local checkout" | Same subscription; "no separate compute charge for the cloud VM"; shares account rate limits | GitHub App or `/web-setup` token sync; credentials held outside the sandbox by a proxy | N/A (nothing runs locally) | Research preview for Pro/Max/Team | N/A — already remote, but it is *Anthropic's* remote, not yours |
| **Claude mobile app** (iOS/Android) | **Client only.** Attaches to Remote Control sessions and monitors cloud sessions; originates nothing local by itself | Included in the plan | Anthropic account | N/A | First-party | N/A |
| **Happy** (happy.engineering, slopus/happy) | **Full local.** "The AI coding agents run on computers you own… you can use Happy to control Claude Code on that machine"; "Works with vanilla Claude Code – Not a proprietary wrapper" | Free, MIT. "completely free… No usage limits… No user limits". Still needs your own Claude sub / API key | QR device pairing; both ends dial **out** to a relay, no port forwarding; "Encryption happens on your device before sending. Relay server only sees encrypted blobs"; relay self-hostable | Explicit: "Works on any computer (Mac, Windows, Linux)" | 23.4k stars, last push 2026-08-10, 971 open issues, MIT | Yes — CLI + self-hostable relay both run on Linux |
| **Telegram bridge** (RichardAtCT/claude-code-telegram, best-maintained found) | **Full local.** Wraps the local CLI and its auth: "Authenticate on your server with `gh auth login`, then work with repos conversationally" | Free, MIT | Bot token + `ALLOWED_USERS` whitelist, directory sandboxing; optional webhook server on port 8080. Telegram Bot API is **not** end-to-end encrypted | **Not stated.** Setup is Makefile + Poetry, Unix-oriented | 2.75k stars, last push 2026-03-30 (~4.5 mo stale), v1.3.0 | Yes — plain Python service |
| **SSH + phone terminal + persistent session** | **Full local** — if a persistent session exists | Termius Starter free / Pro $10 per mo; Blink is iOS-only and subscription-only; Tailscale Personal "free for individuals" | Keys; either a public SSH port or a Tailscale tailnet with no exposed port | OpenSSH Server is a supported Windows optional feature. **But tmux/screen are POSIX and the Microsoft-documented path is WSL2** — no native Windows detach/reattach was found | Mature and boring | Yes, and better there — tmux is native on Linux |
| **VS Code Remote Tunnels** | **Full local shell** on the host machine via vscode.dev's integrated terminal, usable from a mobile browser | Free | GitHub or Microsoft account; tunnel is outbound, no inbound port | Yes, explicitly | Mature, first-party Microsoft | Yes |
| **JetBrains Remote Dev / Gateway** | — | — | — | Windows *as remote host* not stated on the fetched pages | **No mobile client exists** per current vendor docs | — |
| **Vibe Kanban** (BloopAI/vibe-kanban) | Local — `npx vibe-kanban` drives locally-authenticated agents | Free, Apache-2.0 | OAuth (GitHub/Google) or local admin; ports 8081/8082 | Implied only (a Windows-specific `MCP_HOST` caveat exists); no explicit statement | **Sunsetting.** README banner: "Vibe Kanban is sunsetting." Last push 2026-04-24 | Docker Compose exists, but the project is ending |
| **omnara** (omnara-ai/omnara) | **Partial / fresh.** Agent-orchestration platform; can "connect your own laptop or VM" as a Machine, but the agent is defined through Omnara's own config rather than attaching to an existing `claude` session | Free tier $0 platform fee, hosted machines from $0.0414/GiB-hour, bring your own model keys | Self-host listens on localhost:8000, production needs `OMNARA_PUBLIC_URL`; no E2E encryption claimed | Not stated | 2.7k stars, pushed 2026-08-15, Apache-2.0 | Yes — Docker Compose |
| **ttyd** (extra) | Full local shell in a browser | Free, OSS | Whatever you put in front of it; it *is* a listening web server | Yes — `winget install tsl0922.ttyd` | Mature small tool | Yes |
| **code-server** (extra, ruled out) | — | — | — | "We currently do not publish Windows releases" | — | — |

## Verdict

Three real contenders, on the deciding axis:

1. **Claude Code Remote Control.** The only first-party surface that reaches the local
   installation, and the only one where the exposure question mostly disappears — the
   local process dials out, opens no inbound port, and there is no relay to trust beyond
   Anthropic, whom the session already trusts. Its costs are that the transcript lives on
   Anthropic servers while connected, that the local process must stay alive, and that
   it is one remote session per interactive process outside server mode — which matters
   for a Caesar that runs four at once.

2. **Happy.** The same reach, free, E2E-encrypted, explicitly Windows-supported, with a
   self-hostable relay — the strongest independent option and the one that survives if
   the first-party surface changes shape. Cost is a third-party relay in the path and
   971 open issues.

3. **SSH + a phone terminal, over Tailscale.** The most general and the least magical:
   it reaches everything on the box, not just Claude. Its problem is exactly the one the
   prior art never confronted — **session persistence on Windows.** tmux and screen are
   POSIX; the documented Windows route is WSL2, which is a different filesystem and a
   different `gh` auth from the one Caesar actually uses. Until that gap is closed with a
   real Windows answer, this contender is incomplete.

Ruled out and why: **Claude Code on the web** and **`--cloud`** fail the deciding axis by
construction — an Anthropic VM cloning the GitHub remote is exactly "something fresh and
separate somewhere else". **JetBrains** has no mobile client. **Vibe Kanban** is sunsetting.
**omnara** starts its own agent rather than attaching to yours. **code-server** does not
ship for Windows. The **Telegram bridge** does reach the local session, but it is 4.5
months stale, does not state Windows support, and rides a transport that is not E2E
encrypted — a fallback, not a contender.

Choosing between the three is ticket work with Raj, not this document's job.

## Ruling on the prior-art bundle

`C:\Users\rajdh\Projects\numen-vps-bootstrap` — files dated 2026-04-27, not a git
repository, never executed, README still opens with "You read **Part 1** and do those
steps yourself".

**Ruling: bin it.**

The findings that decide it:

- **It fails the deciding axis by design.** The whole bundle stands up a *second* Claude
  Code on a Hetzner CX22 (`bootstrap.sh` installs `@anthropic-ai/claude-code` on the VPS)
  and clones the repos there. Nothing in it reaches the Windows box. Phone-driving the
  Windows session was never what it was for.
- **The Telegram half does not drive Claude at all.** `bot/telegram-bot.py` exposes
  exactly `/briefing`, `/triage`, `/wiki`, `/status`, `/help`, each of which shells out to
  a fixed `.sh` under `~/scripts/`. The string `claude` appears nowhere in it. It is a
  cron remote control, not an agent surface.
- **The Happy half appears premised on a wrong model of Happy.** `systemd/happy.service`
  runs `happy --host 127.0.0.1 --port 9000` and `caddy/Caddyfile` fronts it with HTTP
  basic auth because — its own comment says — "Happy itself doesn't have built-in auth so
  the proxy is the only thing standing between the public internet and a fully-empowered
  Claude Code session." Current Happy docs describe a CLI plus a native mobile app paired
  by QR code, both dialling **out** to a relay, with end-to-end encryption and an explicit
  "Without the server, you'd need to set up port forwarding"
  (https://happy.engineering/docs/how-it-works/). A self-hosted HTTP UI on port 9000
  behind basic auth is not the shape the vendor documents. The bundle's port/Caddy design
  is unverified prior art and should not be trusted without re-reading Happy's docs.
- **It is superseded.** Remote Control did not have to exist for this plan to be written;
  it does now, and it delivers the bundle's stated goal — Claude Code from the phone —
  against the *real* machine, for zero extra euros and with no inbound port.

Not thrown away with it: the rclone Drive mount unit and the three cron wrappers answer a
different question (always-on scheduled jobs off the laptop). If that question comes back,
lift those two pieces; do not lift the Happy, Caddy or Telegram layers.

## Labelling

Claims sourced from the local bundle READMEs — the €4.51/mo CX22 figure, the Falkenstein
placement, the Happy port/Caddy topology, the three-hour Part 2 estimate — are
**unverified prior art**, not fact. They were never executed and never checked against
Hetzner's or Happy's current pages during this run.

## Sources

All fetched 2026-08-15.

- Remote Control — https://code.claude.com/docs/en/remote-control
- Claude Code on the web — https://code.claude.com/docs/en/claude-code-on-the-web
- Claude Code system requirements — https://code.claude.com/docs/en/setup
- Claude plan pricing — https://claude.com/pricing
- Happy docs / FAQ / how-it-works — https://happy.engineering/docs/ , https://happy.engineering/docs/faq/ , https://happy.engineering/docs/how-it-works/
- Happy repo metadata — https://api.github.com/repos/slopus/happy
- Telegram bridge — https://raw.githubusercontent.com/RichardAtCT/claude-code-telegram/main/README.md , https://api.github.com/repos/RichardAtCT/claude-code-telegram
- OpenSSH on Windows — https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse
- WSL (tmux availability) — https://learn.microsoft.com/en-us/windows/wsl/about
- Termius pricing — https://termius.com/pricing
- Blink Shell — https://blink.sh , https://docs.blink.sh/faq
- Tailscale pricing — https://tailscale.com/pricing
- Tailscale SSH — https://tailscale.com/kb/1193/tailscale-ssh
- VS Code Remote Tunnels — https://code.visualstudio.com/docs/remote/tunnels
- JetBrains remote development — https://www.jetbrains.com/remote-development/ , https://www.jetbrains.com/help/idea/remote-development-overview.html
- Vibe Kanban — https://raw.githubusercontent.com/BloopAI/vibe-kanban/main/README.md , https://api.github.com/repos/BloopAI/vibe-kanban , https://vibekanban.com/docs/self-hosting/deploy-docker
- omnara — https://raw.githubusercontent.com/omnara-ai/omnara/main/README.md , https://omnara.com/pricing , https://docs.omnara.com/self-hosting/deployment
- ttyd — https://github.com/tsl0922/ttyd
- code-server — https://coder.com/docs/code-server/install
