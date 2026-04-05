# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Check whether a PDF has fillable form fields."""

import argparse
import sys

from pypdf import PdfReader


def main() -> None:
    parser = argparse.ArgumentParser(description="Check if a PDF has fillable form fields.")
    parser.add_argument("input", help="Input PDF file")
    args = parser.parse_args()

    reader = PdfReader(args.input)
    fields = reader.get_fields()

    if fields:
        print(f"This PDF has {len(fields)} fillable form fields")
        sys.exit(0)
    else:
        print("This PDF does not have fillable form fields")
        sys.exit(1)


if __name__ == "__main__":
    main()
