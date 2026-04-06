# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdfium2>=4.0", "Pillow>=10.0"]
# ///
"""Convert PDF pages to PNG images."""

import argparse
import os

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


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert PDF pages to PNG images.")
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("output", help="Output directory")
    parser.add_argument("--pages", help="Page range (e.g. '1-3,5')")
    parser.add_argument("--dpi", type=int, default=200, help="Resolution in DPI (default: 200)")
    parser.add_argument(
        "--max-dim", type=int, default=0,
        help="Max dimension in pixels; 0 = no limit (default: 0)"
    )
    args = parser.parse_args()

    os.makedirs(args.output, exist_ok=True)

    pdf = pdfium.PdfDocument(args.input)
    total = len(pdf)
    indices = parse_page_range(args.pages, total) if args.pages else list(range(total))

    scale = args.dpi / 72.0

    for i in indices:
        page = pdf[i]
        bitmap = page.render(scale=scale)
        img = bitmap.to_pil()

        if args.max_dim > 0:
            w, h = img.size
            if w > args.max_dim or h > args.max_dim:
                factor = min(args.max_dim / w, args.max_dim / h)
                img = img.resize((int(w * factor), int(h * factor)))

        out_path = os.path.join(args.output, f"page_{i + 1}.png")
        img.save(out_path, "PNG")
        print(f"Saved page {i + 1} as {out_path} (size: {img.size[0]}x{img.size[1]})")

    print(f"Converted {len(indices)} pages to {args.output}/")


if __name__ == "__main__":
    main()
