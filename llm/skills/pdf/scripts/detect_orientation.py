# /// script
# requires-python = ">=3.11"
# dependencies = ["pytesseract>=0.3", "pypdfium2>=4.0", "Pillow>=10.0"]
# ///
"""Detect page orientation (rotation) using tesseract OSD."""

import argparse
import json
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


def process_one(path: str, pages: str | None) -> list[dict]:
    """Detect orientation for a single PDF. Returns list of per-page results."""
    pdf = pdfium.PdfDocument(path)
    total = len(pdf)
    indices = parse_page_range(pages, total) if pages else list(range(total))

    results = []
    for i in indices:
        page = pdf[i]
        bitmap = page.render(scale=2.0)
        img = bitmap.to_pil()

        try:
            osd = pytesseract.image_to_osd(img, output_type=pytesseract.Output.DICT)
            results.append({
                "page": i + 1,
                "rotation": osd.get("rotate", 0),
                "confidence": osd.get("orientation_conf", 0),
                "script": osd.get("script", "unknown"),
            })
        except pytesseract.TesseractError as e:
            results.append({
                "page": i + 1,
                "error": str(e),
            })
    return results


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Detect page orientation using tesseract OSD."
    )
    parser.add_argument("input", nargs="+", help="Input PDF file(s)")
    parser.add_argument("--pages", help="Page range (e.g. '1-3,5')")
    parser.add_argument("--porcelain", action="store_true", help="JSONL output (one JSON object per line)")
    parser.add_argument("--fail-fast", action="store_true", help="Stop on first error")
    args = parser.parse_args()

    if not shutil.which("tesseract"):
        print("Error: tesseract is not installed or not in PATH", file=sys.stderr)
        sys.exit(1)

    multi = len(args.input) > 1
    failures = 0

    for path in args.input:
        try:
            results = process_one(path, args.pages)
        except Exception as e:
            failures += 1
            print(f"Error processing {path}: {e}", file=sys.stderr)
            if args.fail_fast:
                sys.exit(1)
            if args.porcelain:
                print(json.dumps({"file": path, "error": str(e)}))
            continue

        if args.porcelain:
            print(json.dumps({"file": path, "pages": results}))
        else:
            if multi:
                print(f"=== {path} ===")
            for r in results:
                if "error" in r:
                    print(f"Page {r['page']}: detection failed — {r['error']}", file=sys.stderr)
                else:
                    rotation = r["rotation"]
                    status = "upright" if rotation == 0 else f"rotated {rotation}° clockwise"
                    print(f"Page {r['page']}: {status} (confidence: {r['confidence']:.1f}, script: {r['script']})")

    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
