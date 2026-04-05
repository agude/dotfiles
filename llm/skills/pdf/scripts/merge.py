# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Merge multiple PDFs into one."""

import argparse

from pypdf import PdfReader, PdfWriter


def main() -> None:
    parser = argparse.ArgumentParser(description="Merge multiple PDFs into one.")
    parser.add_argument("inputs", nargs="+", help="Input PDF files")
    parser.add_argument("-o", "--output", required=True, help="Output PDF file")
    args = parser.parse_args()

    writer = PdfWriter()
    for pdf_path in args.inputs:
        reader = PdfReader(pdf_path)
        for page in reader.pages:
            writer.add_page(page)

    with open(args.output, "wb") as f:
        writer.write(f)

    total = len(writer.pages)
    print(f"Merged {len(args.inputs)} files ({total} pages) into {args.output}")


if __name__ == "__main__":
    main()
