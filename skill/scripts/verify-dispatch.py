"""Prove a dispatch actually ran at the tier it was dispatched at (#53).

inspect-run.ps1 answers "did this run do the work". It cannot answer "did it run on the
model it was asked for", and a dispatch that silently fell back to the default is
indistinguishable from success by every other signal: is_error is False, the ticket
closes, the GIST prints. The only two places the truth survives are `modelUsage` in the
result JSON, which is keyed on the real billed model id, and the `effort` key on
assistant records in the session transcript.

Python, not PowerShell, because the transcript is JSONL and the sidecar is JSON, and
because #55 and #60 were both Python over these same records.

Usage: python verify-dispatch.py <worktree-name> [repo-path]
Prints facts only. No verdict - same posture as inspect-run.ps1.
"""
import collections, glob, json, os, re, sys

wt = sys.argv[1]
repo = sys.argv[2] if len(sys.argv) > 2 else os.path.expanduser("~/Projects/caesar")
repo = os.path.abspath(repo)

# spawn names its files <worktree>-yyyyMMdd-HHmmss.json; take the newest run for this worktree
runs = sorted(glob.glob(os.path.join(repo, ".claude", "caesar-runs", wt + "-2*[0-9].json")))
if not runs:
    sys.exit("no result file for " + wt)
result = runs[-1]

print("==", wt)

# The sidecar is read as bytes first on purpose. Windows PowerShell 5.1's
# `Set-Content -Encoding UTF8` writes a BOM, and json.load then dies on char 0 - the
# exact bug the spawn script was fixed for, so it is worth re-checking every time.
raw = open(result.replace(".json", ".dispatch.json"), "rb").read()
print("sidecar     BOM:", "PRESENT (BAD)" if raw[:3] == b"\xef\xbb\xbf" else "none")
side = json.loads(raw.decode("utf-8"))
print("sidecar     ASKED tier=%s model=%s effort=%s cap=$%s" % (
    side["Tier"], side["Model"], side["Effort"], side["BudgetUsd"]))

r = json.load(open(result, encoding="utf-8"))
print("result      is_error=%s subtype=%s turns=%s cost=$%.4f" % (
    r.get("is_error"), r.get("subtype"), r.get("num_turns"), r.get("total_cost_usd", 0)))
print("result      BILLED:", ", ".join(
    "%s (in %s / out %s)" % (k, v.get("inputTokens"), v.get("outputTokens"))
    for k, v in (r.get("modelUsage") or {}).items()) or "*** no modelUsage ***")
gist = [l for l in (r.get("result") or "").splitlines() if l.startswith("GIST:")]
print("result      GIST:", gist[0][6:].strip()[:100] if gist else "*** MISSING ***")

# The session dir name is the worktree path with every :, \, / and . turned into a dash.
# The character class must be a raw string - "[:\\/.]" in a normal string collapses to
# [:\/.] and quietly drops the backslash, leaving a half-converted name that matches
# nothing, which reads exactly like "this run never wrote a transcript".
wtpath = os.path.join(repo, ".claude", "worktrees", wt).replace("/", "\\")
tdir = os.path.join(os.path.expanduser("~/.claude/projects"), re.sub(r"[:\\/.]", "-", wtpath))
if not os.path.isdir(tdir):
    sys.exit("no transcript dir at " + tdir)

# Streamed line by line: a transcript is megabytes and must never be read whole.
efforts, models = collections.Counter(), collections.Counter()
for jl in glob.glob(os.path.join(tdir, "*.jsonl")):
    for line in open(jl, encoding="utf-8"):
        try:
            t = json.loads(line)
        except ValueError:
            continue
        if t.get("type") != "assistant":
            continue
        msg = t.get("message", {})
        eff = t.get("effort", msg.get("effort"))
        if eff:
            efforts[eff] += 1
        if msg.get("model"):
            models[msg["model"]] += 1
print("transcript  effort on assistant records:", dict(efforts) or "*** NONE FOUND ***")
print("transcript  model on assistant records:", dict(models) or "*** NONE FOUND ***")
