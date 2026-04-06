# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Split a PDF into individual pages or extract a page range."""

import argparse
import os

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


def main() -> None:
    parser = argparse.ArgumentParser(description="Split a PDF into pages or a range.")
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("output", help="Output file or directory")
    parser.add_argument("--pages", help="Page range to extract (e.g. '1-5,8')")
    args = parser.parse_args()

    reader = PdfReader(args.input)
    total = len(reader.pages)

    if args.pages:
        # Extract specific pages into a single output file
        indices = parse_page_range(args.pages, total)
        writer = PdfWriter()
        for i in indices:
            writer.add_page(reader.pages[i])
        with open(args.output, "wb") as f:
            writer.write(f)
        print(f"Extracted {len(indices)} pages to {args.output}")
    else:
        # Split into one file per page in output directory
        os.makedirs(args.output, exist_ok=True)
        for i, page in enumerate(reader.pages):
            writer = PdfWriter()
            writer.add_page(page)
            out_path = os.path.join(args.output, f"page_{i + 1}.pdf")
            with open(out_path, "wb") as f:
                writer.write(f)
        print(f"Split {total} pages into {args.output}/")


if __name__ == "__main__":
    main()
