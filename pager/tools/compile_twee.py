#!/usr/bin/env python3
"""
Compile a Twine Twee (SugarCube-ish) file into:
- story/story.graph.json : the narrative graph (IDs + choice targets), WITHOUT actual text
- locales/<lang>.json    : all strings, so you can localize by swapping JSON files

This is intentionally "good enough" for a working base:
- It treats lines that are ONLY [[...]] as choices.
- It doesn't try to interpret SugarCube macros; it leaves them in the body text.
- It doesn't resolve conditionals; those are future work.
"""
from __future__ import annotations
import argparse, json, re, pathlib

def parse_passages(twee_text: str):
    lines = twee_text.splitlines()
    passages = []
    current = None
    for line in lines:
        if line.startswith(":: "):
            if current:
                passages.append(current)
            header = line[3:].strip()
            # strip metadata like:  Title {"position":"..."}
            if " {" in header:
                title_part, _meta = header.rsplit(" {", 1)
                title = title_part.strip()
            else:
                title = header.strip()
            current = {"title": title, "lines": []}
        else:
            if current is not None:
                current["lines"].append(line)
    if current:
        passages.append(current)
    return passages

def parse_link(text: str):
    inner = text.strip()[2:-2]
    if "->" in inner:
        label, target = inner.split("->", 1)
        return label.strip(), target.strip()
    if "<-" in inner:
        target, label = inner.split("<-", 1)
        return label.strip(), target.strip()
    if "|" in inner:
        label, target = inner.split("|", 1)
        return label.strip(), target.strip()
    return inner.strip(), inner.strip()

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("twee", type=pathlib.Path)
    ap.add_argument("--lang", default="it")
    ap.add_argument("--out", default="dist", type=pathlib.Path)
    args = ap.parse_args()

    text = args.twee.read_text(encoding="utf-8")
    passages = parse_passages(text)

    title = ""
    for p in passages:
        if p["title"] == "StoryTitle":
            title = "\n".join(p["lines"]).strip()
            break

    story_passages = [p for p in passages if p["title"] not in ("StoryTitle","StoryData")]
    graph = {"title": title or "Story", "start": "0", "passages": {}}
    locale = {"app.title": graph["title"]}

    for p in story_passages:
        pid = p["title"]
        choice_lines, body_lines = [], []
        for ln in p["lines"]:
            if re.match(r"^\s*\[\[.*\]\]\s*$", ln):
                choice_lines.append(ln.strip())
            else:
                body_lines.append(ln)
        body = "\n".join(body_lines).strip("\n")
        locale[f"p.{pid}.body"] = body

        choices = []
        for i, cl in enumerate(choice_lines, start=1):
            label, target = parse_link(cl)
            locale[f"p.{pid}.c{i}"] = label
            choices.append({"labelKey": f"p.{pid}.c{i}", "to": target})

        graph["passages"][pid] = {"bodyKey": f"p.{pid}.body", "choices": choices}

    if graph["start"] not in graph["passages"]:
        graph["start"] = next(iter(graph["passages"].keys()))

    out_story = args.out / "story"
    out_loc = args.out / "locales"
    out_story.mkdir(parents=True, exist_ok=True)
    out_loc.mkdir(parents=True, exist_ok=True)

    (out_story / "story.graph.json").write_text(json.dumps(graph, ensure_ascii=False, indent=2), encoding="utf-8")
    (out_loc / f"{args.lang}.json").write_text(json.dumps(locale, ensure_ascii=False, indent=2), encoding="utf-8")

    print("Wrote:", out_story / "story.graph.json")
    print("Wrote:", out_loc / f"{args.lang}.json")

if __name__ == "__main__":
    main()
