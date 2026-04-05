# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Rotate PDF pages."""

import argparse

from pypdf import PdfReader, PdfWriter


def parse_page_list(spec: str, total: int) -> list[int]:
    """Parse '1,3,5' into zero-based page indices."""
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
    parser = argparse.ArgumentParser(description="Rotate PDF pages.")
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("output", help="Output PDF file")
    parser.add_argument(
        "--angle", type=int, required=True, choices=[90, 180, 270],
        help="Rotation angle clockwise (90, 180, or 270)"
    )
    parser.add_argument("--pages", help="Pages to rotate (e.g. '1,3,5'); default: all")
    args = parser.parse_args()

    reader = PdfReader(args.input)
    total = len(reader.pages)
    target_indices = set(parse_page_list(args.pages, total)) if args.pages else set(range(total))

    writer = PdfWriter()
    for i, page in enumerate(reader.pages):
        if i in target_indices:
            page.rotate(args.angle)
        writer.add_page(page)

    with open(args.output, "wb") as f:
        writer.write(f)

    print(f"Rotated {len(target_indices)} pages by {args.angle}° in {args.output}")


if __name__ == "__main__":
    main()
