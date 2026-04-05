# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Remove password protection from a PDF."""

import argparse
import sys

from pypdf import PdfReader, PdfWriter


def main() -> None:
    parser = argparse.ArgumentParser(description="Decrypt a password-protected PDF.")
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("output", help="Output PDF file")
    parser.add_argument("--password", required=True, help="Password to decrypt the PDF")
    args = parser.parse_args()

    reader = PdfReader(args.input)

    if reader.is_encrypted:
        if not reader.decrypt(args.password):
            print("Error: incorrect password", file=sys.stderr)
            sys.exit(1)
    else:
        print("Note: PDF is not encrypted, copying as-is", file=sys.stderr)

    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)

    with open(args.output, "wb") as f:
        writer.write(f)

    print(f"Decrypted PDF saved to {args.output}")


if __name__ == "__main__":
    main()
