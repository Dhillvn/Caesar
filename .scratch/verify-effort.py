"""Confirm, per cell, the effort the harness actually recorded and the model actually billed.
Effort comes off assistant records in the session transcript; model off modelUsage. Never a self-report."""
import collections, glob, json, os

BASE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.expanduser(r"~\.claude\projects")

for d in sorted(glob.glob(os.path.join(BASE, "runs", "task*"))):
    cell = os.path.basename(d)
    res = os.path.join(d, "result.json")
    if not os.path.exists(res) or os.path.getsize(res) == 0:
        print(f"{cell:28} NO RESULT"); continue
    j = json.load(open(res, encoding="utf-8"))
    sid = j.get("session_id")
    efforts = collections.Counter()
    for f in glob.glob(os.path.join(PROJ, "*", f"{sid}.jsonl")):
        for line in open(f, encoding="utf-8"):
            try: r = json.loads(line)
            except Exception: continue
            if r.get("type") == "assistant":
                efforts[r.get("effort")] += 1
    asked_e = cell.split("-")[2]
    asked_m = cell.split("-")[1]
    billed = list(j.get("modelUsage", {}).keys())
    ok_e = list(efforts) == [asked_e]
    ok_m = billed == [f"claude-{asked_m}-5"]
    print(f"{cell:28} effort={dict(efforts)} match={ok_e} | billed={billed} match={ok_m} "
          f"| terminal={j.get('terminal_reason')}")
