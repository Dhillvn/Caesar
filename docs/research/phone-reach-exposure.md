# Phone reach: exposure, cost and blast radius

Ticket: https://github.com/Dhillvn/caesar/issues/167

All prices and free-tier limits below were fetched from vendor pages on **2026-08-15**. Every
figure carries the URL it came from. Nothing was signed up for, installed, provisioned or
exposed to produce this document; every option is judged from its published documentation.

This document does **not** choose the reach path. That is a later ticket worked with Raj. What
this document does is fix the cost, the Windows behaviour, the exposure surface and the
authentication ruling for each candidate, so that later choice is made against numbers rather
than against the prior-art plan's defaults.

## 1. The blast radius, stated first

Whatever the surface is, what sits behind it is a Claude Code session running as Raj on the
laptop. That is, by construction, **arbitrary code execution as Raj**, and the sandbox that
would normally bound it does not exist on this machine:

> "The sandbox is built into Claude Code and runs on macOS, Linux, and WSL2. Native Windows is
> not supported. On Windows, run Claude Code inside a WSL2 distribution."
> — https://code.claude.com/docs/en/sandboxing

An attacker who reaches a live session on that machine reaches, without needing a second
exploit:

- `~/.claude/.env.numen-apis` — every API key Numen owns, in one file. Read once, valid until
  each key is individually rotated at each vendor.
- The `gh` token with write access to Raj's repositories. Push access is also *code execution
  later*: a poisoned workflow or a poisoned skill file runs on the next session.
- The mounted Google Drive — the whole business: client work, contracts, books, credentials
  stored in documents.
- The session's own conversation history and every other credential the machine can read
  (browser profiles, SSH keys, cloud CLI caches).

Three properties make this worse than a normal single-user exposure:

1. **It is silent.** An agent session takes instructions in natural language. Exfiltration looks
   like ordinary tool use. There is no malware signature to catch.
2. **It is persistent.** With `gh` write access and file write access to `~/.claude/`, an
   attacker can establish re-entry that survives revoking the reach path itself.
3. **It is business-total.** There is no second tenant, no staging copy, no blast wall. One
   machine is the whole company.

What meaningfully limits it — and it is a short list:

- **Not being reachable at all** when Raj is not deliberately using the feature. A surface that
  is off by default has no attack surface.
- **A device-scoped credential required before the first TCP byte reaches the laptop**, so an
  attacker who has not compromised one of Raj's enrolled devices cannot even speak to the
  service.
- **Nothing published on public DNS** that resolves toward a session, so the surface cannot be
  found by scanning or by certificate-transparency trawling.
- **Central, one-action revocation** that does not require touching the laptop, because if the
  laptop is the thing compromised, you cannot trust commands issued on it.
- **Credential rotation on a clock that expires by default**, so a forgotten enrolment becomes
  a closed door rather than an open one.

Things that do *not* limit it, and should not be counted as mitigations: HTTPS (encryption is
not authorisation), a long random URL (it is a shared secret in a place that gets logged), rate
limiting (one successful request is enough), and the laptop's own Windows login (see §5).

## 2. Ranked shortlist

Ranked by exposure per pound, given §1. Rank is an analytical ordering, not a recommendation to
adopt.

### Rank 1 — Tailscale (or another WireGuard mesh)

| | |
|---|---|
| Cost | Personal plan **$0, "Free forever"**: unlimited user devices, up to 6 users, 3 ACL groups, 50 tagged resources, 1,000 ephemeral-resource minutes/month. Standard **$8/user/month**, Premium **$18/user/month**. (https://tailscale.com/pricing) |
| Does the free tier cover Raj? | Technically yes — one user, two devices, well inside every limit. **Licensing is the catch, not capacity.** The same page: the Personal plan "is only suitable for non-commercial use of Tailscale", and "If you create a tailnet with a custom domain, it's considered business use". Caesar drives Numen work, so the honest read is Standard at **$8/user/month ≈ $96/year** for one seat. A Gmail-signup tailnet lands on Personal automatically, but that is a licence Raj would be leaning on rather than one he holds. (https://tailscale.com/pricing) |
| Windows client | First-class. Signed `.exe` and `.msi` installers, Windows 10+ / Server 2016+, system-tray app, SSO login through an identity provider, registry-based policy for MDM. (https://tailscale.com/kb/1022/install-windows) |
| Sleep/wake | The laptop asleep is simply offline — nothing reaches it, which is a security property, not a bug. On wake the client re-establishes outbound; there is no inbound listener or public record to go stale. Vendor docs do not publish a sleep/resume guarantee, so treat "reconnects within seconds of wake" as expected-but-unverified until measured. |
| Dynamic home IP | A non-issue by design: "Connections between tailnet devices work seamlessly across firewalls and Network Address Translation (NAT) … without requiring port forwarding or complex firewall rules." (https://tailscale.com/kb/1151/what-is-tailscale) |
| What becomes reachable, and by whom | A port on the laptop reachable **only from devices already authenticated into Raj's tailnet**, further narrowable by ACL. Nothing is published on public DNS. An internet-wide scanner sees nothing. The trust root moves to the tailnet: any enrolled device, and the Tailscale account itself, become paths in. |
| Credential lifetime | Node keys expire — "By default, new domains are set with an expiry period of 180 days"; the period is settable from 1 to 180 days, and expiry can be disabled per device. Expiry means the door closes by default. (https://tailscale.com/kb/1028/key-expiry) |

Why it ranks first: it is the only option in this list where the default state of the surface is
*unaddressable from the public internet*, and where the primary credential is device-scoped and
expiring rather than shared and typed.

### Rank 2 — Cloudflare Tunnel + Cloudflare Access

| | |
|---|---|
| Cost | Zero Trust / SASE **Free plan: $0 forever, 50-user limit**, community-forum support, log retention **up to 24 hours**; includes the application connector, the device client, and ZTNA. Pay-as-you-go is **$7/user/month** with no user limit and up to 30 days of logs. (https://www.cloudflare.com/plans/zero-trust-services/) |
| Does the free tier cover Raj? | Yes, comfortably and without a licensing asterisk — one seat against a 50-seat ceiling. Seats are consumed per authenticating user, not per device, and service-token traffic consumes none. (https://developers.cloudflare.com/cloudflare-one/team-and-resources/users/seat-management/) The real free-tier cost is **24-hour log retention**: after a quiet weekend there is no record left to answer "was anything else reached?". |
| Windows client | `cloudflared` installs as a Windows system service (`cloudflared.exe service install`, `sc start cloudflared`). (https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/local-management/as-a-service/windows/) Rougher than Tailscale's tray app: config lives in a YAML file and a registry `ImagePath`, i.e. more places to get it silently wrong. |
| Sleep/wake | Connector is outbound-only, so sleep drops the tunnel and wake re-establishes it. But note the asymmetry with rank 1: **the public hostname keeps resolving while the laptop is asleep.** The endpoint stays discoverable and the login page stays live; only the origin is absent. |
| Dynamic home IP | Irrelevant. "With Tunnel, you do not send traffic to an external IP — instead, a lightweight daemon in your infrastructure (`cloudflared`) creates outbound-only connections to Cloudflare's global network", so the origin needs no publicly routable IP at all. (https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/) |
| What becomes reachable, and by whom | **An HTTPS endpoint published on public DNS.** Anyone on the internet can resolve it, connect to it, and reach the Access login page; the hostname also appears in certificate transparency logs, so it is findable without guessing. What stands between the internet and the session is entirely the Access policy. The origin itself is genuinely protected — inbound can be blocked at the firewall so nothing but Cloudflare can reach it — but the *front door* is public by design. |

Why it ranks second and not first: the security model is sound and the money is better, but it
converts "unaddressable" into "addressable, and defended by one policy evaluated by a third
party". Against §1, a single misconfigured Access policy — a bypass rule, an over-broad email
domain, a stale service token — is the whole business. That is a thinner margin than a mesh, for
$96/year less.

### Rank 3 — Reverse SSH tunnel to a relay host

| | |
|---|---|
| Cost | No vendor plan and therefore **no fetched figure**: the cost is whatever relay host Raj already has or rents. Stated as unpriced rather than as free, deliberately. The client side is free and built in: OpenSSH Server is a Windows optional feature installed with `Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0`. (https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse) |
| Windows behaviour | Workable but hand-built. `sshd` runs as a service with `Set-Service -Name sshd -StartupType 'Automatic'`, and a persistent reverse tunnel needs its own supervision — autossh or a scheduled task — because nothing in the box keeps `ssh -R` alive. (same URL) |
| Sleep/wake | The weakest of the tunnelled options. A reverse tunnel dies on sleep and does not come back unless something restarts it; the relay may hold a half-open socket until keepalive timeouts clear it. Every wake is a chance for the tunnel to be silently absent. |
| Dynamic home IP | Fine — the laptop dials out. |
| What becomes reachable, and by whom | Depends entirely on the relay's bind. Bound to the relay's loopback, only relay users reach it — good. Bound to `0.0.0.0`, it is a public port on a public IP with no identity layer in front, which is rank 5 wearing a costume. The relay host becomes a second machine that must be secured to the same standard as the laptop, because compromising it yields the tunnel. |

Why it ranks third: cryptographically strong, operationally fragile, and it adds a whole second
host to the trust boundary in exchange for saving a subscription.

### Rank 4 — ngrok

| | |
|---|---|
| Cost | **Free: $0** — $5 one-time credit (valid one year, spendable only on the Free plan, not on data transfer out), up to 3 online endpoints, 1 GB transfer, 20k HTTP/S requests, **interstitial page on HTTP/S endpoints**, assigned dev domain, 1 team member, 4k requests/min, 24-hour traffic-inspector retention, 3 monthly-active Traffic Identities for OAuth; TCP endpoints need credit-card verification. **Hobbyist: $8/month billed annually ($10 monthly)** — $10 included usage, 3 endpoints, 5 GB, 100k requests, no interstitial, ngrok-branded domains; when the credit runs out "your endpoints will stop working until the end of your billing cycle". **Pay-as-you-go: $20/month + usage** — unlimited endpoints, bring-your-own domain at $0.01 per active hour, $0.02 per active endpoint hour, $0.10/GB, $1 per 100k requests, 5 identities then $1 each. (https://ngrok.com/pricing) |
| Does the free tier cover Raj? | Marginally, and badly. 20k requests/month is plausible for phone-driven use; the interstitial page, the random assigned dev domain, and the hard stop when credit is exhausted are not things to build a control channel on. Hobbyist at **$8/month ≈ $96/year** is the honest entry price — the same annual figure as Tailscale Standard, for a worse exposure profile. |
| Windows client | Mature agent, runs in the background as a service; remote stop/restart on all plans, remote update on Pay-as-you-go. (https://ngrok.com/pricing) |
| Sleep/wake | Agent reconnects on wake. On Free/Hobbyist the URL is assigned rather than owned, so a reconnect can hand back a *different* hostname — the phone's bookmark rots. A stable custom domain starts at Pay-as-you-go. |
| Dynamic home IP | Irrelevant — outbound agent. |
| What becomes reachable, and by whom | **A public HTTPS endpoint on ngrok's DNS.** ngrok's hostname space is well known and actively enumerated; assume discovery, not obscurity. ngrok's own auth (OAuth via Traffic Identities) is capped at 3 monthly active users free / 5 on paid, so it is usable — but it is a second vendor holding the front door to §1. |

Why it ranks fourth: same public-endpoint exposure as rank 2, at a higher price, with less
mature policy tooling and a less stable hostname.

### Rank 5 — Direct port forwarding on the home router

| | |
|---|---|
| Cost | £0 in fees. |
| Windows behaviour | Requires an inbound listener on the laptop plus a router NAT rule. If SSH is the listener, note that installing OpenSSH Server "creates and enables a firewall rule named `OpenSSH-Server-In-TCP`. This rule allows inbound SSH traffic on port 22." (https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse) |
| Sleep/wake | Fails ugly. The forward points at a LAN IP; DHCP hands out a different one and the rule now points at nothing — or, worse, at whatever device took that address. |
| Dynamic home IP | Needs dynamic DNS, which republishes Raj's home address every time the ISP rotates it. The reach path now also leaks where he lives. |
| What becomes reachable, and by whom | **A port on the public internet, reachable by everyone, indexed by scanners within hours.** No identity layer, no revocation, no logging beyond the daemon's own. The credential is whatever the daemon checks, brute-forced continuously by background noise. |

Why it ranks last: it is the only option that offers the entire internet a first packet, and it
is the only one that publishes Raj's home IP as a side effect.

## 3. Exposure summary

| Option | Cost/yr (single user) | Published on public DNS? | Findable by scanning? | Primary credential | Central revoke without touching laptop |
|---|---|---|---|---|---|
| Tailscale | $0 Personal (non-commercial only) / **$96 Standard** | No | No | Device node key, expiring | Yes |
| Cloudflare Tunnel + Access | **$0** (24 h logs) | Yes | Yes | Access policy: IdP identity or service token | Yes |
| Reverse SSH | Unpriced (relay host) | Only if relay is | Only if relay binds publicly | SSH key | Only via relay |
| ngrok | $0 crippled / **$96 Hobbyist** | Yes | Yes | ngrok endpoint policy | Yes |
| Port forward | £0 | Yes (via DDNS) | Yes, fast | Whatever the daemon checks | No |

## 4. Minimum protection — stated as a floor

Not a preference. Any reach path that fails one of these should be rejected regardless of how
convenient it is:

1. **No unauthenticated party may complete a TCP connection to the laptop.** Authentication must
   happen before the laptop's service is spoken to, in the network or in a provider's edge — not
   inside the app behind the port.
2. **The credential must be device-scoped and issued by Raj to a named device**, so that a
   secret stolen from the phone is not usable from an attacker's machine.
3. **It must be revocable in one action from a console that is not the laptop**, and revocation
   must be effective in minutes, not at next expiry.
4. **It must fail closed.** Expiry, credit exhaustion, plan lapse, or config error must end in
   "unreachable", never "reachable without the check".
5. **Nothing may be published on public DNS that resolves toward a Claude Code session** unless
   the layer in front of it is a phishing-resistant identity check (§5), because publication
   means discovery.
6. **The surface must be off unless in use.** A control channel that is up 24/7 to serve
   occasional phone use is paying full exposure for part-time value.
7. **Every action taken through the path must be logged off the laptop**, retained long enough to
   answer "what happened last week" — 24 hours is not that.

## 5. Ruling on each authentication layer

Judged solely against §1: the thing being protected is arbitrary code execution as Raj plus every
Numen credential.

| Layer | Ruling | Reason |
|---|---|---|
| **HTTP basic auth (the prior-art Caddy plan)** | **Inadequate — theatre.** | One shared static secret, replayed on every request, typed on a phone keyboard, identical from every device, with no expiry, no per-device revocation and no binding to anything. It is brute-forceable at the endpoint and phishable in one screenshot. Its whole security value is "the attacker must guess a password" — and what the guess buys is §1. It is the single weakest layer on this list, and it is the one the prior-art plan reached for. Reject as a sole gate. |
| **Bearer token in a header** | **Inadequate alone; acceptable as a second layer.** | Same shared-secret class as basic auth. Marginally better in that it is not typed and can be long and rotated, marginally worse in that it will end up stored in a phone app, a shortcut, or a note. Behind a mesh it is useful defence-in-depth against a compromised device on the mesh; in front of the internet it is basic auth with extra steps. |
| **Device-scoped key** (WireGuard/Tailscale node key; Access service token bound to one device, ideally with mTLS) | **Adequate as the primary gate.** | Not replayable from a device that was not enrolled, centrally revocable, and expiring by default — Tailscale node keys expire on a 180-day default settable to 1–180 days (https://tailscale.com/kb/1028/key-expiry); Access service tokens carry an explicit duration, are refreshable, and are deleted to revoke (https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/). This is the only layer class that satisfies floor items 2, 3 and 4 on its own. Caveat for service tokens: Access will only honour them where the policy action is **Service Auth**, and a service token in a header is a bearer secret unless it is paired with mTLS or a mesh — so it inherits the row above if deployed naked on a public hostname. |
| **IdP SSO with phishing-resistant MFA** (Cloudflare Access in front of a published hostname, with a passkey or hardware key on the identity account) | **Adequate for a published endpoint — conditionally.** | Strong, logged, and revocable, and it is what makes rank 2 viable at all. Two conditions, both load-bearing: the identity account must have phishing-resistant MFA, because that account now transitively holds §1; and the login page is publicly reachable, so the whole business sits behind one OAuth session cookie's lifetime. Set short session durations. Without hardware-backed MFA on the IdP, downgrade this to inadequate — SMS or TOTP against this blast radius is a coin flip against a competent phisher. |
| **OS login on the laptop** (Windows password / Hello) | **Inadequate — irrelevant to this threat.** | It is not an authentication layer on the reach path at all. The exposed service runs as Raj in an already-unlocked session; a request that arrives over the tunnel never meets a Windows credential prompt. Counting it as protection is a category error. Its only real contribution is physical-theft resistance, which is not the threat here. |

**Verdict on the prior-art plan.** Caddy with HTTP basic auth in front of a loopback service is
rejected as a sole protection layer. It was designed for a different blast radius; carried over
unexamined it protects arbitrary code execution and every Numen key with one typed shared
password. Caddy as a reverse proxy behind a mesh is fine; basic auth as *the* gate is not.

## 6. What this leaves for the choosing ticket

The genuine trade-off is narrow and worth stating plainly, because it is the decision:

- **Tailscale Standard** costs ~$96/year and buys a surface that is not addressable from the
  public internet at all.
- **Cloudflare Zero Trust Free** costs $0 and buys a surface that is publicly addressable and
  defended by one policy, with 24-hour forensic memory.

Both clear the floor in §4 if configured correctly. They differ in what a configuration mistake
costs: on a mesh, a mistake usually means "still private"; on a published hostname, a mistake
means "the internet can reach the login page for the whole company". The choosing ticket should
also weigh floor item 6 — an on-demand surface, raised when Raj wants his phone to drive Caesar
and lowered afterwards, is materially safer than either option left running permanently.
