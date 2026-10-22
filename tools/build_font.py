#!/usr/bin/env python3
"""Rebuild the shipped Korean font subset from every source of game text.

Requires fontTools (``python3 -m pip install fonttools``) and the licensed
Noto Sans CJK collection. The default Debian source is its Korean face (1).
The Noto license is retained in assets/fonts/OFL.txt.

Run from any directory: python3 tools/build_font.py
Then let Godot reimport the changed font before running test_font_glyphs.gd.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc")


def json_strings(value: object):
    """Decode escaped JSON text as well as literal UTF-8 catalog labels."""
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for key, child in value.items():
            yield key
            yield from json_strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from json_strings(child)


def collect_codepoints(root: Path) -> tuple[list[int], int]:
    # Scan whole source files conservatively: new UI strings are covered without
    # having to maintain a parser for every GDScript/scene property expression.
    paths = sorted(
        {
            *root.glob("scripts/**/*.gd"),
            *root.glob("data/**/*.json"),
            *root.glob("scenes/**/*.tscn"),
            *root.glob("scenes/**/*.tres"),
        }
    )
    if not paths:
        raise ValueError(f"No game text sources found under {root}")
    codepoints = set(range(0x20, 0x7F))
    for path in paths:
        content = path.read_text(encoding="utf-8")
        texts = json_strings(json.loads(content)) if path.suffix == ".json" else [content]
        for text in texts:
            codepoints.update(ord(char) for char in text if ord(char) >= 0x20 and ord(char) != 0x7F)
    return sorted(codepoints), len(paths)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--font-number", type=int, default=1, help="Noto CJK Korean face index")
    parser.add_argument("--output", type=Path, default=PROJECT_ROOT / "assets/fonts/RustCity.otf")
    args = parser.parse_args()

    codepoints, source_count = collect_codepoints(PROJECT_ROOT)
    # Retain the source font's timestamp and sorted input/table ordering so the
    # same fontTools version and game text produce byte-identical output.
    with TTFont(args.source, fontNumber=args.font_number, recalcTimestamp=False) as font:
        missing = sorted(set(codepoints) - font.getBestCmap().keys())
        if missing:
            raise ValueError("Source font lacks required glyphs: " + ", ".join(f"U+{code:04X} {chr(code)}" for code in missing))
        options = subset.Options()
        options.recalc_timestamp = False
        options.canonical_order = True
        options.ignore_missing_unicodes = False
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(unicodes=codepoints)
        subsetter.subset(font)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        font.save(args.output, reorderTables=True)
    print(f"Built {args.output}: {len(codepoints)} characters from {source_count} game source files")


if __name__ == "__main__":
    main()
