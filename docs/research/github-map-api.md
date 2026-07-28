# GitHub issues API for driving a Wayfinder map

Research for [issue #3](https://github.com/Dhillvn/caesar/issues/3), part of the Caesar map ([issue #1](https://github.com/Dhillvn/caesar/issues/1)). Builds on [issue #4's resolution](https://github.com/Dhillvn/caesar/issues/4) — sub-issues and dependencies already confirmed working on `Dhillvn/caesar` (private repo), and that the numeric database `id` is required, not `#number`/`node_id`. This doc goes past "it works" into cost, edges, and the one-shot frontier query.

All commands below were run live against `Dhillvn/caesar` on 2026-07-28 unless marked otherwise. Three throwaway issues (#12, #13, #14) were created to test closed-blocker and concurrency semantics, then deleted (HTTP 410 confirmed). Issues 1, 2, 5–11 were not touched.

## 1. Sub-issues API

Endpoints ([REST docs](https://docs.github.com/en/rest/issues/sub-issues), fetched 2026-07-28):

| Op | Method + path |
|---|---|
| Get parent | `GET /repos/{owner}/{repo}/issues/{issue_number}/parent` |
| List sub-issues | `GET /repos/{owner}/{repo}/issues/{issue_number}/sub_issues` |
| Add sub-issue | `POST /repos/{owner}/{repo}/issues/{issue_number}/sub_issues` (body: `sub_issue_id`, optional `replace_parent`) |
| Remove sub-issue | `DELETE /repos/{owner}/{repo}/issues/{issue_number}/sub_issue` (body: `sub_issue_id`) — note singular `sub_issue` in the path, easy to typo |
| Reprioritize | `PATCH /repos/{owner}/{repo}/issues/{issue_number}/sub_issues/priority` (body: `sub_issue_id` + `after_id`/`before_id`) |

**GA status.** Shipped as REST API endpoints in the [2024-12-12 changelog](https://github.blog/changelog/2024-12-12-github-issues-projects-close-issue-as-a-duplicate-rest-api-for-sub-issues-and-more/) ("You can now use the REST API to view, add, remove, and reprioritize sub-issues"). Sub-issues themselves (the feature, not just the API) reached full GA per [community discussion #154148](https://github.com/orgs/community/discussions/154148): "the general availability of sub-issues, issue types, advanced search, and increased item limits in GitHub Projects." No preview header/opt-in is required today — **tested**: none of our calls needed a preview `Accept` header.

**Per-parent limit.** [Docs](https://docs.github.com/en/issues/tracking-your-work-with-issues/using-issues/adding-sub-issues): up to **100 sub-issues per parent** (raised from 50 per the [2025-09-11 changelog](https://github.blog/changelog/2025-09-11-a-rest-api-for-github-projects-sub-issues-improvements-and-more/)), and up to **8 levels of nesting**. Caesar's maps (10 children on issue #1) are nowhere near this.

**Availability.** Not stated explicitly as a plan-tier restriction anywhere I found — flagged as **unverified from docs text**. Empirically **tested**: works on `Dhillvn/caesar`, a **private** repo (`"private":true` confirmed in the live JSON below), under the account's default plan (issue #4 already established this; re-confirmed here incidentally via issue #13's repo object). Could not confirm the account's exact plan tier — `gh api user --jq .plan` returned `null` for this token's scopes.

## 2. Issue dependencies API

Endpoints ([REST docs](https://docs.github.com/en/rest/issues/issue-dependencies), fetched 2026-07-28):

| Op | Method + path |
|---|---|
| List blocked-by | `GET /repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocked_by` |
| Add blocked-by | `POST /repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocked_by` (body: `issue_id`, numeric) |
| Remove blocked-by | `DELETE /repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocked_by/{issue_id}` |
| List blocking | `GET /repos/{owner}/{repo}/issues/{issue_number}/dependencies/blocking` |

**GA + availability.** [2025-08-21 changelog](https://github.blog/changelog/2025-08-21-dependencies-on-issues/): "Dependencies on issues are now generally available!" and "issue dependencies are fully supported in the API and webhooks." Search snippet from that page (not independently re-verified against raw HTML) states Free/Pro/Team/Enterprise Cloud availability — **flagged as secondhand, not directly re-fetched** — but empirically **tested and working** on this private repo regardless.

**Limit.** [Changelog](https://github.blog/changelog/2025-08-21-dependencies-on-issues/): up to **50 issues per relationship type** (i.e. 50 blockers, 50 blocked-by, separately).

**Numeric id requirement — confirmed genuinely required, tested twice.**
- `gh api --method POST .../dependencies/blocked_by -f issue_id=<id>` (string form, `-f`) → **422**: `` "Invalid property /issue_id: `\"5001345092\"` is not of type integer." `` The endpoint rejects a stringified number.
- `gh api --method POST .../dependencies/blocked_by -F issue_id=<id>` (typed form, `-F`, sends a JSON integer) → succeeds.
- The `#number` and `node_id` were not accepted in issue #4's original test either (per its resolution comment); this session didn't need to re-test that half.

**`issue_dependencies_summary` — the important nuance the ticket asked about, and REST's advantage over GraphQL (see §3).**

Live test: created throwaway issue A (#12) and B (#13), added `B blocked_by A` while A was open, then closed A, and fetched B's `issue_dependencies_summary` at each step:

```
A open:   {"blocked_by":1,"total_blocked_by":1,"blocking":0,"total_blocking":0}
A closed: {"blocked_by":0,"total_blocked_by":1,"blocking":0,"total_blocking":0}
```

**Confirmed: `blocked_by` counts open blockers only (drops to 0 the instant the blocker closes) — this is the live frontier gate. `total_blocked_by` is the all-time/all-state count (stays 1).** This matches issue #4's claim and is now independently re-tested with a closed-blocker case that issue #4 didn't have in its graph (the live map currently has zero closed blockers among its 7 edges, so this was the first real test of that specific behaviour).

## 3. The frontier query in one shot

**Answer: yes, one GraphQL call, and it is cheap — no N+1 needed.** REST cannot do it in one call (see below); GraphQL can, **tested live** against `Dhillvn/caesar#1`:

```graphql
query {
  repository(owner: "Dhillvn", name: "caesar") {
    issue(number: 1) {
      subIssues(first: 20) {
        totalCount
        nodes {
          number
          state
          assignees(first: 5) { nodes { login } }
          blockedBy(first: 20) {
            totalCount
            nodes { number state title }
          }
        }
      }
    }
  }
}
```
Run via `gh api graphql -f query='...'`.

**Tested result** (2026-07-28, live map — 10 children, 7 edges, #4 closed): returned all 10 sub-issues with state, assignees, and each one's `blockedBy` nodes (number + state) in a single response. Sample edge: issue #9 blocked by #5 (open) and #7 (open); issue #4 (closed) correctly shows `blockedBy: {totalCount:0}` and isn't anyone's live blocker.

**Cost, tested via the same query with `rateLimit` requested alongside:**
```
{"rateLimit":{"limit":5000,"cost":1,"remaining":4909,"resetAt":"..."}}
```
**1 GraphQL point** for the whole 10-child, 7-edge frontier snapshot. At 5,000 points/hour this is not a meaningful constraint even if Caesar polls several maps every few seconds.

**The one real gap, found only by testing, not by reading docs: `blockedBy`'s `totalCount` in GraphQL is NOT open-only.** Repeating the closed-blocker test from §2 but reading GraphQL instead of REST:

```graphql
query { repository(owner:"Dhillvn", name:"caesar") {
  issue(number: 13) { blockedBy(first: 10) { totalCount nodes { number state } } }
} }
```
Result after A (#12) was closed: `{"totalCount":1,"nodes":[{"number":12,"state":"CLOSED"}]}`.

So **GraphQL's `blockedBy.totalCount` counts all blockers regardless of state — it does not match REST's `issue_dependencies_summary.blocked_by` (open-only)**. An orchestrator using the GraphQL one-shot query must filter `blockedBy.nodes` by `state == "OPEN"` itself to get the live gate; it cannot trust `totalCount` directly. This is a real, non-obvious edge — the two APIs disagree on what "blocked_by count" means, and only the REST per-issue field does the open-filtering server-side.

**Why REST can't do this in one call.** REST's sub-issues list endpoint returns child issues (with assignees) but not each child's `issue_dependencies_summary` in the same payload structure needed for a map-wide sweep without a second call *unless* you already know each child's number and fetch `GET /issues/{n}` individually — that's the N+1 REST falls into. GraphQL's nested-connection model (`subIssues { nodes { blockedBy { nodes } } } }`) is what collapses it to one round trip. **Recommendation for Caesar: use GraphQL for the frontier sweep, REST for single-issue mutations** (claim, comment, close) where the simpler mental model and existing tracker-doc commands are already proven.

## 4. Rate limits

[REST rate-limits docs](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) + [best-practices doc](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api), fetched 2026-07-28:

- **Primary limit**, personal token (what `gh` uses here): **5,000 requests/hour**. **Tested**: `gh api rate_limit` on this account currently shows `"core":{"limit":5000,...}` and `"graphql":{"limit":5000,...}` — separate buckets for REST and GraphQL, each 5,000/hour.
- A single frontier-sweep GraphQL call costs ~1 point (tested, §3) — Caesar could run the frontier query thousands of times an hour before hitting the primary limit. Not the binding constraint.
- **Secondary limits** (undocumented exact thresholds, but explicit guidance): "make requests serially instead of concurrently" and "if making a large number of POST/PATCH/PUT/DELETE requests, wait at least one second between each." No specific per-minute number is published in the docs page fetched — **flagged as not fully quantified by GitHub**, only qualitative guidance found.
- **What a rate-limited response looks like**: HTTP `403` or `429`, `x-ratelimit-remaining: 0` header when primary limit is hit, `x-ratelimit-reset` (epoch seconds) always present, `retry-after` header present on secondary-limit hits telling you how many seconds to wait. Guidance: don't retry before the header-specified time; back off exponentially on repeated secondary-limit hits.
- **Practical implication for Caesar**: primary limit is a non-issue for a handful of maps polled at reasonable cadence (GraphQL sweep ≈ 1 point). The actual discipline needed is **serial, spaced-out mutating calls** (claim/comment/close), not volume — one write at a time, ~1s apart, is the documented safe pattern.

## 5. Concurrency: two agents editing the same issue

**Tested directly, not found in prose docs.** Attempted an `If-Match` conditional PATCH against a throwaway issue (#14) using a deliberately stale ETag (captured before a prior PATCH had changed the body):

```
curl -X PATCH -H "If-Match: W/\"<stale-etag>\"" -d '{"body":"..."}' \
  https://api.github.com/repos/Dhillvn/caesar/issues/14
→ HTTP 400
{"message":"Bad Request","errors":["Conditional request headers are not allowed in unsafe requests unless supported by the endpoint"],"status":"400"}
```

**Conclusion: there is no optimistic-concurrency story for issue PATCH.** GitHub explicitly refuses `If-Match`/conditional headers on unsafe (mutating) issue requests rather than honoring or silently ignoring them — it's a hard 400, not a 412. Combined with a plain PATCH (no conditional header) succeeding unconditionally in the same test session, **this is last-write-wins**: whichever PATCH lands last on the server wins, no version check, no conflict signal.

ETags do exist on **GET** responses (`Etag: W/"..."` header, confirmed via `gh api ... -i` on issue #3) and support conditional `GET` (`If-None-Match` → `304`, which per the [best-practices doc](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api) doesn't count against the primary rate limit) — but that's a read-caching optimization, not a write-conflict guard.

**Implication for Caesar**: if two agents (or Caesar and Raj) edit the same issue body concurrently, the second write silently clobbers the first with no error, no merge, no warning. Caesar must avoid concurrent writers per issue by construction (e.g. Wayfinder's own "one ticket, one driving agent" rule) rather than lean on any GitHub-side protection — there isn't any. Comments (`POST .../comments`) are additive and don't have this problem; only same-issue **body** edits (claim via assignee add is a distinct field, less risky, but map-body edits like Decisions-so-far are exactly this risk).

## Open / unverified items

- Exact plan-tier gating for issue dependencies (Free vs Pro vs Team) — changelog text says Free/Pro/Team/Enterprise Cloud but wasn't independently re-fetched from raw HTML this session; treat as probable, not certain.
- Exact secondary rate-limit numeric thresholds (requests/minute) — GitHub's own docs only give qualitative guidance ("serially," "wait 1s"), no published number for REST issues specifically.
- Whether `gh` CLI's own sub-issue/dependency commands (`gh issue edit --add-sub-issue`? — see [2026-06-10 changelog](https://github.blog/changelog/2026-06-10-manage-sub-issues-types-and-dependencies-from-github-cli/) about first-class CLI support) are cheaper/more reliable than raw `gh api` calls — this changelog exists but wasn't tested this session; worth a follow-up ticket if Caesar wants to simplify the tracker-doc commands.
