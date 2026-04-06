# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Display PDF metadata."""

import argparse
import json
import sys

from pypdf import PdfReader


def process_one(path: str) -> dict:
    reader = PdfReader(path)
    meta = reader.metadata
    return {
        "file": path,
        "pages": len(reader.pages),
        "title": meta.title if meta else None,
        "author": meta.author if meta else None,
        "subject": meta.subject if meta else None,
        "creator": meta.creator if meta else None,
        "producer": meta.producer if meta else None,
        "creation_date": str(meta.creation_date) if meta and meta.creation_date else None,
        "modification_date": str(meta.modification_date) if meta and meta.modification_date else None,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Display PDF metadata.")
    parser.add_argument("input", nargs="+", help="Input PDF file(s)")
    parser.add_argument("--json", action="store_true", dest="as_json", help="Output as JSON")
    parser.add_argument("--porcelain", action="store_true", help="JSONL output (one JSON object per line)")
    parser.add_argument("--fail-fast", action="store_true", help="Stop on first error")
    args = parser.parse_args()

    multi = len(args.input) > 1
    failures = 0

    for path in args.input:
        try:
            info = process_one(path)
        except Exception as e:
            failures += 1
            print(f"Error processing {path}: {e}", file=sys.stderr)
            if args.fail_fast:
                sys.exit(1)
            if args.porcelain:
                print(json.dumps({"file": path, "error": str(e)}))
            continue

        if args.porcelain:
            print(json.dumps(info))
        elif args.as_json:
            print(json.dumps(info, indent=2))
        else:
            if multi:
                print(f"=== {path} ===")
            for key, value in info.items():
                if key == "file":
                    continue
                label = key.replace("_", " ").title()
                print(f"{label}: {value if value is not None else '(none)'}")
            if multi:
                print()

    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
