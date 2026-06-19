# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Split a PDF into individual pages or extract a page range."""

import argparse
import os
import sys
from pathlib import Path

from pypdf import PdfReader, PdfWriter


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


def split_pages(input_file: str, output_dir: str) -> int:
    """Split a PDF into one file per page. Returns page count."""
    reader = PdfReader(input_file)
    os.makedirs(output_dir, exist_ok=True)
    for i, page in enumerate(reader.pages):
        writer = PdfWriter()
        writer.add_page(page)
        out_path = os.path.join(output_dir, f"page_{i + 1}.pdf")
        with open(out_path, "wb") as f:
            writer.write(f)
    return len(reader.pages)


def extract_range(input_file: str, output_file: str, pages: str) -> int:
    """Extract specific pages into a single output file. Returns page count."""
    reader = PdfReader(input_file)
    total = len(reader.pages)
    indices = parse_page_range(pages, total)
    writer = PdfWriter()
    for i in indices:
        writer.add_page(reader.pages[i])
    with open(output_file, "wb") as f:
        writer.write(f)
    return len(indices)


def main() -> None:
    parser = argparse.ArgumentParser(description="Split a PDF into pages or extract a range.")
    parser.add_argument("input", nargs="+", help="Input PDF file(s)")
    parser.add_argument("-o", "--output", default=None, help="Output file (page range extraction, single input only)")
    parser.add_argument("-d", "--output-dir", default=None, help="Output directory (per-page split)")
    parser.add_argument("--pages", help="Page range to extract (e.g. '1-5,8')")
    parser.add_argument("--porcelain", action="store_true", help="Machine-readable tab-delimited output")
    parser.add_argument("--fail-fast", action="store_true", help="Stop on first error")
    args = parser.parse_args()

    # Detect legacy two-positional pattern: split.py input.pdf output
    if (len(args.input) == 2
            and not args.output
            and not args.output_dir
            and not Path(args.input[1]).is_file()):
        second = args.input.pop()
        if args.pages or second.lower().endswith(".pdf"):
            args.output = second
        else:
            args.output_dir = second

    multi = len(args.input) > 1

    if args.pages:
        # Page range extraction — single input only
        if multi:
            print("Error: --pages requires a single input file", file=sys.stderr)
            sys.exit(1)
        if not args.output:
            print("Error: --pages requires -o/--output", file=sys.stderr)
            sys.exit(1)
        try:
            count = extract_range(args.input[0], args.output, args.pages)
            if args.porcelain:
                print(f"ok\t{args.input[0]}\t{count} pages to {args.output}")
            else:
                print(f"Extracted {count} pages to {args.output}")
        except Exception as e:
            if args.porcelain:
                print(f"error\t{args.input[0]}\t{e}")
            else:
                print(f"Error: {e}", file=sys.stderr)
            sys.exit(1)
        return

    # Per-page split mode
    if not args.output_dir:
        print("Error: specify output directory with -d/--output-dir", file=sys.stderr)
        sys.exit(1)

    failures = 0
    successes = 0

    for input_file in args.input:
        input_path = Path(input_file)
        if multi:
            out_dir = str(Path(args.output_dir) / input_path.stem)
        else:
            out_dir = args.output_dir

        try:
            count = split_pages(input_file, out_dir)
            successes += 1
            if args.porcelain:
                print(f"ok\t{input_file}\t{count} pages to {out_dir}")
            else:
                print(f"Split {count} pages into {out_dir}/: {input_file}")

        except Exception as e:
            failures += 1
            if args.porcelain:
                print(f"error\t{input_file}\t{e}")
            else:
                print(f"Error processing {input_file}: {e}", file=sys.stderr)
            if args.fail_fast:
                sys.exit(1)

    if multi and not args.porcelain:
        print(f"\nSplit {successes + failures} files ({successes} succeeded, {failures} failed)")

    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
