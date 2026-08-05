"""Grade Task B: run each cell's frontier.ps1 against the seen and held-out maps."""
import glob, json, os, subprocess

BASE = os.path.dirname(os.path.abspath(__file__))
PS = r"C:\WINDOWS\System32\WindowsPowerShell\v1.0\powershell.exe"
CASES = [
    (os.path.join(BASE, "fixtures", "taskB", "map.md"), [2, 4, 8]),        # seen
    (os.path.join(BASE, "held-out", "map2.md"), [10, 14, 16]),             # held out
]

def run(script, path):
    try:
        # Only Windows PowerShell 5.1 exists on this machine, so it is the real target
        # even though the task prompt said `pwsh`. Recorded as a caveat in the writeup.
        p = subprocess.run([PS, "-NoProfile", "-File", script, "-Path", path],
                           capture_output=True, text=True, timeout=90)
    except Exception as e:
        return None, f"launch failed: {e}"
    got = [int(x) for x in p.stdout.split() if x.strip().lstrip("#").isdigit()]
    return got, (p.stderr or "").strip()[:200]

rows = []
for d in sorted(glob.glob(os.path.join(BASE, "runs", "taskB-*"))):
    cell = os.path.basename(d)
    script = os.path.join(d, "frontier.ps1")
    cases = []
    for path, want in CASES:
        if not os.path.exists(script):
            cases.append(dict(map=os.path.basename(path), pass_=False, got=None, want=want,
                              err="no frontier.ps1 produced"))
            continue
        got, err = run(script, path)
        cases.append(dict(map=os.path.basename(path), pass_=(got == want), got=got, want=want, err=err))
    res = os.path.join(d, "result.json")
    try:
        j = json.load(open(res, encoding="utf-8"))
    except Exception:
        continue  # still in flight
    extra = sorted(set(os.listdir(d)) - {"frontier.ps1", "map.md", "result.json", "stderr.txt", ".prompt.txt"})
    rows.append(dict(cell=cell, passed=sum(c["pass_"] for c in cases), of=len(cases), cases=cases,
                     extra_files=extra, cost=round(j.get("total_cost_usd", 0), 4),
                     turns=j.get("num_turns"), models=list(j.get("modelUsage", {}).keys()),
                     sid=j.get("session_id"), terminal=j.get("terminal_reason")))
print(json.dumps(rows, indent=1))
