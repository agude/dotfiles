# /// script
# requires-python = ">=3.11"
# dependencies = ["pdfplumber>=0.10"]
# ///
"""Extract text or tables from born-digital PDFs."""

import argparse
import csv
import io
import json
import sys

import pdfplumber


def parse_page_range(spec: str, total: int) -> list[int]:
    """Parse '1-3,5,7-9' into zero-based page indices."""
    pages: list[int] = []
    for part in spec.split(","):
        part = part.strip()
        if "-" in part:
            start, end = part.split("-", 1)
            start_i = int(start) - 1
            end_i = int(end)
            pages.extend(range(start_i, min(end_i, total)))
        else:
            idx = int(part) - 1
            if 0 <= idx < total:
                pages.append(idx)
    return sorted(set(pages))


def process_one(path: str, pages: str | None, tables: bool) -> str:
    """Extract text or tables from a single PDF. Returns the output string."""
    with pdfplumber.open(path) as pdf:
        total = len(pdf.pages)
        indices = parse_page_range(pages, total) if pages else list(range(total))

        if tables:
            buf = io.StringIO()
            writer = csv.writer(buf)
            for i in indices:
                page = pdf.pages[i]
                for table in page.extract_tables():
                    if table:
                        for row in table:
                            writer.writerow(row)
                        writer.writerow([])
            return buf.getvalue()
        else:
            parts = []
            for i in indices:
                text = pdf.pages[i].extract_text()
                if text:
                    parts.append(text)
            return "\n".join(parts)


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract text or tables from a PDF.")
    parser.add_argument("input", nargs="+", help="Input PDF file(s)")
    parser.add_argument("--tables", action="store_true", help="Extract tables as CSV")
    parser.add_argument("--pages", help="Page range (e.g. '1-3,5')")
    parser.add_argument("--porcelain", action="store_true", help="JSONL output (one JSON object per line)")
    parser.add_argument("--fail-fast", action="store_true", help="Stop on first error")
    args = parser.parse_args()

    multi = len(args.input) > 1
    failures = 0

    for path in args.input:
        try:
            output = process_one(path, args.pages, args.tables)
        except Exception as e:
            failures += 1
            print(f"Error processing {path}: {e}", file=sys.stderr)
            if args.fail_fast:
                sys.exit(1)
            if args.porcelain:
                print(json.dumps({"file": path, "error": str(e)}))
            continue

        if args.porcelain:
            print(json.dumps({"file": path, "text": output}))
        else:
            if multi:
                print(f"=== {path} ===")
            print(output, end="" if output.endswith("\n") else "\n")

    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
