# Caesar — Style Reference

> Terminal war room at midnight. A stark black control surface where a single light card
> lands like a flashlit dispatch — the only object in the room is the work itself.

**Theme:** dark
**Base system:** Factory — https://styles.refero.design/style/13d6fc89-eba2-4724-ac37-20f4f2e5efec
**Unmodified source spec:** `docs/prototypes/design-md/factory.md`
**Ruled on:** 2026-08-16, ticket #182

This is Factory's published system with **one substitution**: its two functional accents are
replaced by Numen's brand colours, slot for slot. Everything else — surfaces, type, tracking,
radii, spacing, components, elevation — is Factory's, unaltered. Where this file and
`docs/prototypes/design-md/factory.md` disagree on anything other than those two accents,
the source spec wins and this file is wrong.

## Why this system

Four measured reasons, recorded so a future change has to beat them rather than relitigate them:

1. **It is the only one of the three finalists designed as an instrument.** Factory ships a
   Dashboard Frame and a Metric Tile as first-class components; its own spec states the mono
   voice exists to "signal 'instrument, not marketing'". Slash and Modal would have required a
   marketing component (Blog Post Card / Workload Card) to hold operational data.
2. **It is the only one whose rules permit state colour-coding.** Modal rations its accent to
   one fill per viewport; Slash bars copper from status entirely. Factory defines two accents
   *as data-voice colours*, which is exactly the requirement for a five-state ticket board.
3. **It is the only one the brand substitution does not break.** Modal's spec forbids non-green
   chromatic accents; Slash's forbids any chromatic accent but copper. Factory forbids
   *additional* accents — so a like-for-like swap into its two existing slots leaves the rule
   intact.
4. **It reaches the work fastest.** Measured at 1280×610 (Raj's usable viewport at 150% scaling):
   first ticket row at 929px, against Slash 1355px and Modal 1414px. Factory's spec puts the
   hero in a 2-column split, so metrics sit beside the headline rather than above the fold-line.

## The substitution

| Factory slot | Factory's value | Caesar's value | Role, unchanged |
|---|---|---|---|
| Signal accent | Signal Orange `#ee6018` | **Warm Copper `#C87941`** | Live status, build-state indicators, accent strokes in data charts. **Never a button fill.** |
| Metric accent | Metric Green `#a0ca92` | **Teal `#0D9488`** | Positive metric, settled trend, resolved state. **Never a button fill.** |

Both are the Numen brand hexes, unmodified — one home:
`C:\Numen\.claude\skills\numen-brand-guidelines\SKILL.md`.

Contrast against the `#101010` canvas, computed from relative luminance rather than asserted:
copper **5.68:1**, teal **5.09:1**. Both clear WCAG AA for small text (4.5:1). Neither is used
below 12px.

The role assignment is not arbitrary. Numen's own identity doctrine holds copper as "an accent
note, not a second primary" — which is precisely what Factory's signal slot is: rationed,
attention-grabbing, never a surface. Teal is Numen's primary accent and lands in the slot for
settled and positive state.

**No third accent may be introduced.** That is Factory's rule and it is now Caesar's.

## Tokens — Colors

| Name | Value | Token | Role |
|------|-------|-------|------|
| Obsidian Canvas | `#101010` | `--color-obsidian-canvas` | Page background, footer base — the void everything else is measured against |
| Carbon Lift | `#1d1a18` | `--color-carbon-lift` | Raised dark surfaces, nav wells, button fills, hairline dividers |
| Ash Stroke | `#3d3a39` | `--color-ash-stroke` | Hairline borders, ghost button outlines, separator lines |
| Graphite Mid | `#4d4947` | `--color-graphite-mid` | Mid-tone fills, secondary surfaces, neutral data visualisation |
| Warm Granite | `#8a8380` | `--color-warm-granite` | Muted body text, secondary copy, inactive labels |
| Pale Stone | `#b8b3b0` | `--color-pale-stone` | Tertiary text, section eyebrows, subdued supporting copy |
| Bone | `#eeeeee` | `--color-bone` | Primary text, light card surfaces, the single bright figure on dark ground |
| Chalk | `#fafafa` | `--color-chalk` | High-emphasis light button fill, elevated neutral surface |
| **Copper Signal** | `#C87941` | `--color-copper-signal` | **Live status, running agents, errored runs, chart accent strokes** |
| **Teal Metric** | `#0D9488` | `--color-teal-metric` | **Settled, landed, decided, positive trend** |

## Tokens — Typography

### Geist · `--font-geist`
- **Substitute:** Inter, system-ui
- **Weights:** 400, 500 — 400 almost universally; 500 only when a label must dominate
- **Sizes:** 12, 14, 16, 36, 44, 72
- **Role:** All interface text. The flat 400-only treatment is a signature: authority comes from
  size and tracking, never from bold weight.

### Geist Mono · `--font-geist-mono`
- **Substitute:** JetBrains Mono, IBM Plex Mono, ui-monospace
- **Weight:** 400 · **Sizes:** 12, 14, 16 · **Tracking:** -0.02em
- **Role:** Captions, labels, status tags, ticket numbers, column headers — always uppercase
  12px. This is the system's secondary voice and the fastest way to signal "instrument".

### Type Scale

| Role | Size | Line Height | Letter Spacing | Token |
|------|------|-------------|----------------|-------|
| caption | 12px | 1 | -0.24px | `--text-caption` |
| body-sm | 14px | 1.43 | — | `--text-body-sm` |
| body | 16px | 1.5 | — | `--text-body` |
| heading | 36px | 1.1 | -1.12px | `--text-heading` |
| heading-lg | 44px | 1.12 | -1.1px | `--text-heading-lg` |
| display | 72px | 1 | -2.88px | `--text-display` |

## Tokens — Spacing & Shapes

**Base unit:** 8px · **Density:** comfortable
**Scale:** 8, 16, 24, 32, 40, 56, 80, 96, 120

| Element | Radius |
|---------|--------|
| nav | 3px |
| buttons | 3px |
| cards | 10px |
| largePanels | 20px |

**Layout:** page max-width 1200px · section gap 96px · card padding 24px · element gap 24px

## Elevation

**No shadows.** Depth is figure/ground contrast — a `#eeeeee` card landing on `#101010` does
the work a drop shadow would do elsewhere. The only permitted box-shadow is a 1px hairline at
near-black, never a diffuse glow.

## Components as Caesar uses them

Factory's components, mapped onto the command centre. Component specs are in the source file;
this table records only the mapping decision.

| Factory component | Caesar's use |
|---|---|
| Top Navigation Bar | Wordmark, section links, sweep freshness, `Sweep now` (light fill) |
| **Dashboard Frame** | **One per map card** — macOS chrome bar over the ticket list |
| Metric Tile | The six page metrics, as one full-width strip above the maps |
| Logo Strip (Trust Bar) | **Not used** — the repo rides in each map card's chrome bar instead |
| Feature Card Row | **Superseded** by the Dashboard Frame as the map card |
| Data Table Row | Ticket rows inside a map card; the run ledger |
| CTA Section Card | The light Bone card: **the PRs awaiting Raj's merge word** |
| Status Pulse | 6px dot before any live/ongoing label |
| Footer | Four columns, mono headings, 14px links, 44px brand mark |

**Card-per-map is settled** (#182). Each map is a separate workstream; a single merged table
loses the boundary that makes the page readable.

## State colours

Ruled by Raj in #182. Four states across the two accents and two neutrals — **no third accent**.
Each state carries a glyph as well as a colour, so the scan survives without a red.

| State | Colour | Glyph | Why |
|---|---|---|---|
| Needs you | Warm Copper | `◆` | Copper is the attention signal; this is the only state that wants his hands |
| Ongoing | Teal | `●` | A centurion is on it — teal reads as progress |
| Queued | Bone | `○` | Takeable, waiting, neither urgent nor moving |
| Blocked | Graphite Mid | `⊘` | Stalled behind another ticket; recedes on purpose |

This inverts Factory's own reading of its two accent slots, where the signal accent is *live
status* and the metric accent is *settled*. The swap is deliberate: on this page "needs Raj" is
the one thing that must be seen first, and nothing else may take the signal colour.

## Deviations from `factory.md`

Recorded, with the reason, so a future change has to beat them rather than rediscover them.
Everything not listed here follows the source spec.

1. **The Dashboard Frame is a content card, not the product hero.** `factory.md` gives it the
   role "product hero — the live software factory preview". Here every map card is one. The
   reason is Raj's, at round 6: the hero was the only beautiful object on the page because it
   was the only thing using Factory's best component, and the fix is to spend that component
   where the content is rather than keep an oversized hero for its looks. Verified free: the
   framed card measured 14px *shorter* than the bordered card it replaced.
2. **The frame's bar title is 20px mono, not 12px.** The map's issue number is the identity Raj
   navigates by — he names working sessions after it (`178-ui`) — so it is sized to be scanned
   across six cards, not read once.
3. **Density is tight, not "comfortable".** Section gap 56px rather than 96px, row padding 7px
   rather than 11px. Measured saving: 400px on a 4-map page, on a surface opened many times a
   day. Factory's comfortable density is written for a marketing page that is read once.
4. **No sparklines in the Metric Tiles.** `factory.md` puts a 40px sparkline in every tile. The
   trend data does not exist yet — the series in the first prototype were invented, and invented
   data does not ship. Restore them only against real history from `caesar-runs`.

## Do's and Don'ts

### Do
- Keep the canvas `#101010` in every band. Light cards (`#eeeeee`) are the only bright objects.
- Use Geist 400 for everything. Weight 500 only when a label must dominate a dense surface.
- Apply negative letter-spacing proportionally to size: -0.04em at 72px, -0.025em at 44px,
  -0.02em at 12px. Display type earns its weight through tightness, not boldness.
- Reserve copper for live status, running state, and accent strokes in data charts.
- 3px radius on buttons and nav, 10px on cards, 20px on the largest panels. No softer.
- Build depth through `#eeeeee`-on-`#101010` contrast and 96px+ section gaps.
- Use Geist Mono 12px uppercase for eyebrows, status labels, ticket numbers and column headers.

### Don't
- Do not introduce a third accent colour. Two neutrals, one warm gray, two functional accents.
- Do not use weight 600+ or bold for headings.
- Do not put copper or teal on button backgrounds, card surfaces, or large text fills. They are
  data-voice colours, not chrome colours.
- Do not use line-height above 1.5.
- Do not add drop shadows, glows, or blurs to anything.
- Do not mix in serif or display typefaces. Geist and Geist Mono only.
- Do not fill buttons with an accent. The primary action is a neutral dark fill (`#1d1a18`) or a
  neutral light fill (`#fafafa`).

## Surfaces

| Level | Name | Value | Purpose |
|-------|------|-------|---------|
| 0 | Obsidian Canvas | `#101010` | Page base, hero, all non-card sections |
| 1 | Carbon Lift | `#1d1a18` | Nav well, inline buttons, hairline dividers |
| 2 | Bone Card | `#eeeeee` | Light cards on dark ground — the signature figure/ground move |
| 3 | Chalk Elevated | `#fafafa` | Light button fill, top of the light surface stack |

## Motion

Short and mechanical: 0.15s–0.2s, `cubic-bezier(0.4, 0, 0.2, 1)`. Colour, background-color,
border-color and stroke transition together so a state change reads as one switch flipping.
No spring physics, no parallax, no scroll-driven effects — the surface stays still and precise.

## Voice & Type Treatment

Two voices, one family. Geist 400 carries prose. Geist Mono 12px uppercase carries every
instrument label: column headers, status tags, ticket numbers, nav items. The split is
structural — when mono appears, the reader knows they are looking at a system surface.

Note this is the *visual* register only. Caesar's spoken register is set by the `caesar` skill,
and the `status.ps1` table stays undecorated regardless.

## Reference implementation

`docs/prototypes/command-centre.html` — every variable ruled in #182, no switches. This is what
the renderer (#183) is built against. It runs on the fixture in `docs/prototypes/fixture.md` via
`docs/prototypes/data.js`.

The nine rounds that produced it are kept beside it, each with its own switch so a ruling can be
re-examined against what it beat: `r2-card-body.html` (card body), `r3-card-grid.html` (width),
`r4-state-legibility.html` (state), `r5-top-of-page.html` (the hero), `r6-framed-cards.html`
(the frame), `r7-finishing-pass.html` (metrics, density and the small variables),
`r8-second-half.html` (the queue section), `r9-the-gate.html` (the PR lines).

`s2-factory.html` is the round-zero implementation, superseded but kept as the system's plain
reading. `s1-slash.html` and `s3-modal.html` remain the rejected alternatives.

Two further prototypes are kept as the rejected alternatives, in their own native palettes,
each with its unmodified source spec beside it in `docs/prototypes/design-md/`:
`s1-slash.html` (Slash) and `s3-modal.html` (Modal). They are reference, not fallback.
