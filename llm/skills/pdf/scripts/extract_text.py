# /// script
# requires-python = ">=3.11"
# dependencies = ["pdfplumber>=0.10"]
# ///
"""Extract text or tables from born-digital PDFs."""

import argparse
import csv
import io
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


def main() -> None:
    parser = argparse.ArgumentParser(description="Extract text or tables from a PDF.")
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("--tables", action="store_true", help="Extract tables as CSV")
    parser.add_argument("--pages", help="Page range (e.g. '1-3,5')")
    args = parser.parse_args()

    with pdfplumber.open(args.input) as pdf:
        total = len(pdf.pages)
        indices = parse_page_range(args.pages, total) if args.pages else list(range(total))

        if args.tables:
            writer = csv.writer(sys.stdout)
            for i in indices:
                page = pdf.pages[i]
                for table in page.extract_tables():
                    if table:
                        for row in table:
                            writer.writerow(row)
                        writer.writerow([])  # blank line between tables
        else:
            for i in indices:
                text = pdf.pages[i].extract_text()
                if text:
                    print(text)


if __name__ == "__main__":
    main()
