# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Add password protection to a PDF."""

import argparse

from pypdf import PdfReader, PdfWriter


def main() -> None:
    parser = argparse.ArgumentParser(description="Encrypt a PDF with password protection.")
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("output", help="Output PDF file")
    parser.add_argument("--user-password", required=True, help="Password required to open the PDF")
    parser.add_argument("--owner-password", help="Password for full permissions (defaults to user password)")
    args = parser.parse_args()

    reader = PdfReader(args.input)
    writer = PdfWriter()

    for page in reader.pages:
        writer.add_page(page)

    owner_pw = args.owner_password or args.user_password
    writer.encrypt(args.user_password, owner_pw)

    with open(args.output, "wb") as f:
        writer.write(f)

    print(f"Encrypted PDF saved to {args.output}")


if __name__ == "__main__":
    main()
