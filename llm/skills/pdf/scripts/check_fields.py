# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Check whether a PDF has fillable form fields."""

import argparse
import json
import sys

from pypdf import PdfReader


def check_one(path: str) -> dict:
    """Check a single PDF for fillable fields."""
    reader = PdfReader(path)
    fields = reader.get_fields()
    count = len(fields) if fields else 0
    return {"file": path, "has_fields": count > 0, "field_count": count}


def main() -> None:
    parser = argparse.ArgumentParser(description="Check if a PDF has fillable form fields.")
    parser.add_argument("input", nargs="+", help="Input PDF file(s)")
    parser.add_argument("--porcelain", action="store_true", help="JSONL output (one JSON object per line)")
    parser.add_argument("--fail-fast", action="store_true", help="Stop on first error")
    args = parser.parse_args()

    multi = len(args.input) > 1
    failures = 0
    any_has_fields = False

    for path in args.input:
        try:
            result = check_one(path)
        except Exception as e:
            failures += 1
            print(f"Error processing {path}: {e}", file=sys.stderr)
            if args.fail_fast:
                sys.exit(1)
            if args.porcelain:
                print(json.dumps({"file": path, "error": str(e)}))
            continue

        if result["has_fields"]:
            any_has_fields = True

        if args.porcelain:
            print(json.dumps(result))
        else:
            if multi:
                print(f"=== {path} ===")
            if result["has_fields"]:
                print(f"This PDF has {result['field_count']} fillable form fields")
            else:
                print("This PDF does not have fillable form fields")

    if failures:
        sys.exit(1)
    if not any_has_fields:
        sys.exit(1)


if __name__ == "__main__":
    main()
