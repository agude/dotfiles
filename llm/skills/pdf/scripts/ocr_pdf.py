# /// script
# requires-python = ">=3.11"
# dependencies = ["ocrmypdf>=15.0"]
# ///
"""Add a searchable text layer to a scanned PDF."""

import argparse
import shutil
import sys

import ocrmypdf


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Add searchable text layer to a scanned PDF."
    )
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("output", help="Output PDF file")
    parser.add_argument("--deskew", action="store_true", help="Deskew pages before OCR")
    parser.add_argument("--rotate", action="store_true", help="Auto-rotate pages to correct orientation")
    parser.add_argument("--lang", default="eng", help="Tesseract language (default: eng)")
    parser.add_argument(
        "--force", action="store_true",
        help="Re-OCR even if the PDF already has text"
    )
    args = parser.parse_args()

    if not shutil.which("tesseract"):
        print("Error: tesseract is not installed or not in PATH", file=sys.stderr)
        sys.exit(1)

    kwargs: dict = {
        "language": args.lang,
        "deskew": args.deskew,
        "rotate_pages": args.rotate,
    }
    if args.force:
        kwargs["force_ocr"] = True
    else:
        kwargs["skip_text"] = True

    result = ocrmypdf.ocr(args.input, args.output, **kwargs)
    if result == ocrmypdf.ExitCode.ok:
        print(f"OCR complete: {args.output}")
    elif result == ocrmypdf.ExitCode.already_done_ocr:
        print(f"PDF already has text. Use --force to re-OCR. Copied to: {args.output}")
    else:
        print(f"OCR failed with exit code: {result}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
