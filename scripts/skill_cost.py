"""Skill-cost inventory: static on-disk size vs bytes actually injected on invoke.

Read-only over ~/.claude. Prints aggregates only -- never dumps transcript text.
Usage: python scripts/skill_cost.py
"""
import json, glob, os, collections, statistics

HOME = os.path.expanduser("~")
SKILL_ROOTS = [
    os.path.join(HOME, ".claude", "skills"),
    os.path.join(HOME, ".claude", "plugins", "cache"),
]
PROJ = os.path.join(HOME, ".claude", "projects")


def dir_bytes(d):
    t = 0
    for root, _, files in os.walk(d):
        for f in files:
            try:
                t += os.path.getsize(os.path.join(root, f))
            except OSError:
                pass
    return t


def static_inventory():
    """{skill_name: (skill_md_bytes, dir_bytes, path)} for every SKILL.md on disk."""
    out = {}
    for root in SKILL_ROOTS:
        for p in glob.glob(os.path.join(root, "**", "SKILL.md"), recursive=True):
            d = os.path.dirname(p)
            name = os.path.basename(d)
            md = os.path.getsize(p)
            # keep the biggest copy if a skill is installed twice (plugin cache dupes)
            prev = out.get(name)
            if prev and prev[1] >= dir_bytes(d):
                continue
            out[name] = (md, dir_bytes(d), d)
    return out


def observed_loads():
    """{skill_name: [injected_chars, ...]} across every transcript on the machine."""
    obs = collections.defaultdict(list)
    for path in glob.glob(os.path.join(PROJ, "*", "*.jsonl")):
        try:
            f = open(path, encoding="utf-8")
        except OSError:
            continue
        with f:
            for line in f:
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                msg = rec.get("message") or {}
                content = msg.get("content")
                if not isinstance(content, list):
                    continue
                for c in content:
                    if not isinstance(c, dict) or c.get("type") != "text":
                        continue
                    if rec.get("type") != "user":
                        continue
                    txt = c.get("text") or ""
                    if txt.startswith("Base directory for this skill"):
                        d = txt.split(": ", 1)[1].split("\n")[0].strip()
                        obs[os.path.basename(d.rstrip("\\/"))].append(len(txt))
    return obs


def main():
    static = static_inventory()
    obs = observed_loads()
    rows = []
    for name, (md, dirb, path) in static.items():
        samples = obs.get(name, [])
        rows.append({
            "name": name,
            "md": md,
            "dir": dirb,
            "n": len(samples),
            "med": int(statistics.median(samples)) if samples else None,
            "max": max(samples) if samples else None,
        })
    rows.sort(key=lambda r: -(r["med"] or r["md"]))
    print(f"{'skill':34}{'SKILL.md':>10}{'dir':>10}{'obs n':>7}{'obs med':>10}{'obs max':>10}")
    for r in rows:
        print(f"{r['name'][:33]:34}{r['md']:>10}{r['dir']:>10}{r['n']:>7}"
              f"{r['med'] if r['med'] is not None else '-':>10}{r['max'] if r['max'] is not None else '-':>10}")

    paired = [r for r in rows if r["med"]]
    print(f"\nskills on disk: {len(rows)}   with >=1 observed load: {len(paired)}")
    if paired:
        ratios = [r["med"] / r["md"] for r in paired]
        dratios = [r["med"] / r["dir"] for r in paired]
        print(f"observed/SKILL.md ratio: median {statistics.median(ratios):.2f} "
              f"min {min(ratios):.2f} max {max(ratios):.2f}")
        print(f"observed/dir      ratio: median {statistics.median(dratios):.2f} "
              f"min {min(dratios):.3f} max {max(dratios):.2f}")
    # observed-only skills (invoked but SKILL.md not found on disk under the roots)
    orphan = {k: v for k, v in obs.items() if k not in static}
    if orphan:
        print("\nobserved but no SKILL.md matched on disk:")
        for k, v in sorted(orphan.items(), key=lambda kv: -max(kv[1]))[:10]:
            print(f"  {k[:40]:42} n={len(v):>3} max={max(v)}")


if __name__ == "__main__":
    main()
