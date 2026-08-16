# Ticket #182 — what is settled, what is still open

> **SUPERSEDED 2026-08-16.** #182 is closed. Every variable below was ruled across nine
> prototype rounds; the answers are in the ticket's resolution comment, in `DESIGN.md`
> (State colours, Deviations) and in `docs/prototypes/command-centre.html`. Kept for the
> Method section, which still holds.
>
> **Two claims below are wrong.** The "Already ticketed elsewhere" section states that #186
> covers sweep failure and #187 the history view. It does not: **#186 and #187 are pull
> requests**, not tickets. Sweep failure remains fog in the map's *Not yet specified*; the
> ledger's place on the page was ruled by Raj in round 8 — it stays.

Handoff written 2026-08-16, immediately before a context clear. Prototyping continues from here.

**Map:** https://github.com/Dhillvn/Caesar/issues/178 — one self-refreshing command centre
**Ticket:** #182, prototype how the command centre looks. **Still open.**

---

## Settled — do not reopen without a reason that beats the record

1. **Layout is card-per-map.** Each map is a separate workstream; a merged table loses the
   boundary that makes the page readable.
2. **Design system is Factory**, with Numen's two brand colours in its two functional accent
   slots. Standard: `DESIGN.md` at the repo root. Reasons recorded there, measured not asserted.

Nothing else about the look is ruled.

---

## Method — how prototyping is done here

Learned the hard way this session; do not drift off it.

- **Build against the full DESIGN.md, never a summary of it.** A field extract (colours, radii,
  a base unit) is not the document. The document also carries components, layout rhythm,
  imagery, motion and an explicit Do/Don't list — and that is where the look actually lives.
  The three source specs are saved in `docs/prototypes/design-md/`.
- **Never average multiple systems.** The intersection of N distinctive systems is the *least*
  distinctive result, because what they share is the generic baseline. Character lives in the
  disagreements. This was tried and rejected.
- **Never break a system's own stated Don't.** Modal's spec forbids non-green accents; swapping
  in teal made it unrecognisable. Factory was chosen partly because the brand swap fits its
  rules rather than breaking them.
- **Only one variable changes at a time**, against the shared fixture, so the comparison is
  honest. Per `C:\Numen\Knowledge\wiki\ops\scientific-method.md`.
- **Narrow objectively, then hand the taste call over.** Measure where a number exists —
  scroll height, time-to-first-ticket, contrast ratio — rather than asserting.

---

## Files

| Path (relative to the worktree root) | What it is |
|---|---|
| `DESIGN.md` | The repo standard. Factory + the substitution. |
| `docs/prototypes/design-md/factory.md` | Unmodified source spec. **Wins over `DESIGN.md` on any disagreement except the two accents.** |
| `docs/prototypes/design-md/slash.md`, `modal.md` | The rejected alternatives' specs. Reference. |
| `docs/prototypes/s2-factory.html` | Reference implementation, brand colours in. |
| `docs/prototypes/s1-slash.html`, `s3-modal.html` | Rejected alternatives, native palettes. |
| `docs/prototypes/fixture.md` | The data contract: 4 maps, 21 open, 28 decided. |
| `docs/prototypes/data.js` | That fixture as code. **Shared by all prototypes — keep it that way so only the design varies.** |

Worktree root: `C:\Users\rajdh\Projects\caesar\.claude\worktrees\ticket-182-prototype`

---

## Still open — the variables left to prototype

Roughly in the order they affect the page. Nothing here is decided.

### Composition

1. **Card grid width.** Currently `auto-fit, minmax(340px, 1fr)` — 3 across at 1280px, so four
   maps render 3 + 1 orphan. 2-up would be even; 4-up would be cramped. Unruled.
2. **Where the light Bone card sits.** It is the single brightest object on the page and
   currently closes the page, below the map cards. Top-of-page would make it the first thing
   seen. This is the biggest single lever on how the page reads.
3. **Section order.** Currently hero → repo strip → map cards → your-queue card → ledger.
4. **Whether the repo Trust Bar strip earns its space** at all.

### The map card

5. **Every ticket, or a capped list?** Currently every one, so card height tracks ticket count
   (Map A has 9, Map D has 3) and the grid goes ragged. A cap with "+6 more" evens it.
6. **Row sort.** Currently needs-you → your queue → ongoing → queued → blocked, then by number.
   Alternatives: strict number order, or grouped under state subheadings.
7. **What a row shows.** Currently number, title, type, blocker-if-blocked, state. Type may not
   earn its place. Age is absent and might matter more.
8. **Blocked tickets** — inline and dimmed, or collapsed behind a count?
9. **Click target** — whole row, or title only?

### The hero

10. **Which six metrics.** Currently open / needs-you / Caesar-holds / decided / agent slots /
    maps driven.
11. **Sparklines: keep or cut.** ⚠ **The current series are fabricated.** Real trend lines need
    run history that may not exist yet. Either source it or drop them — do not ship invented data.
12. **The 72px headline** — currently a fixed phrase. Could carry a live number instead.

### System-level

13. **State-to-colour mapping.** Copper = live, teal = settled is ruled at the token level, but
    which of the five states get an accent, which get Bone, and which get Graphite is not.
    Currently: Ongoing = copper, Needs-you/You = Bone, Queued = teal, Blocked = Graphite.
14. **Density.** Factory specifies "comfortable" with 96px section gaps. A page opened twenty
    times a day may want tighter. Deviating from the spec is allowed but must be recorded in
    `DESIGN.md` as a deliberate deviation, not left implicit.
15. **Empty states.** A map with nothing open; no PR awaiting the word; a sweep that found nothing.
16. **Freshness.** How the page shows how stale it is.

### Already ticketed elsewhere — do not prototype these here

- **#186** — what the page shows when a sweep fails. Covers the failure state.
- **#187** — whether the history view (the ledger) belongs on the page at all. Item 4 above and
  the ledger's existence are #187's call, not #182's.

Both are open `grilling` tickets on map #178 and are Raj's to rule.

---

## State of the work — nothing has been committed or published

- `DESIGN.md` and `docs/prototypes/` are **untracked** on branch `ticket-182-prototype`.
  Nothing committed: this worktree was not created by the session that did the work.
- **Nothing written to GitHub.** #182 is still open, no resolution comment, map #178's
  `## Decisions so far` is untouched. The two settled decisions above exist only in this file
  and in `DESIGN.md` until someone writes them to the map.
- Two draft PRs still await Raj's word: **#187** (docs-only) and **#186**
  (`skill/scripts/dashboard-data.ps1`, `status.ps1`, `ticket-state.ps1` — riskier; `status.ps1`
  runs at every Caesar session startup).
- **#183** (build the renderer) stays blocked until #182 closes.
