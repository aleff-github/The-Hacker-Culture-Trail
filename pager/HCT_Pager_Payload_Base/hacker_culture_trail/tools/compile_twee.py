#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re
import argparse
from typing import List, Dict, Tuple

PASSAGE_HEADER_RE = re.compile(r'^\s*::\s*(.+?)\s*$')
# Link Twine in formato [[...]]
LINK_RE = re.compile(r'\[\[(.+?)\]\]')

# Alcuni passaggi "di sistema" comuni nei file Twee/Twine
DEFAULT_SKIP_TITLES = {
    "StoryData", "StoryTitle", "StoryIncludes", "StoryStylesheet", "StoryScript"
}

def parse_header(raw: str) -> str:
    """
    Estrae il titolo dal contenuto dopo '::'.
    Gestisce anche i tag in stile: :: Titolo [tag1 tag2]
    """
    title = raw.strip()

    # Rimuove eventuali tags alla fine: "Titolo [tag ...]"
    # (nota: non perfetto per titoli che contengono '[' come testo, ma è lo standard Twine)
    title = re.sub(r'\s*\[[^\]]*\]\s*$', '', title).strip()

    # In caso di header tipo "::" vuoto (anomalo), restituisce stringa vuota
    return title

def extract_link_target(link_inner: str) -> str:
    """
    Dato il contenuto interno di [[...]], ricava il target del link.
    Gestisce:
      [[Testo->Target]]
      [[Target<-Testo]]
      [[Testo|Target]]
      [[Target]]
    """
    s = link_inner.strip()

    if '->' in s:
        # [[Testo->Target]]
        parts = s.split('->', 1)
        return parts[1].strip()
    if '<-' in s:
        # [[Target<-Testo]]
        parts = s.split('<-', 1)
        return parts[0].strip()
    if '|' in s:
        # [[Testo|Target]]
        parts = s.split('|', 1)
        return parts[1].strip()

    # [[Target]]
    return s

def parse_twee(path: str) -> Dict[str, str]:
    """
    Ritorna dict: {passage_title: passage_body}
    """
    with open(path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    passages: Dict[str, List[str]] = {}
    current_title: str | None = None

    for line in lines:
        m = PASSAGE_HEADER_RE.match(line)
        if m:
            raw_title = m.group(1)
            title = parse_header(raw_title)
            current_title = title
            if current_title not in passages:
                passages[current_title] = []
            continue

        if current_title is not None:
            passages[current_title].append(line)

    # unisci body
    return {k: ''.join(v).strip('\n') for k, v in passages.items()}

def outgoing_links(body: str) -> List[str]:
    """
    Estrae i target dei link in ordine, senza duplicati ripetuti.
    """
    targets: List[str] = []
    seen = set()

    for m in LINK_RE.finditer(body or ""):
        inner = m.group(1)
        tgt = extract_link_target(inner)
        if tgt and tgt not in seen:
            targets.append(tgt)
            seen.add(tgt)

    return targets

def to_tsv_rows(passages: Dict[str, str], skip_titles: set[str]) -> List[Tuple[str, str, str]]:
    rows: List[Tuple[str, str, str]] = []

    for title, body in passages.items():
        if not title:
            continue
        if title in skip_titles:
            continue

        links = outgoing_links(body)
        next1 = links[0] if len(links) > 0 else ""
        next2 = links[1] if len(links) > 1 else ""
        rows.append((title, next1, next2))

    return rows

def main():
    ap = argparse.ArgumentParser(description="Export Twine Twee to TSV: ID<TAB>NEXT1<TAB>NEXT2")
    ap.add_argument("input", help="Path al file .twee")
    ap.add_argument("-o", "--output", help="Path output TSV (default: stdout)", default=None)
    ap.add_argument("--no-skip-defaults", action="store_true",
                    help="Non saltare i passaggi di sistema (StoryData, StoryTitle, ...)")
    args = ap.parse_args()

    passages = parse_twee(args.input)

    skip_titles = set()
    if not args.no_skip_defaults:
        skip_titles |= DEFAULT_SKIP_TITLES

    rows = to_tsv_rows(passages, skip_titles)

    out_lines = []
    for pid, n1, n2 in rows:
        out_lines.append(f"{pid}\t{n1}\t{n2}")

    output_text = "\n".join(out_lines) + ("\n" if out_lines else "")

    if args.output:
        with open(args.output, "w", encoding="utf-8", newline="\n") as f:
            f.write(output_text)
    else:
        print(output_text, end="")

if __name__ == "__main__":
    main()