"""Grade Task A: which of the 5 seeded defects did the cell find, and did it flag correct code?"""
import glob, json, os, re

BASE = os.path.dirname(os.path.abspath(__file__))
# (defect id, file, accepted line window) -- window spans declaration..use for one mechanism.
BUCKETS = [
    ("A1", "map-sync",    range(25, 28)),   # gh output -> variable -> Set-Content -NoNewline
    ("A2", "map-sync",    range(29, 32)),   # ^-anchored regex against an array
    ("A3", "map-sync",    range(36, 40)),   # --body $updated through argv
    ("A4", "map-sync",    range(41, 46)),   # verification by phrasing
    ("A5", "spawn-agent", range(1, 200)),   # deny list with internal spaces as one argv token
]

def bucket(fname, line):
    for did, f, win in BUCKETS:
        if f in fname and line in win:
            return did
    return None

rows = []
for d in sorted(glob.glob(os.path.join(BASE, "runs", "taskA-*"))):
    cell = os.path.basename(d)
    ans = os.path.join(d, "ANSWER.md")
    found, fps = set(), []
    if os.path.exists(ans):
        for m in re.finditer(r"([A-Za-z0-9._-]+\.ps1):(\d+)", open(ans, encoding="utf-8").read()):
            b = bucket(m.group(1), int(m.group(2)))
            (found.add(b) if b else fps.append(m.group(0)))
    res = os.path.join(d, "result.json")
    try:
        j = json.load(open(res, encoding="utf-8"))
    except Exception:
        continue  # still in flight
    rows.append(dict(cell=cell, found=sorted(found), n=len(found), fp=sorted(set(fps)),
                     cost=round(j.get("total_cost_usd", 0), 4), turns=j.get("num_turns"),
                     models=list(j.get("modelUsage", {}).keys()), sid=j.get("session_id"),
                     terminal=j.get("terminal_reason")))
print(json.dumps(rows, indent=1))
