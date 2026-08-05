"""Per cap-death run: which tools/skills produced the injected bytes.

Read-only. Prints aggregates only.
"""
import json, glob, os, collections, sys

PROJ = r"C:\Users\rajdh\.claude\projects"


def tool_bytes(path):
    """Sum tool_result payload chars per tool name, plus skill-load chars."""
    by_tool = collections.Counter()
    by_skill = collections.Counter()
    id_to_name = {}
    total_user_chars = 0
    with open(path, encoding="utf-8") as f:
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
                if not isinstance(c, dict):
                    continue
                if c.get("type") == "tool_use":
                    id_to_name[c.get("id")] = c.get("name")
                elif c.get("type") == "tool_result":
                    body = c.get("content")
                    if isinstance(body, list):
                        body = "".join(b.get("text", "") for b in body if isinstance(b, dict))
                    if not isinstance(body, str):
                        body = json.dumps(body)
                    name = id_to_name.get(c.get("tool_use_id"), "?")
                    by_tool[name] += len(body)
                    total_user_chars += len(body)
                    if name == "Skill":
                        head = body[:400]
                        for marker in ("name: ", "Base directory for this skill: "):
                            if marker in head:
                                by_skill[head.split(marker, 1)[1].split("\n")[0][:60]] += len(body)
                                break
                elif c.get("type") == "text" and rec.get("type") == "user":
                    txt = c.get("text") or ""
                    total_user_chars += len(txt)
                    if txt.startswith("Base directory for this skill"):
                        by_skill[txt.split(": ", 1)[1].split("\n")[0][:80]] += len(txt)
                        by_tool["Skill(prompt-injected)"] += len(txt)
    return by_tool, by_skill, total_user_chars


def main():
    rows = json.load(open(sys.argv[1], encoding="utf-8"))
    agg_tool = collections.Counter()
    agg_skill = collections.Counter()
    for r in rows:
        if not r["dead"]:
            continue
        hits = glob.glob(os.path.join(PROJ, "*", r["session"] + ".jsonl"))
        if not hits:
            continue
        bt, bs, tot = tool_bytes(hits[0])
        agg_tool.update(bt)
        agg_skill.update(bs)
        top = ", ".join(f"{k}:{v//1024}KB" for k, v in bt.most_common(3))
        print(f"{r['file'][:28]} tool_result_total={tot//1024}KB top={top}")
    print("\nACROSS ALL CAP DEATHS -- tool_result chars by tool:")
    for k, v in agg_tool.most_common(12):
        print(f"  {k:26} {v//1024:>7} KB")
    print("\nSkill loads by skill:")
    for k, v in agg_skill.most_common(10):
        print(f"  {k:60} {v//1024:>7} KB")


if __name__ == "__main__":
    main()
