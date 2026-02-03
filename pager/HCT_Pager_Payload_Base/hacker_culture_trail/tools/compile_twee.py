#!/usr/bin/env python3
"""
compile_twee.py - Convert a SugarCube .twee into:
- story/story.tsv (node_id \t choice1_target \t choice2_target)
- locales/<lang>.lang (key=value lines)
Assumptions (simple on purpose):
- Passages are introduced by lines starting with ":: "
- Choices are the first two Twine links of the form [[label|Target]] or [[Target]]
- Lines that contain ONLY a link are removed from the passage body (so body stays clean)

Usage:
  python3 tools/compile_twee.py "The Hacker Culture Trail.twee" --lang it
"""
import re, argparse, pathlib

LINK_RE = re.compile(r'\[\[([^\]]+)\]\]')

def parse_twee(text: str):
    parts = re.split(r'(?m)^\s*::\s+', text)
    passages = {}
    for part in parts[1:]:
        lines = part.splitlines()
        if not lines:
            continue
        title_line = lines[0].strip()
        title = title_line.split(" {")[0].strip()
        if title in ("StoryTitle", "StoryData"):
            continue
        body = "\n".join(lines[1:]).strip("\n")
        passages[title] = body
    return passages

def extract_choices(body: str):
    out = []
    for m in LINK_RE.finditer(body):
        raw = m.group(1)
        if "|" in raw:
            label, target = raw.split("|", 1)
        else:
            label, target = raw, raw
        out.append((label.strip(), target.strip()))
    return out

def strip_choice_lines(body: str):
    kept=[]
    for line in body.splitlines():
        if re.fullmatch(r'\s*\[\[[^\]]+\]\]\s*', line):
            continue
        kept.append(line)
    return "\n".join(kept).strip("\n")

def esc(v: str) -> str:
    return v.replace("\\","\\\\").replace("\r","").replace("\n","\\n")

def node_key(n: str):
    parts = n.split(".")
    out=[]
    for p in parts:
        if p.isdigit():
            out.append((0, int(p)))
        else:
            out.append((1, p))
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("twee", help="Input .twee file")
    ap.add_argument("--lang", default="it", help="Locale code for output file, default: it")
    args = ap.parse_args()

    in_path = pathlib.Path(args.twee)
    text = in_path.read_text(encoding="utf-8", errors="replace")
    passages = parse_twee(text)

    graph_rows=[]
    locale={}
    for pid, body in passages.items():
        choices = extract_choices(body)
        if len(choices) >= 2:
            (c1,t1),(c2,t2)=choices[0],choices[1]
        elif len(choices) == 1:
            (c1,t1)=choices[0]; c2,t2=("","")
        else:
            c1,t1,c2,t2=("","","","")
        graph_rows.append((pid,t1,t2))
        clean_body = strip_choice_lines(body)
        locale[f"p.{pid}.body"]=esc(clean_body)
        if c1: locale[f"p.{pid}.c1"]=esc(c1)
        if c2: locale[f"p.{pid}.c2"]=esc(c2)

    out_root = pathlib.Path(__file__).resolve().parents[1]
    story_dir = out_root/"story"
    loc_dir = out_root/"locales"
    story_dir.mkdir(parents=True, exist_ok=True)
    loc_dir.mkdir(parents=True, exist_ok=True)

    graph_rows = sorted(graph_rows, key=lambda r: node_key(r[0]))
    (story_dir/"story.tsv").write_text("\n".join(["\t".join(r) for r in graph_rows])+"\n", encoding="utf-8")

    loc_lines = [f"{k}={locale[k]}" for k in sorted(locale.keys())]
    (loc_dir/f"{args.lang}.lang").write_text("\n".join(loc_lines)+"\n", encoding="utf-8")

if __name__ == "__main__":
    main()
