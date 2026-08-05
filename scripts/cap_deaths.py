"""Measure headless runs killed by the budget cap against the completed-run norm.

Read-only. Prints aggregates only -- never dumps transcript content.
"""
import json, os, glob, sys, re, statistics

RUNS = glob.glob(r"C:\Users\rajdh\Projects\*\.claude\caesar-runs\*.json") + \
       glob.glob(r"C:\Users\rajdh\Projects\*\.claude\worktrees\*\.claude\caesar-runs\*.json")
PROJ = r"C:\Users\rajdh\.claude\projects"


def transcript_for(session_id):
    hits = glob.glob(os.path.join(PROJ, "*", session_id + ".jsonl"))
    return hits[0] if hits else None


def label_biggest(line):
    """Name what produced a transcript line, from its first bytes only."""
    try:
        rec = json.loads(line)
    except Exception:
        return "unparseable"
    t = rec.get("type")
    msg = rec.get("message") or {}
    content = msg.get("content")
    if isinstance(content, list) and content:
        c = content[0]
        ct = c.get("type")
        if ct == "tool_result":
            body = c.get("content")
            if isinstance(body, list) and body:
                body = body[0].get("text", "")
            body = (body or "")[:300] if isinstance(body, str) else ""
            m = re.search(r"name:\s*([\w:-]+)", body)
            skill = f" skill={m.group(1)}" if m else ""
            return f"{t}/tool_result{skill} head={body[:80]!r}"
        if ct == "tool_use":
            return f"{t}/tool_use name={c.get('name')} input_head={str(c.get('input'))[:80]!r}"
        if ct == "text":
            return f"{t}/text head={(c.get('text') or '')[:80]!r}"
    if isinstance(content, str):
        return f"{t}/str head={content[:100]!r}"
    return f"{t}/other"


def measure(path):
    """Dedup assistant records by message.id: Claude Code writes several
    snapshots of the same assistant message, each with the same id and the
    same usage block, so keying on id keeps exactly one copy per real turn."""
    seen, raw_records = set(), 0
    cc = cr = inp = out = turns = 0
    biggest = (0, None, "")
    writes, reads = [], []
    with open(path, encoding="utf-8") as f:
        for n, line in enumerate(f, 1):
            if len(line) > biggest[0]:
                biggest = (len(line), n, line)
            try:
                rec = json.loads(line)
            except Exception:
                continue
            if rec.get("type") != "assistant":
                continue
            m = rec.get("message") or {}
            u = m.get("usage") or {}
            if not u:
                continue
            raw_records += 1
            key = m.get("id") or n
            if key in seen:
                continue
            seen.add(key)
            turns += 1
            c1 = u.get("cache_creation_input_tokens", 0) or 0
            c2 = u.get("cache_read_input_tokens", 0) or 0
            cc += c1; cr += c2
            inp += u.get("input_tokens", 0) or 0
            out += u.get("output_tokens", 0) or 0
            writes.append(c1); reads.append(c2)
    return dict(turns=turns, raw_usage_records=raw_records,
                cache_create=cc, cache_read=cr, input=inp, output=out,
                max_cache_write=max(writes, default=0),
                peak_context=max(reads, default=0),
                mean_context=round(statistics.mean(reads)) if reads else 0,
                biggest_chars=biggest[0], biggest_line=biggest[1],
                biggest_src=label_biggest(biggest[2]) if biggest[2] else "")


def main():
    rows = []
    for p in RUNS:
        if os.path.getsize(p) == 0:
            continue
        try:
            d = json.load(open(p, encoding="utf-8"))
        except Exception:
            continue
        dead = (d.get("terminal_reason") == "budget_exhausted"
                or d.get("subtype") == "error_max_budget_usd")
        sid = d.get("session_id")
        t = transcript_for(sid) if sid else None
        row = dict(file=os.path.basename(p), dead=dead,
                   worktree_repo=p.split("Projects\\")[1].split("\\")[0],
                   session=sid, cost=d.get("total_cost_usd"),
                   terminal=d.get("terminal_reason"), transcript=bool(t))
        if t:
            row.update(measure(t))
        rows.append(row)
    json.dump(rows, open(sys.argv[1], "w", encoding="utf-8"), indent=1)
    print(f"parsed runs: {len(rows)}  cap deaths: {sum(r['dead'] for r in rows)}"
          f"  with transcript: {sum(1 for r in rows if r['transcript'])}")


if __name__ == "__main__":
    main()
