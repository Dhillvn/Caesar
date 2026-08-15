# Reaching Raj's phone when no Caesar session is in front of him

Ticket: [#176](https://github.com/Dhillvn/caesar/issues/176). Every URL below was fetched
during this run (2026-08-15).

## The question

Remote Control settles the *inbound* direction — Raj's phone can drive a live local session,
confirmed working 2026-08-15. This is the reverse: a thing that needs Raj happens while he is
not looking, and today it reaches nobody until he looks.

Three signals can need him:

- the watcher's six events (`skill/references/watcher.md`) — `LANDED`, `LANDED-NO-GIST`,
  `ERRORED`, `DIED-AT-SPAWN`, `QUIET`, `NO-TRANSCRIPT`
- the `caesar:needs-raj` label (`skill/references/failure.md`)
- a PR queued for the merge word (`skill/SKILL.md`, *Build work and the merge gate*)

`skill/scripts/publish-runs.ps1` already renders run state to a GitHub gist readable from a
phone. That is load-bearing for everything below: **the notification only has to say *look*.**
It carries no content, so it needs no formatting, no size budget, and no secrets — which is
what makes the cheapest mechanism sufficient rather than merely tolerable.

## Finding 1 — what the Claude app already does unaided

Claude Code can push to the phone with no extra machinery, and it is not enough.

> "When Remote Control is active, Claude can send push notifications to your phone. Claude
> decides when to push. It typically sends one when a long-running task finishes or when it
> needs a decision from you to continue. […] Beyond the two on/off toggles below, there is no
> per-event configuration."
> — <https://code.claude.com/docs/en/remote-control#mobile-push-notifications>

Four constraints from the same page kill it as Caesar's escalation path:

1. **It requires a live Remote Control session.** "Remote Control runs as a local process. If
   you close the terminal, quit VS Code, or otherwise stop the `claude` process, the session
   goes offline"
   (<https://code.claude.com/docs/en/remote-control#limitations>). No session, no push — and
   "no Caesar session in front of him" is exactly the case this ticket is about.
2. **Claude decides, not Caesar.** Two toggles (`Push when Claude decides`, `Push when actions
   required`) and no per-event configuration, so "push on `DIED-AT-SPAWN`, never on `QUIET`"
   is not expressible.
3. **It is suppressed when he is at the machine** — pushes are skipped while he is typing in
   the connected terminal, and `CLAUDE_CLIENT_PRESENCE_FILE` extends that to any time a marker
   file exists. Useful, but it means presence, not event class, drives delivery.
4. **Plan-gated**: Pro, Max, Team, Enterprise; API keys unsupported
   (<https://code.claude.com/docs/en/remote-control>).

Verdict: keep it on — it is free and it covers the case where a session *is* up and Raj has
wandered off. It cannot be the mechanism, because it cannot be aimed.

## Finding 2 — can a Claude Code hook reach a phone

Yes, and the hook layer is the wrong place to put it anyway.

The `Notification` hook fires when Claude Code sends a notification, and its `matcher` selects
the notification type — `permission_prompt`, `idle_prompt`, `agent_needs_input`,
`agent_completed` and others. `Stop` fires when the main agent has finished responding. Both
take `"type": "command"` entries that run an arbitrary shell command:

```json
{ "hooks": { "Notification": [ { "matcher": "idle_prompt",
  "hooks": [ { "type": "command", "command": "/path/to/idle-notification.sh" } ] } ] } }
```

— <https://code.claude.com/docs/en/hooks>

So a hook would have to invoke a program that performs an outbound HTTPS request to a push
service (one `curl`/`Invoke-RestMethod` line). The hook itself has no phone capability; it is
only a trigger. The same page documents HTTP hooks, so the request can even be the hook.

**But Caesar's signals are not hook events.** A landing is discovered by `watch-runs.ps1`
polling the run directory, a flag is a label Caesar stamps, and a queued PR is GitHub state.
None of them coincide with a `Stop` or `Notification` in the driving session at the moment
they matter — and `Stop` fires on *every* turn end, which would be a push per turn. The push
belongs where the event is already computed: inside `watch-runs.ps1` and at the two places
Caesar flags and opens a PR. Hooks are a viable transport and a bad trigger.

## The candidates

| Mechanism | Cost | Setup burden | Exposure | Reliability while phone asleep |
|---|---|---|---|---|
| **ntfy.sh (hosted)** | Free tier, "Try ntfy for free without sign-up"; 250 messages/day on ntfy.sh. Paid: Supporter $5/mo (2,500/day), Pro $10/mo (20k/day), Business $20/mo (50k/day) [[1]](https://ntfy.sh/#pricing) [[2]](https://docs.ntfy.sh/publish/) | Install free app, pick an unguessable topic string, one `POST`. No account either side [[3]](https://docs.ntfy.sh/subscribe/phone/) | **None.** Outbound HTTPS only. (Self-hosting *would* need an exposed port — not proposed) | Android via FCM, with an instant-delivery foreground service to avoid FCM delay; iOS via APNs [[3]](https://docs.ntfy.sh/subscribe/phone/) |
| **Pushover** | $4.99 one-time **per platform**; 10,000 messages/month free to send; Teams $5/user/mo (not needed) [[4]](https://pushover.net/pricing) | Buy app, create account, create an application token, register a user key. One `POST` | None. Outbound HTTPS only | Native push, commercial service with a status page [[4]](https://pushover.net/pricing) |
| **Telegram bot** | Free — "Bots are able to message their users at no cost"; paid broadcast only above 30 msg/s [[5]](https://core.telegram.org/bots/faq) | Telegram account, create bot via @BotFather, hold a bot token, discover the chat id. One `POST` | None — sending is outbound; long polling means no webhook and no SSL endpoint [[5]](https://core.telegram.org/bots/faq) | Native push through the Telegram app |
| **Email to an alerting address** | Free (existing account) | Highest: SMTP credentials on disk. Gmail needs 2-Step Verification plus a 16-digit app password, which Google says "aren't recommended and are unnecessary in most cases" [[6]](https://support.google.com/accounts/answer/185833) | None outbound, but a long-lived mail credential now sits on the machine | **Worst.** Delivery is at the mail client's polling/batching discretion, and iOS notification summaries batch mail by design |

## Recommendation — hosted ntfy.sh

**One free app, no account, no port, one line of PowerShell.** Nothing on the list is cheaper
or more boring, and the constraint ("an option needing a hosted service, an account or an
exposed port must beat one that needs none") is satisfied on the two that matter: ntfy needs
**no account** and **no exposed port**. It does use a hosted service, and there is no
account-free, service-free way to wake a sleeping phone — every candidate here routes through
someone's servers, because FCM and APNs are the only doors iOS and Android open.

The message body is a single line plus a `Click:` header pointing at the gist
`publish-runs.ps1` already maintains. That is the whole design: **the push says *look*, the
gist says *what*.**

Two honest costs, stated rather than buried:

- **A topic name is the only secret.** Anyone who guesses it can read the notifications, so
  the topic must be a long random string and the body must stay content-free — ticket numbers
  and event names, never diffs or credentials. This is a real downgrade from Pushover's
  token+user-key pair, and it is the price of needing no account.
- **The free tier is 250 messages/day** [[2]](https://docs.ntfy.sh/publish/). Under the event
  set below, Caesar emits a handful per day. If it ever nears that ceiling, the event set is
  wrong, not the tier.

### The events worth firing on

Argue from the failure that hurts. The failure is not "a run errored" — the failure is **the
map stopped advancing and nobody knew for hours.** Every raw watcher event that Caesar can
resolve alone is noise, and noise is how a real alert gets swiped away. So:

| Fire | Why |
|---|---|
| **`caesar:needs-raj` stamped** | Definitionally his: the flag means Caesar stopped and cannot proceed. It already absorbs `ERRORED` and `DIED-AT-SPAWN` that survived the one-retry ceiling, and budget death, and a coherently-wrong artifact — so firing on the label instead of the raw events fires once, after Caesar has done his job |
| **A PR is queued for the merge word** | The only signal that is *pure* waiting: work is finished, correct, and blocked solely on Rome. `SKILL.md` already says a queued PR is "the one piece of prior state nothing else surfaces" |
| **The frontier holds only HITL tickets** | `prototype`, `grilling`, HITL `task`. Caesar has nothing left to dispatch, so the map is stalled on a human and will stay stalled silently. This is the failure that hurts, and it is the one no existing signal reports at all |

**Do not fire on**: `LANDED` and `LANDED-NO-GIST` (Caesar verifies and appends — that is the
job), `QUIET` ("look, do not kill" is Caesar's look, not Raj's), `NO-TRANSCRIPT` (re-arrives
every recheck; a repeating alarm trains dismissal), and `ERRORED` / `DIED-AT-SPAWN` on first
occurrence (one retry is owed before Raj hears about it).

### Known gap, unsolved by any candidate

All three events are computed by a running Caesar session or its watcher. **If no session is
running at all, nothing fires** — the same structural limit as the Claude app's push, for the
same reason. Closing it needs a scheduled task independent of any session, which is out of
scope here and worth its own ticket.

### Runner-up: Pushover, and why it lost

Pushover is the better-engineered product — a per-application token and a per-user key instead
of a guessable topic, priority levels with forced re-alert, and a public status page
[[4]](https://pushover.net/pricing). It lost on the stated constraint and nothing else: it
costs $4.99 per platform and requires an account, and ntfy delivers the same push for $0 with
neither. Since the payload is only the word *look*, Pushover's advantages buy security and
polish on a message that carries nothing worth securing. If the topic-name-as-secret model
ever proves too weak — or if a genuinely urgent event needs an alarm that repeats until
acknowledged — Pushover is the upgrade, at $4.99 once.

Telegram lost to Pushover on setup (bot token *and* chat-id discovery, plus a Telegram account
Raj must keep signed in) despite being free. Email lost outright on sleep reliability and on
putting a long-lived mail credential on disk for no gain.

## Sources

1. <https://ntfy.sh/#pricing> — ntfy hosted tiers and "free without sign-up"
2. <https://docs.ntfy.sh/publish/> — publish by `curl` with no account; 250 messages/day on ntfy.sh
3. <https://docs.ntfy.sh/subscribe/phone/> — free apps, no account to subscribe, FCM/APNs delivery
4. <https://pushover.net/pricing> — $4.99 one-time per platform, 10,000 messages/month, Teams $5/user/mo
5. <https://core.telegram.org/bots/faq> — bots message users at no cost; @BotFather; long polling needs no webhook
6. <https://support.google.com/accounts/answer/185833> — Google app passwords require 2-Step Verification and "aren't recommended"
7. <https://code.claude.com/docs/en/remote-control> — Remote Control plans, mobile push, presence suppression, local-process limitation
8. <https://code.claude.com/docs/en/hooks> — `Notification` matchers, `Stop` timing, `"type": "command"` hook shape
