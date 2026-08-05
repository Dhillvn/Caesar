# What published sources already settle about model and effort choice

Research for [#58](https://github.com/Dhillvn/caesar/issues/58). Desk work only — no model runs, no
experiments. Builds on [#50](https://github.com/Dhillvn/caesar/issues/50)
(`docs/research/model-effort-dispatch.md`) and [#55](https://github.com/Dhillvn/caesar/issues/55)
(`docs/research/caesar-run-corpus.md`); neither is re-derived here.

## Method, and an honest limit on it

Web reading was done with the **Firecrawl MCP tools** (`firecrawl_scrape`), per the workspace
convention. Firecrawl was available; no fallback to WebSearch/WebFetch was needed.

**The limit, stated up front because it shapes what follows.** This ticket ran under a hard USD
budget cap. Loading the `claude-api` skill (which its own trigger rules require for any task about
Claude model IDs, pricing or flags) put a very large reference corpus into context, and because
every subsequent turn re-bills the whole context, the budget went from $0.27 to $3.89 across a
single scrape. That left room for **one** live documentation fetch, not the six or seven planned.

So this document is honest about a split that matters:

- **The effort parameter is verified against a live Anthropic page**, read 2026-08-05.
- **Model IDs, pricing, and context windows are quoted from Anthropic's own bundled reference
  material** (the `claude-api` skill's cached tables, stamped `2026-06-24`) — Anthropic-authored,
  but a cache, not a live page. They are tiered accordingly and are **not** presented as live-verified.
- **The third-party agentic-benchmark survey was not done on attempt 1.** It is **now done** — §5,
  added on attempt 2, which was dispatched for that purpose alone and forbidden from loading
  `claude-api` again. Nothing in §5 comes from recollection; every claim there carries a URL and the
  access date 2026-08-05, and vendor claims encountered along the way are quarantined in §5.6 rather
  than laundered into the table.

**Why attempt 1 could afford only one fetch, recorded because it is a reusable operational fact.**
The cost was context size, not web reading. Attempt 1 spent **1.7M cache-read tokens to produce 12.7K
output tokens**; the `claude-api` skill load injected ~340K tokens, after which every turn re-billed
~400K, while its actual Firecrawl fetches totalled ~17K. Attempt 2 ran the entire tier-D survey on
two searches and three narrow scrapes.

## Tiers used throughout

| Tier | Meaning |
|---|---|
| **A — Anthropic primary, live** | Read from an Anthropic-operated page during this ticket, with URL and access date. |
| **B — Anthropic primary, cached** | Anthropic-authored text bundled into the harness, with its own cache stamp. Authoritative in origin, stale in time. |
| **C — Measured here** | A probe or artifact from #50 / #55 on this machine. Not published, but observed. |
| **D — Third-party, disclosed method** | Published benchmark or evaluation with a stated harness. §5 is the tier-D survey. Sources whose method is only partly disclosed are graded down inline and say so. |
| **E — Inference** | Reasoning from A–C. Carries no independent authority. Labelled `(inference)` inline. |

An uncited claim appears nowhere below. Where the evidence ran out, the section says so.

---

## 1. The effort parameter — tier A

Source: `https://platform.claude.com/docs/en/build-with-claude/effort.md`, read **2026-08-05**.

### 1.1 What effort actually controls

> "The effort parameter affects **all tokens** in the response, including: Text responses and
> explanations; Tool calls and function arguments; Thinking (when active)."

And:

> "It doesn't require thinking to be enabled. It can affect all token spend including tool calls.
> For example, lower effort would mean Claude makes fewer tool calls."

**This contradicts what I expected and what #50 implicitly assumed.** #50 treated effort as a
thinking-depth dial and concluded its cost effect was unmeasurable because a trivial probe moved
output by only ~200 tokens. That conclusion was right about the probe and wrong about the
mechanism: on a trivial single-turn prompt there are no tool calls to consolidate, so the probe was
structurally incapable of exercising the parameter's main lever.

This matters directly for Caesar, because #55 established that **turn count**, not startup context,
drives the cost tail. Effort is documented to act on exactly that variable. **Called out explicitly
as a place where the live docs contradict the prior expectation.**

### 1.2 Levels, and which models have which

Live page enumerates `low`, `medium`, `high`, `xhigh`, `max`.

| Level | Documented use | Availability (per the live page) |
|---|---|---|
| `max` | "Tasks requiring the deepest possible reasoning" | Fable 5, Mythos 5, Opus 5, Opus 4.8, Mythos Preview, Opus 4.7, Opus 4.6, Sonnet 5, Sonnet 4.6 |
| `xhigh` | "Long-running agentic and coding tasks (over 30 minutes) with token budgets in the millions" | Fable 5, Mythos 5, Opus 5, Opus 4.8, Opus 4.7, **Sonnet 5** |
| `high` | "Equivalent to not setting the parameter" | all effort-supporting models |
| `medium` | "Balanced approach with moderate token savings" | all |
| `low` | "Simpler tasks... **such as subagents**" | all |

Two structural notes from the page: `xhigh` is newer than `max`, so "some models that support `max`
don't support `xhigh`" — the ladder is not uniformly ordered across models. And effort is
supported on Fable 5, Mythos 5, Opus 5, Opus 4.8, Mythos Preview, Opus 4.7, Opus 4.6, Sonnet 5,
Sonnet 4.6 and Opus 4.5 — **notably not** Haiku 4.5.

`xhigh`'s definition names Caesar's exact workload shape: long-running agentic work over 30 minutes.
#55 measured Caesar-family runs at median 6.5 min, p90 12.6 min, max 112 min — so **the documented
`xhigh` use case describes only Caesar's tail, not its median.** (inference)

### 1.3 API default is `high` — and Caesar runs below it

> "By default, Claude uses high effort... Setting `effort` to `"high"` produces exactly the same
> behavior as omitting the `effort` parameter entirely."

Caesar's user `settings.json` carries `"effortLevel": "medium"` (tier C, from #50). **Every Caesar
ticket to date has therefore run one notch below the API default**, and no one decided that — it is
a setting nobody derived, exactly like `-BudgetUsd 2.0` in #55. Worth stating plainly because it
reframes #56: the question is not only "should we lower effort to save money", it is "was lowering
it already the wrong default?"

### 1.4 Per-model guidance, verbatim where it matters

**Opus 5** (Caesar's current model):

> "**Start with `high`, the default**, and adjust based on your evals: step up to `xhigh` for
> demanding coding and agentic work, or to `max` when a task justifies unconstrained token spending,
> and use `low` and `medium` liberally as your primary control for token cost and response time
> wherever your evals show quality holds. **If you carried effort settings over from an earlier
> model, run a fresh effort sweep on your evals rather than reusing them.**"

That last sentence is Anthropic telling you the thing #56 exists to do.

Also on Opus 5, two hard constraints:

> "Effort controls thinking volume, not visible response length: on Claude Opus 5, changing effort
> does not reliably shorten responses."

> "On Claude Opus 5, thinking cannot be disabled at `xhigh` or `max` effort: requests that set
> `thinking: {"type": "disabled"}` at those levels return a 400 error."

**Sonnet 5** — the model Caesar has never once run (#55: zero Sonnet-driven ticket runs exist):

> "Claude Sonnet 5 defaults to `high` effort on the Claude API and Claude Code."
> "**Medium effort:** Cost-saving step-down from the default. **Comparable to Claude Sonnet 4.6 at
> high effort.**"
> "**Xhigh effort:** For the hardest coding and agentic tasks."

Sonnet 5 supporting `xhigh` is significant: the cheaper model is not excluded from the effort level
whose documented purpose is long-horizon agentic work. A Sonnet-5-at-`xhigh` configuration is
therefore a legal point in the grid, not a category error. (inference)

**Opus 4.7 / 4.8** guidance inverts Opus 5's: "Start with `xhigh` for coding and agentic use cases."
That Opus 5's guidance moves the recommended start *down* to `high` is a real generational
difference, not a docs inconsistency — the page states both deliberately and in adjacent sections.

### 1.5 The finding Caesar will care about most

> "Because effort shapes the rendered prompt, changing it between requests does not preserve cached
> prefixes from earlier turns; if you rely on prompt caching across a long session, pick an effort
> level at the start and keep it constant."

And in best practices: "**Hold effort constant within cached conversations.**"

#50 measured that cache write is the per-run cost floor ($0.24 Sonnet / $0.40 Opus, cold). Combine
the two: **any dispatch design that varies effort mid-run pays a fresh cache write at the moment it
varies.** That kills, on documentation alone, an entire class of designs — "start low, escalate when
the ticket looks hard", "drop to low for the wrap-up turn" — without #56 needing to spend a cent on
them. (inference, from tier A + tier C)

Per-run effort selection (one level, fixed for the whole ticket) is unaffected. That is the only
shape worth testing.

### 1.6 Effort is not a token budget

> "Effort is a behavioral signal, not a strict token budget. At lower effort levels, Claude will
> still think on sufficiently difficult problems, but it will think less than it would at higher
> effort levels for the same problem."

So effort cannot be used as a spend guard. `-BudgetUsd` remains the only hard cap, and #55's
recommendation of `$5.00` is untouched by anything here.

---

## 2. Models and prices — tier B

From the `claude-api` skill's bundled model table, **cache-stamped 2026-06-24**. Anthropic-authored;
not re-verified live in this ticket. Treat every number here as needing a live check before it is
frozen into a dispatch policy.

| Model | ID | Context | Input $/MTok | Output $/MTok |
|---|---|---|---|---|
| Claude Opus 5 | `claude-opus-5` | 1M | $5.00 | $25.00 |
| Claude Sonnet 5 | `claude-sonnet-5` | 1M | $3.00 ($2.00 intro through 2026-08-31) | $15.00 ($10.00 intro) |
| Claude Haiku 4.5 | `claude-haiku-4-5` | 200K | $1.00 | $5.00 |

Two things this changes about #50's arithmetic:

1. #50 derived Opus:Sonnet = **1.67×** flat from observed `costUSD`. The list prices agree
   ($5/$3 = 1.667, $25/$15 = 1.667). Independent confirmation of a measured result — one of the few
   places in this document where two tiers corroborate.
2. **There is an introductory Sonnet 5 price of $2/$10 running through 2026-08-31.** Today is
   2026-08-05. Any Sonnet-vs-Opus cost comparison run in #56 during the next 26 days measures
   **2.5×**, not 1.67×, and that discount then expires. #56 must record which price was in force, or
   its numbers become unreadable in September. This is a live trap and nothing in #50 or #55
   anticipates it.

Model IDs carry no date suffix (`claude-opus-5`, not `claude-opus-5-20260xxx`) — the bundled
reference is emphatic about this, and #56's banked n=1 result (invalid `--model` → HTTP 404, one
turn, $0.00, fails loud and free) is the safety net if an ID is ever wrong.

---

## 3. What #50 and #55 already settled — not re-derived

Carried forward as established, for the transferability argument below:

- CLI flag beats user `settings.json`; `--effort` warns-and-continues on a bad value, `--model`
  404s loud and free (tier C, #50 + #56 partial).
- `modelUsage` in the result JSON is billing truth; effort is **not** in the result JSON at all and
  lives only in the session transcript (tier C, #50).
- Opus is 1.67× Sonnet per token, flat, every token class (tier C, #50 — corroborated by tier B above).
- Ticket type does not predict cost; within-type variance dwarfs between-type variance (tier C, #55).
- Every run in the corpus was Opus-driven. **Zero Sonnet ticket runs exist anywhere** (tier C, #55).
- `-BudgetUsd 2.0` sits at p54.5 of completed cost; $5.00 recommended (tier C, #55).

---

## 4. Transferability — what published results cannot settle for Caesar

This is the section the ticket says Caesar actually needs, so it is written to be hard on itself.

**A Caesar ticket is a specific and unusual shape.** It is unattended; multi-turn (median 29 turns,
#55); it holds `git` and `gh` credentials; it runs under a hard budget cap that kills it mid-work;
and it counts as a success only if it closes its own ticket and opens a PR with no human watching.

### 4.1 What transfers

- **Effort's mechanism.** "Lower effort → fewer tool calls" is a statement about the model's
  behaviour, not about a harness. Caesar's cost is turn-driven (#55), so the mechanism transfers
  even though the magnitude does not.
- **The cache-invalidation rule.** Prompt caching is API-level. It applies to any caller, Caesar
  included. This is the strongest transferable finding in the document — it eliminates designs
  without any measurement.
- **Price ratios.** Arithmetic on published per-token rates is harness-independent. What it does
  *not* tell you is total cost, because that depends on turn count, which is behavioural.
- **Hard API constraints** (thinking-disabled 400s at `xhigh`/`max`; `xhigh` absent on some
  `max`-supporting models). Configuration validity is not workload-dependent.

### 4.2 What does not transfer — and why

**Anthropic's per-model effort guidance is not written for an unattended, budget-capped run.** Every
recommendation on the effort page is framed as *"adjust based on your evals"*. It assumes a caller
with an eval suite and a human reading the outputs. Caesar has neither: its only success signal is
binary and terminal (did a PR appear, did the ticket close), and a failure is not a bad answer — it
is a run that burned its full budget and returned an empty `result` string. #55: 17 such runs cost
$56.44, 20% of all spend, for zero artifact. **No published benchmark scores that failure mode**,
because benchmarks retry, and a benchmark harness that fails a task loses a data point, not $3.

**Any single-shot coding score is the wrong shape entirely.** Caesar's unit of work is ~29 tool-using
turns against a real repo with real credentials. A published pass@1 on an isolated problem measures
a different thing and predicts Caesar's cost not at all.

**Even agentic benchmarks carry their harness with them.** The ticket's own framing is right: the
harness is most of the result. A published agentic score is a joint measurement of model × scaffold ×
tool surface × retry policy. Caesar's scaffold is `spawn-ticket-agent.ps1` plus the Wayfinder
guardrail prompt plus this repo's CLAUDE.md and skills — a combination that appears in no published
evaluation. #50 measured that this scaffold alone costs $0.24–$0.40 per cold start before any work
happens. That is a Caesar-specific constant no external number contains.

**The budget cap makes quality and cost non-separable.** In a benchmark, a model that takes more
turns scores the same and costs more. In Caesar, a model that takes more turns *hits the cap and
scores zero*. So a cheaper-per-token model that needs more turns can be both cheaper per token and
catastrophically worse in outcome. #55 says this explicitly and it bears repeating: **the flat 1.67×
Opus:Sonnet ratio is an arithmetic fact about token prices, not a prediction that Sonnet finishes
tickets for less.** Nothing published resolves this, because nothing published runs Caesar's
scaffold under Caesar's cap.

**Effort's documented low-effort use case is "subagents".** Caesar's centurions are not subagents —
they are the primary agent of their own run, holding write credentials and owning a deliverable.
Reading across from Anthropic's subagent guidance to Caesar's ticket agents is a category error, and
this document declines to make it. (inference)

### 4.3 The gap in one sentence

Published sources settle **which configurations are legal, what effort does mechanically, and what
tokens cost**; they cannot settle **how many turns a given model-and-effort takes to close a Caesar
ticket**, and turn count is the entire cost and the entire failure mode.

---

## 5. Third-party evidence — tier D

Added on the second attempt at this ticket, which was dispatched narrowly to close the gap §6.1
originally named. All sources below were read **2026-08-05**. Each is graded on one question the
ticket insists on: **does its harness resemble an unattended, multi-turn, budget-capped run that
must close its own ticket and open a PR?** Where the answer is no, that is stated and the result is
not stretched.

### 5.1 Long-Horizon Terminal-Bench (LHTB) — the closest published shape to Caesar

`https://zli12321.github.io/LHTB/` — read 2026-08-05, published July 2026.

Method, quoted from the page: 46 tasks across 9 categories, **18 frontier models**, one identical
harness (**Terminus-2**), one Docker container per task, **a 90-minute budget, one attempt, no
retries of bad runs**, and hidden replay-based verifiers paying continuous partial credit. A task
counts as solved at reward ≥ 0.95.

This is the **only** source found whose harness genuinely resembles Caesar's: unattended, hundreds
of dependent turns, a hard resource cap that fires mid-work, one shot, and a verifier that only
counts real artifacts. Its headline findings:

- Best model (Grok 4.5) averages **0.505** mean reward and solves **13 of 46**. Grok 4.5 "narrowly
  leads a trio of Anthropic models". **29 of 46 tasks have never been solved by any model.**
- Runs average **231 steps, 9.9M tokens, 85 minutes**.
- **"79% of unresolved runs time out while the agent is still actively making progress."**
- **"Price is not performance"** — MiniMax M3 scores 0.39 at ~$6/task, ahead of GPT-5.4 at $28.

**The transferable finding, and it is the strongest tier-D result in this document.** At
long-horizon scale the dominant failure mode is *not* incapability, it is **the cap firing on work
that was still progressing** — 79% of failures. #55 measured Caesar's version of exactly this: 17
runs burned $56.44, 20% of all spend, and returned an empty `result`. An independent 18-model,
identical-harness study finds the same failure mode dominates at this task shape. That corroborates
#55's cap analysis from outside this repo, and it argues that **cap headroom buys more completed
tickets than model or effort choice does** — because most losses are timeouts, not wrong answers.

**Limits, stated.** Per-model rewards on the page live in charts, not prose; this document therefore
does **not** quote a Claude-family reward figure from it, and the per-task cost figures the page
carries could not be tied to specific Claude 5-family model IDs with confidence. The page's
Anthropic entries also cannot be assumed to be Opus 5 / Sonnet 5. **LHTB does not settle row 7.**

### 5.2 Artificial Analysis on Opus 5 across effort — tier D, disclosed harness

`https://x.com/ArtificialAnlys/status/2080734447717298483` — posted 2026-07-24, read 2026-08-05.
Harness disclosed: **Stirrup**, AA's open-source reference agent harness, for the agentic
benchmarks; Intelligence Index run with Opus 4.8 server-side fallback enabled.

Two claims here bear directly on the tier-E rows:

> "Claude Opus 5's effort setting spans a wide range of token usage-performance tradeoffs. On
> GDPval-AA v2, effort levels span **407 Elo points**, with **output token usage ranging around 8x
> from low to max effort**."

> "Claude Opus 5 (max) costs **$2.03** on average per Intelligence Index task ... still above Claude
> Opus 4.8 (max) at $1.80 and **Claude Sonnet 5 (max) at $1.53**. However, **at high and xhigh
> reasoning efforts Opus 5 can outperform both Opus 4.8 and Claude Sonnet 5 at a lower cost per
> task**."

Also: "Claude Opus 5 (xhigh) with Claude Code leads the Artificial Analysis Coding Index"; 89% on
Terminal-Bench v2.1 at max effort.

**What this settles.** The 8x low→max output-token range is measured, third-party, and disclosed —
effort is a large cost lever, not a marginal one. **Row 9's premise is confirmed at the token level.**

**What it does not settle.** Token spend is not turn count, and AA reports no turn counts. It also
does not transfer cleanly to Caesar's cap: a per-task cost *average* over a benchmark says nothing
about the tail, and Caesar dies on the tail.

**Row 7 gets its sharpest published answer here, and it is the opposite of the intuition:** the
cheaper model is not the cheaper *completion*. AA's own comparison puts Opus 5 at high/xhigh
**above** Sonnet 5 on quality **at a lower cost per task**. That is a direct third-party rebuttal of
the "1.67× cheaper tokens ⇒ cheaper tickets" reasoning §4.2 warned about — and it comes from a
harness (Stirrup) that at least runs multi-step agentic work, unlike a single-shot score.

### 5.3 CursorBench 3.2, via Caylent — tier D, disclosed metric, secondary reporting

`https://caylent.com/blog/claude-opus-5-changes-improvements-and-how-it-compares-to-fable-5` —
read 2026-08-05. Caylent reports CursorBench 3.2 (`https://cursor.com/cursorbench`), described as
"ambiguous, multi-file software-engineering work drawn from real Cursor sessions", reporting
**score, token use, steps, and average cost per task across effort settings**, with cost computed
from published token prices.

| Config | Score | Avg benchmark cost/task |
|---|---|---|
| Opus 5, **low** | 62.8% | **$2.55** |
| Opus 4.8, max | 62.3% | $5.77 |
| Opus 5, **max** | 70.0% | **$8.23** |
| Fable 5, max | 70.5% | $17.32 |

**Opus 5 at low effort costs 31% of Opus 5 at max and gives up 7.2 points.** This is the only
published table found that puts effort, quality *and* dollars on the same axes for Opus 5, and
CursorBench is the closest benchmark in this survey to Caesar's actual work (real multi-file repo
tasks, steps counted). It transfers **partially**: Cursor's harness is human-adjacent and retried,
not unattended and capped.

Caylent also states, of its own internal testing (methodology **not** disclosed — treat as weaker
than the CursorBench table): Opus 5 "producing significantly longer reasoning traces, which would
explain the cost-per-task increase compared to Opus 4.8", and that Opus 5 "is unlikely to work as a
drop-in replacement. You will need to recalibrate the thinking effort assigned to each task."

### 5.4 CodeRabbit on Opus 5 effort levels — tier D, disclosed configs, wrong harness shape

`https://www.coderabbit.ai/blog/opus-5-model-review` — read 2026-08-05. Three configurations run on
their production review pipeline: junior profile at **medium** (their default), senior at **high**,
senior at **xhigh**; three-run averages against a known-issue benchmark.

- Opus 5 xhigh vs their production baseline: actionable precision **39.3% vs 35.2%**, but known
  issues caught **55.2% vs 61.1%**, and ~**4× the nitpicks**.
- **"More reasoning did not consistently produce a better review."** The junior/**default (medium)**
  configuration **found the most issues** when every comment class was counted.
- Token behaviour is **not monotonic in effort**: "X-high was the heaviest writer, producing 10.8k
  output tokens per call. More effort did not automatically mean more output: **High wrote less than
  junior/default**."
- Their recommendation: "**Test every relevant effort level, including low and medium.** More
  reasoning changed the trade-off in our runs; it did not consistently improve the review."

**Transfer: poor, and it is reported as poor.** A code review is a single large-context call, not a
29-turn tool-using loop; its "quality" metric is precision/recall of comments, which has no Caesar
analogue. What *does* carry is the shape of the result — **effort is a trade between failure modes,
not a quality dial** — and the non-monotonic token finding, which is a direct warning against
assuming `low < medium < high < xhigh` in spend.

### 5.5 FrontierCode v1.1, via SitePoint — tier D, but methodology partly undisclosed

`https://www.sitepoint.com/claude-opus-5-medium-effort-frontiercode-benchmark/` — read 2026-08-05.
Reports Opus 5 peaking at **medium** effort (53.4% main / 63.6% extended), with high "plateaued or
marginally declined" at roughly 3× the relative compute of low versus ~1.5× for medium.

**Graded down deliberately.** The article itself discloses that most scores are approximate
("~") and that "**relative compute cost methodology is undisclosed** — it is not confirmed whether
these multipliers reflect total tokens consumed, thinking tokens only, or another metric." It is a
secondary write-up, not the benchmark's own publication. It is recorded here as *directionally
concordant with CodeRabbit* and is **not** used to settle a row on its own.

### 5.6 Vendor claims encountered and explicitly not laundered

Anthropic's Sonnet 5 launch page (`https://www.anthropic.com/news/claude-sonnet-5`, read 2026-08-05)
carries customer testimonials — "that used to stall halfway", "finishes complex tasks where previous
Sonnet models would stop short", "carried each one through to a tested, verified result on its own"
— which describe exactly Caesar's success condition. **They are marketing testimonials with no
disclosed method, no harness and no n.** They are recorded as vendor claims and settle nothing. The
same goes for a Terminal-Bench figure of 76.1% for Sonnet 5 seen only in a LinkedIn post, which is
not traced to a primary source here and is therefore **not** carried into the table.

### 5.7 Where the literature contradicts itself — and why that is the result

On the single question "is higher effort better", the four tier-D sources **do not agree**:

- CursorBench: **max ≫ low** (70.0% vs 62.8%) — monotonic, at 3.2× the cost.
- AA/GDPval-AA v2: **407 Elo across the effort span** — strongly monotonic.
- CodeRabbit: **medium found the most issues**; xhigh traded recall for precision.
- FrontierCode (weak): **medium is the peak**; high plateaus or declines.

That split is not noise, it is the point: **effort's payoff is a property of the harness and the
task, not of the model.** No published number therefore transfers to Caesar's harness, and any
attempt to pick Caesar's effort level from these tables would be picking someone else's harness.
**Row 6 is narrowed but not settled**, and #56 remains the only way to close it.

---

## 6. Provisional dispatch table

Built from published evidence plus the two prior tickets. Every row carries its tier. Rows marked
**E** rest on inference and are #56's test list.

| # | Decision | Provisional call | Tier | Basis |
|---|---|---|---|---|
| 1 | Effort varies within a run? | **No — fixed per run** | A | Live docs: changing effort between requests invalidates the cached prefix; "pick an effort level at the start and keep it constant" |
| 2 | Split the table by ticket type? | **No — one default for all AFK types** | C | #55: within-type variance dwarfs between-type; IQRs overlap across nearly their whole width |
| 3 | Budget cap | **`-BudgetUsd 5.00`** | C | #55: p97 of completed cost; kills 3/101; a fired cap costs its full value and returns nothing |
| 4 | Effort as a spend guard? | **No** | A | Live docs: "a behavioral signal, not a strict token budget" |
| 5 | Model for AFK tickets | **Opus 5** *(hold)* | C | #55: every one of 101 completed runs was Opus; zero Sonnet ticket runs exist. Holding is the evidenced position, not a preference |
| 6 | Effort for AFK tickets | **Unsettled — test `medium` vs `high`** | **D (conflicting)** | §5.7: four tier-D sources disagree on whether higher effort helps. CursorBench and AA say strongly yes; CodeRabbit and FrontierCode say medium is the peak. Effort's payoff is a harness property. `high` remains the API default; Caesar's `medium` was still never derived |
| 7 | Is Sonnet 5 viable at all? | **Test — but expect Opus 5 to win on cost, not just quality** | **D** | §5.2 (AA/Stirrup, 2026-07-24): "at high and xhigh reasoning efforts Opus 5 can outperform both Opus 4.8 and Claude Sonnet 5 **at a lower cost per task**." Third-party rebuttal of the cheaper-tokens-⇒-cheaper-tickets premise. Not conclusive for Caesar's harness, but the prior has flipped |
| 8 | `xhigh` for the long tail? | **Yes for tail tickets, no as a default** | **D** | §5.2: Opus 5 (xhigh) + Claude Code leads AA's Coding Agent Index. §5.4: xhigh was the heaviest writer (10.8k output tok/call) and traded recall for precision. Cost-justified only where the tail is real; #55 puts only Caesar's tail past 30 min |
| 9 | Does low effort actually cut turns? | **Cuts tokens ~8×; turn effect still unmeasured** | **D (partial)** | §5.2: output token usage spans ~8× low→max on GDPval-AA v2. §5.3: Opus 5 low costs 31% of max for −7.2 pts. §5.4 warns spend is **non-monotonic** in effort (high wrote less than medium). No published source reports turns-vs-effort |
| 10 | Effort proof in the run artifact | **Write the flag at spawn time** | C | #50: effort appears nowhere in the result JSON; transcript-only, and transcripts are not run artifacts |
| 11 | Record the Sonnet price in force | **Required for any #56 cost run** | B | Sonnet 5 intro pricing ($2/$10) expires 2026-08-31; runs before and after are not comparable |
| 12 | Invalid config safety | **Model fails loud; effort fails silent** | C | #50 + #56 partial: bad `--model` = 404, $0.00; bad `--effort` = stderr warning, exit 0, silently re-resolves |

### The shortlist #56 must test

**Revised after the tier-D survey. Two of the four rows come off the list.**

- **Row 8 — drop from #56.** §5.2 and §5.4 between them give a defensible call: `xhigh` for the
  tail, not as a default. Spending Caesar money to re-derive it is waste.
- **Row 9 — reduce, do not drop.** The token half is settled at tier D (~8× span). What is left is
  one narrow question — *does low effort reduce the number of turns on a real Caesar ticket* — and
  §5.4's non-monotonic result means it cannot be assumed. That is a single cheap probe, not a sweep.
- **Row 7 — keep, with the prior flipped.** Still worth one run, because §4.2's argument stands: no
  published source runs Caesar's scaffold under Caesar's cap. But it is now a **falsification** test
  of a third-party expectation ("Opus 5 wins on cost too"), not an open question, and it should be
  scoped as one run, not a comparison sweep.
- **Row 6 — keep, and it is now the only genuinely open row.** §5.7: the literature contradicts
  itself on medium-vs-high, and the contradiction is explained by harness dependence, which means
  only Caesar's own harness can answer it.

So #56's list shrinks from four one-dimensional questions to **row 6 (medium vs high, the real
experiment), row 7 (one Sonnet 5 run as a falsification), row 9 (one low-effort turn-count probe)**.

Note what the shortlist is *not*: it is not a model × effort grid. Rows 1, 2 and 4 collapse the grid
before it is built — no mid-run variation, no per-type split, no effort-as-budget. That collapse,
plus the tier-D trimming above, is this ticket's main deliverable.

**One finding sits outside the table and belongs on #51, not #56.** §5.1: in an 18-model,
identical-harness, budget-capped study, **79% of unresolved runs timed out while still making
progress**. #55 measured Caesar's version (17 empty runs, $56.44, 20% of spend). Independent
corroboration that at this task shape **cap headroom buys more completed work than model or effort
choice does.** If only one lever gets tuned, the published evidence says tune the cap.

---

## 7. What this document does not establish

Stated explicitly, because a gap named is a result and a gap papered over is a trap.

1. ~~The third-party agentic-benchmark survey was not performed.~~ **Closed on attempt 2 — see §5.**
   What remains open within it: **no published source reports turn count against effort level**, and
   **no per-model reward figure for a Claude 5-family model could be extracted from LHTB** (§5.1),
   whose charts are not machine-readable and whose Anthropic entries could not be pinned to specific
   model IDs. Both are named rather than guessed. §4.2's argument survives the survey intact: every
   tier-D score carries its own harness, and §5.7 shows those harnesses disagree with each other.
2. **Pricing, model IDs and context windows were not re-read from a live page.** They are tier B.
   Verify before freezing them into a policy.
3. **Model deprecation and alias schedules** were not checked at all. Unknown whether `claude-opus-5`
   has a retirement date.
4. **Claude Code CLI documentation for `--model` / `--effort`** was not re-read live; §3's claims
   about flag precedence are #50's measurements on this machine (tier C), which is stronger evidence
   for *this* installation than a docs page, but says nothing about other versions.
5. **No cost or quality figure in this document was produced by running a model.** Every number is
   either quoted, or arithmetic on quoted numbers, or carried from #50 / #55.
