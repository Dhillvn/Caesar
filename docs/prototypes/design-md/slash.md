# Slash — Style Reference
> Midnight vault with gilded ledger lines.

**Source:** https://styles.refero.design/style/7c38e84b-aea0-4c8f-b3e9-60b994ee6c6b
**Retrieved:** 2026-08-16
**Theme:** dark

Slash operates in a midnight gallery mode: an almost-black canvas, white type, and a single warm copper accent that functions as editorial punctuation. Display headings are set in Ivy Presto, a high-contrast didone serif used at extreme sizes (up to 88px) — this serif-versus-sans collision is the system's signature, lending financial seriousness without the stockbroker gravitas of traditional banking. The rest of the UI is deliberately quiet: thin borders, pill-shaped controls, compact 16px body text, and barely-there elevation that lets the serif breathe. A single golden gradient (chart line, micro-accents) injects warmth into an otherwise monochrome system, evoking the warm glow of a Bloomberg terminal rendered for a design audience.

## Tokens — Colors

| Name | Value | Token | Role |
|------|-------|-------|------|
| Obsidian | `#08080a` | `--color-obsidian` | Page canvas, footer background, deepest surface — near-black with the faintest blue undertone |
| Onyx | `#040406` | `--color-onyx` | Card surface, secondary backdrop — one step deeper than the page for visual weight |
| Carbon | `#121317` | `--color-carbon` | Elevated panels, subtle UI fills — the first clearly lighter step in the surface stack |
| Graphite | `#1c1d22` | `--color-graphite` | Borders, dividers, icon containers, slider controls — the hairline color that defines structure |
| Slate | `#2e3038` | `--color-slate` | Secondary borders, muted icon strokes, subtle dividers between content blocks |
| Smoke | `#464853` | `--color-smoke` | Tertiary borders, inactive nav items — barely visible structural lines |
| Ash | `#5e616e` | `--color-ash` | Muted body text, placeholder content, secondary metadata |
| Steel | `#777a88` | `--color-steel` | Button borders, icon strokes, secondary text, ghost button outlines |
| Fog | `#9194a1` | `--color-fog` | Nav text, body descriptions, helper text — the workhorse readable gray |
| Mist | `#acafb9` | `--color-mist` | Subdued body copy, supplementary text, less-emphasized paragraphs |
| Silver | `#c7c9d1` | `--color-silver` | Light body text, medium-emphasis paragraphs, secondary headings |
| Bone | `#e2e3e9` | `--color-bone` | High-emphasis body text, dense data labels, the default text tone across most UI |
| Paper White | `#ffffff` | `--color-paper-white` | Primary action button fill, headings, nav active state — reserved for elements that must command attention |
| Copper | `#cc9166` | `--color-copper` | Category labels, editorial links, warm accent punctuation — the only chromatic color, used sparingly |
| Gilded Gradient | `linear-gradient(103deg, rgb(174,147,87), rgb(255,240,204) 40%, rgb(174,147,87) 70%, rgba(189,157,79,0))` | `--gradient-gilded` | Chart line stroke, financial data visualization accent |

## Tokens — Typography

### Ivy Presto · `--font-ivy-presto`
- **Substitute:** Playfair Display, DM Serif Display, Libre Caslon Display
- **Weights:** 400, 500
- **Sizes:** 28px, 44px, 52px, 64px, 88px
- **Line height:** 1.0–1.38
- **Letter spacing:** 0.0100em
- **Role:** Display and heading serif — used exclusively for hero headlines and section titles at 28px and above. The high-contrast didone strokes with hairline serifs create editorial luxury; the slight 0.01em positive tracking is unusual and gives the type a printed, ledger-like feel. This serif is the primary brand signature.

### Inter · `--font-inter`
- **Weights:** 300, 400, 500, 600, 700
- **Sizes:** 12, 13, 14, 15, 16, 18, 20, 24, 48
- **Line height:** 1.0–1.56
- **Letter spacing:** -0.04em, -0.025em, -0.02em, -0.013em, -0.007em, 0.01em
- **Role:** UI sans — body, nav, buttons, labels, links, form fields, and the 48px subhead level. The 300 weight appears on 18px body for whisper-quiet secondary copy; 500 dominates for medium-emphasis text and button labels; 600 is reserved for small-caps category labels.

### Type Scale

| Role | Size | Line Height | Letter Spacing | Token |
|------|------|-------------|----------------|-------|
| eyebrow | 13px | 1 | -0.26px | `--text-eyebrow` |
| body-xs | 16px | 1.5 | — | `--text-body-xs` |
| body-sm | 18px | 1.38 | -0.36px | `--text-body-sm` |
| body | 20px | 1.38 | -0.8px | `--text-body` |
| subheading | 24px | 1 | -0.31px | `--text-subheading` |
| heading-sm | 44px | 1.38 | 0.44px | `--text-heading-sm` |
| heading | 52px | 1.13 | 0.52px | `--text-heading` |
| heading-lg | 64px | 1.13 | 0.64px | `--text-heading-lg` |
| display | 88px | 1 | 0.88px | `--text-display` |

## Tokens — Spacing & Shapes

**Density:** compact

Spacing scale: 4, 6, 8, 9, 10, 12, 14, 16, 20, 22, 24, 32, 40, 48, 105, 224

### Border Radius

| Element | Value |
|---------|-------|
| nav | 2px |
| tags | 9999px |
| cards | 10px |
| icons | 9999px |
| inputs | 9999px |
| buttons | 9999px |

### Shadows

| Name | Value |
|------|-------|
| subtle | `rgba(255,255,255,0.2) 0 0 0 1px` (icon rings only) |

### Layout

- **Page max-width:** 1216px
- **Section gap:** 160px
- **Card padding:** 24px
- **Element gap:** 8px

## Components

### Primary Action Button
**Role:** Highest-emphasis interactive element — final conversion

Pill-shaped, 9999px radius. White (#ffffff) fill, black (#000000) text at 14px Inter weight 500. Padding 10px 20px. No border. The white-on-black inversion is the system's only loud visual signal — treat it as a rare resource.

### Ghost Outline Button
**Role:** Secondary action — paired with the primary in the header

Transparent fill with 1px white (#ffffff) border, 9999px radius. White text at 14px Inter weight 500. Padding 10px 20px.

### Pill Tag Button
**Role:** Category filter, status indicator, small inline action

Transparent background, 1px border in #777a88, 9999px radius, padding 6px 10px. White text at 12–14px Inter. The border color is intentionally cool gray, not white, to read as secondary.

### Hero Chart Card
**Role:** Showcase product visualization in the hero

Dark surface (#040406) with 10px radius. No visible border. Contains a balance header, period filter pill, a golden gradient line chart, and an input field. The chart line uses the gilded gradient (linear-gradient 103deg) as its stroke — this is the only place where the copper/gold accent animates the page.

### Transaction List Card
**Role:** Dense data display panel

Right-side panel in hero, 10px radius, transparent fill. Rows with icon avatars. Each row: icon well (1px border #2e3038, 9999px) + name + amount right-aligned. Dense vertical rhythm.

### Blog Post Card
**Role:** Editorial content card for insights/articles

10px radius, transparent fill. Top: image at native aspect ratio. Below: category eyebrow in Copper (#cc9166) at 13px Inter weight 600, date separator, then title in 18–20px Inter weight 500 in white. Read-time meta at bottom in #acafb9. No border — cards separate through whitespace alone.

### Email Capture Input
**Role:** Hero CTA field

Transparent fill, 1px white (#ffffff) border, 9999px radius. Padding 10px 10px 10px 20px. Placeholder text in #777a88. The pill shape matches the primary button — input and button read as a single unit.

### Navigation Link
**Role:** Top-level menu item

No background, no border. Text at 14px Inter in #9194a1 (inactive) or #ffffff (active/hover). Padding 6px 10px. 2px underline radius on hover indicators.

### Status Badge — Active
**Role:** Positive state indicator in data tables

Small pill, transparent fill with 1px green-toned border. Text in green at 12px Inter weight 500. 9999px radius, 2px vertical padding. The green is a desaturated sage that reads on dark without vibrating.

### Stat Display
**Role:** Large numerical proof point

Number in 28–44px Ivy Presto weight 400, white. Caption below in 14px Inter weight 400 in #9194a1. The serif numeral creates editorial gravitas for statistics.

### Category Eyebrow
**Role:** Section-above-section label, article category

13px Inter weight 600, letter-spacing -0.02em. Copper (#cc9166) for categories, #9194a1 for section types. Functions as a typographic period before each content block.

### Data Table Row
**Role:** Spend limit, virtual account, or transaction table

Transparent fill, 1px bottom border in #1c1d22. No row padding between cells — density is high. Column headers in #9194a1 at 14px. Cell values in #e2e3e9 at 14–15px. Right-aligned numerics. The table relies on hairline dividers, not card containers.

## Do's and Don'ts

### Do
- Use Ivy Presto for all display and heading text at 28px and above — never for body copy under 20px.
- Set body text at 16px Inter weight 400 with line-height 1.5 in #e2e3e9 (Bone) — this is the default readable tone.
- Use the white (#ffffff) filled pill button exclusively for the single most important action on each screen — it is a scarce visual resource.
- Apply Copper (#cc9166) only to category labels and editorial links — never to buttons, icons, or large text blocks.
- Use 1px borders in #1c1d22 or #2e3038 for card and table edges; never use drop shadows for elevation.
- Space sections with 160px vertical gaps on desktop — the generous breathing room lets the serif headlines dominate.
- Use 9999px border-radius for all buttons, inputs, tags, and status indicators; use 10px for cards and 2px for nav underlines.

### Don't
- Don't substitute Inter for Ivy Presto on display text — the serif/sans contrast is the brand's identity, not decoration.
- Don't introduce blue, green, or any chromatic color as a brand accent — Copper is the only warm note in the palette.
- Don't use the white filled button more than once per viewport — its power diminishes with repetition.
- Don't add drop shadows to cards, modals, or popovers — use surface color steps and 1px borders instead.
- Don't set body text larger than 20px in Inter — larger sizes belong in Ivy Presto.
- Don't use #ffffff for long-form body copy — switch to #e2e3e9 (Bone) to reduce eye strain on dark backgrounds.
- Don't apply the gilded gradient outside data visualization contexts — it is reserved for chart lines and financial data accents.

## Surfaces

| Level | Name | Value | Purpose |
|-------|------|-------|---------|
| 0 | Void | `#08080a` | Page canvas, page-level background |
| 1 | Card | `#040406` | Card surfaces, contained content blocks |
| 2 | Panel | `#121317` | Elevated panels, dropdown surfaces, input backgrounds |
| 3 | Floating | `#1c1d22` | Borders, dividers, floating UI elements, icon wells |

## Elevation

- **Icon rings:** `rgba(255,255,255,0.2) 0 0 0 1px` — the only shadow token in the system.

## Imagery

Photography is editorial and naturalistic: warm-toned portrait shots in real work environments. Images fill card frames edge-to-edge with no padding. A dark gradient overlay is applied to the bottom portion of testimonial cards for text legibility. The aesthetic is 'LinkedIn meets editorial magazine' — candid, human, slightly desaturated, never stock-photo polished. Product UI is shown in dark mode at full opacity, floating above the page on subtle dark surfaces — these are the hero's centerpiece. Icons are monochrome with 1px strokes in #2e3038 or #777a88, never filled with brand color.

## Layout

Max-width 1216px centered content with 160px vertical section gaps. The hero is a full-width dark canvas with a split composition: left-aligned serif headline at 64–88px with capture field below, and a large product UI card on the right at 50% width. Subsequent sections use a single-column centered headline (serif at 44–64px) with subtitle in Inter, followed by 3-column card grids. Navigation is a fixed top bar: logo left, center menu, right-aligned ghost + white filled pill. Footer is a dense link grid. The page alternates between content-rich grid sections and full-bleed stat callouts — rhythm is established by generous whitespace between bands, not by alternating background colors (the entire page is one continuous #08080a canvas).

## Agent Prompt Guide

### Quick Color Reference
- text: #e2e3e9 (body) / #ffffff (headings, emphasis)
- background: #08080a (page) / #040406 (card) / #121317 (panel)
- border: #1c1d22 (hairline) / #2e3038 (secondary)
- accent: #cc9166 (Copper — editorial links, category labels)
- primary action: #ffffff (filled action)
- chart accent: gilded gradient (rgb(174,147,87) → rgb(255,240,204))

### Example Component Prompts

1. **Hero section**: #08080a background, max-width 1216px centered. Left column: 88px Ivy Presto weight 400 white headline with 0.01em tracking, 20px Inter weight 400 #9194a1 subtext. Below: a pill-shaped input (transparent fill, 1px white border, 9999px radius, 10px 20px padding, #777a88 placeholder) joined to a white filled pill button. Right column: a dashboard card at #040406 with 10px radius showing a balance number (48px Inter weight 500 white), filter pill, and a golden gradient line chart.
2. **3-column card grid**: each card 10px radius, transparent fill, no border. Copper (#cc9166) category label at 13px Inter weight 600, date in #9194a1 at 13px, title in 20px Inter weight 500 white at 1.38 line-height. Meta at bottom in #acafb9. 16px column gap, 32px row gap.
3. **Testimonial video card**: 10px radius, full-bleed background photo with a 40% black-to-transparent gradient overlay at the bottom. No border, no shadow.
4. **Data table**: transparent background, 1px bottom border in #1c1d22 on each row. Column headers in #9194a1 at 14px Inter weight 500, cell values in #e2e3e9 at 15px Inter weight 400. Right-aligned numerics. Status column uses a pill badge: 9999px radius, 1px border, 12px Inter weight 500 text.
5. **Stat callout section**: centered. Large number in 44px Ivy Presto weight 400 white, caption below in 14px Inter weight 400 #9194a1. 160px vertical padding above and below.

## Serif/Sans Collision System

The defining structural choice is the pairing of Ivy Presto (a high-contrast didone serif) exclusively for headings 28px and above with Inter for all UI text below that threshold. This creates a two-tier typographic register: the serif speaks to editorial and aspirational moments (hero, section titles, large numbers), the sans handles functional and informational moments (body, labels, buttons). **Never cross the boundary — serif never goes below 28px, sans never goes above 48px.** The slight positive tracking on Ivy Presto (0.01em) gives it a printed, almost engraved quality, reinforced by the copper accent and gilded gradient that evoke financial ledgers and gold leaf.

## Similar Brands

Mercury · Arc · Brex · Ramp · Stripe
