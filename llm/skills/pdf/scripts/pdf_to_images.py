# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdfium2>=4.0", "Pillow>=10.0"]
# ///
"""Convert PDF pages to PNG images."""

import argparse
import os
import sys
from pathlib import Path

import pypdfium2 as pdfium


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


def convert_one(
    input_file: str, output_dir: str, pages: str | None,
    dpi: int, max_dim: int, quiet: bool = False,
) -> int:
    """Convert a single PDF to images. Returns count of pages converted."""
    os.makedirs(output_dir, exist_ok=True)
    pdf = pdfium.PdfDocument(input_file)
    total = len(pdf)
    indices = parse_page_range(pages, total) if pages else list(range(total))
    scale = dpi / 72.0

    for i in indices:
        page = pdf[i]
        bitmap = page.render(scale=scale)
        img = bitmap.to_pil()

        if max_dim > 0:
            w, h = img.size
            if w > max_dim or h > max_dim:
                factor = min(max_dim / w, max_dim / h)
                img = img.resize((int(w * factor), int(h * factor)))

        out_path = os.path.join(output_dir, f"page_{i + 1}.png")
        img.save(out_path, "PNG")
        if not quiet:
            print(f"Saved page {i + 1} as {out_path} (size: {img.size[0]}x{img.size[1]})")

    return len(indices)


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert PDF pages to PNG images.")
    parser.add_argument("input", nargs="+", help="Input PDF file(s)")
    parser.add_argument("-d", "--output-dir", default=None, help="Output directory")
    parser.add_argument("--pages", help="Page range (e.g. '1-3,5')")
    parser.add_argument("--dpi", type=int, default=200, help="Resolution in DPI (default: 200)")
    parser.add_argument(
        "--max-dim", type=int, default=0,
        help="Max dimension in pixels; 0 = no limit (default: 0)"
    )
    parser.add_argument("--porcelain", action="store_true", help="Machine-readable tab-delimited output")
    parser.add_argument("--fail-fast", action="store_true", help="Stop on first error")
    args = parser.parse_args()

    # Detect legacy two-positional pattern: pdf_to_images.py input.pdf output_dir/
    if (len(args.input) == 2
            and not args.output_dir
            and not args.input[1].lower().endswith(".pdf")):
        args.output_dir = args.input.pop()

    if not args.output_dir:
        print("Error: specify output directory with -d/--output-dir", file=sys.stderr)
        sys.exit(1)

    multi = len(args.input) > 1
    failures = 0
    successes = 0

    for input_file in args.input:
        input_path = Path(input_file)
        if multi:
            out_dir = str(Path(args.output_dir) / input_path.stem)
        else:
            out_dir = args.output_dir

        try:
            count = convert_one(
                input_file, out_dir, args.pages, args.dpi, args.max_dim,
                quiet=multi or args.porcelain,
            )
            successes += 1
            if args.porcelain:
                print(f"ok\t{input_file}\t{count} pages to {out_dir}")
            else:
                if multi:
                    print(f"Converted {count} pages to {out_dir}/: {input_file}")
                else:
                    print(f"Converted {count} pages to {out_dir}/")

        except Exception as e:
            failures += 1
            if args.porcelain:
                print(f"error\t{input_file}\t{e}")
            else:
                print(f"Error processing {input_file}: {e}", file=sys.stderr)
            if args.fail_fast:
                sys.exit(1)

    if multi and not args.porcelain:
        print(f"\nConverted {successes + failures} files ({successes} succeeded, {failures} failed)")

    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
