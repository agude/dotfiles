# /// script
# requires-python = ">=3.11"
# dependencies = ["pytesseract>=0.3", "pypdfium2>=4.0", "Pillow>=10.0"]
# ///
"""OCR scanned PDF pages to text via tesseract."""

import argparse
import shutil
import sys

import pypdfium2 as pdfium
import pytesseract


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
    parser = argparse.ArgumentParser(description="OCR scanned PDF pages to text.")
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("--pages", help="Page range (e.g. '1-3,5')")
    parser.add_argument("--lang", default="eng", help="Tesseract language (default: eng)")
    args = parser.parse_args()

    if not shutil.which("tesseract"):
        print("Error: tesseract is not installed or not in PATH", file=sys.stderr)
        sys.exit(1)

    pdf = pdfium.PdfDocument(args.input)
    total = len(pdf)
    indices = parse_page_range(args.pages, total) if args.pages else list(range(total))

    for i in indices:
        page = pdf[i]
        bitmap = page.render(scale=2.0)
        img = bitmap.to_pil()
        text = pytesseract.image_to_string(img, lang=args.lang)
        if text.strip():
            if len(indices) > 1:
                print(f"--- Page {i + 1} ---")
            print(text)


if __name__ == "__main__":
    main()
