#!/usr/bin/env python3
"""Extract the YAML examples in Talos's generated configuration reference."""

import argparse
from collections import Counter
import json
from pathlib import Path
import re


BLOCK = re.compile(
    r"\{\{<\s*highlight\s+yaml\s*>\}\}\r?\n"
    r"(?P<yaml>.*?)\{\{<\s*/highlight\s*>\}\}",
    re.DOTALL,
)
HEADING = re.compile(
    r"^#{2,6}\s+(.+?)(?:\s+\{#([^}]+)\})?\s*$", re.MULTILINE
)
FIELD = re.compile(r"^\|`([^`]+)`\s*\|", re.MULTILINE)


def slug(value):
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")


def extract(page, source):
    text = page.read_text(encoding="utf-8")
    relative = page.relative_to(source)
    section = ""
    position = 0
    field = ""

    for match in BLOCK.finditer(text):
        # examine only markdown between blocks, never YAML comments or scalars
        context = text[position:match.start()]
        for heading in HEADING.finditer(context):
            anchor = heading.group(2)
            section = anchor.partition(".")[2] if anchor else heading.group(1)
            field = ""
        for row in FIELD.finditer(context):
            field = row.group(1)

        prefix = text[text.rfind("\n", 0, match.start()) + 1:match.start()]
        if prefix.strip():
            scope = "field"
            suffix = slug(".".join(filter(None, [section, field]))) or "example"
        elif section:
            scope = "section"
            suffix = slug(section)
        else:
            scope = "document"
            suffix = ""

        stem = relative.stem
        if scope != "document":
            stem += f"--{scope}-{suffix}"

        yield {
            "base": relative.parent / stem,
            "scope": scope,
            "source": page.as_posix(),
            "line": text.count("\n", 0, match.start("yaml")) + 1,
            "yaml": match.group("yaml"),
        }
        position = match.end()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source", type=Path,
        default=Path("website/content/v1.15/reference/configuration"),
    )
    parser.add_argument(
        "--output", type=Path, default=Path("reference/configuration"),
    )
    parser.add_argument(
        "--all", action="store_true",
        help="also extract subsection and field fragments, without adding missing parents or metadata",
    )
    args = parser.parse_args()
    if not args.source.is_dir():
        parser.error(f"source directory does not exist: {args.source}")

    examples = []
    pages = sorted(p for p in args.source.rglob("*.md") if p.name != "_index.md")
    if not pages:
        parser.error("no configuration reference pages found")
    for page in pages:
        found = list(extract(page, args.source))
        if not found:
            parser.error(f"no YAML examples found in {page}")
        examples.extend(found)

    selected = [e for e in examples if args.all or e["scope"] == "document"]
    totals = Counter(e["base"] for e in selected)
    numbers = Counter()
    files = {}
    manifest = []
    for example in selected:
        base = example["base"]
        numbers[base] += 1
        number = f"-{numbers[base]:02d}" if totals[base] > 1 else ""
        relative = base.parent / f"{base.name}{number}.yaml"
        if relative in files:
            parser.error(f"filename collision: {relative}")
        files[relative] = example["yaml"]
        manifest.append({
            "file": relative.as_posix(),
            "scope": example["scope"],
            "source": example["source"],
            "line": example["line"],
        })

    # require a dedicated output tree; rerunning an identical export is safe
    files[Path("index.json")] = json.dumps(manifest, indent=2) + "\n"
    if args.output.exists():
        existing = {p.relative_to(args.output) for p in args.output.rglob("*") if p.is_file()}
        if existing - files.keys():
            parser.error("output contains stale or unrelated files; use a fresh --output directory")
        for relative in existing:
            if (args.output / relative).read_text(encoding="utf-8") != files[relative]:
                parser.error(f"output differs at {relative}; use a fresh --output directory")

    for relative, content in files.items():
        target = args.output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")

    counts = Counter(e["scope"] for e in selected)
    print(f"Exported {len(selected)} YAML files to {args.output}: {dict(counts)}")
    if not args.all:
        print(f"Omitted {len(examples) - len(selected)} fragments; use --all to include them.")


if __name__ == "__main__":
    main()
