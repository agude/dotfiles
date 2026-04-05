# /// script
# requires-python = ">=3.11"
# dependencies = ["pdfplumber>=0.10"]
# ///
"""Extract form structure (labels, lines, checkboxes) from a non-fillable PDF."""

import argparse
import json

import pdfplumber


def extract_structure(pdf_path: str) -> dict:
    """Analyze PDF layout and return structural elements."""
    structure: dict = {
        "pages": [],
        "labels": [],
        "lines": [],
        "checkboxes": [],
        "row_boundaries": [],
    }

    with pdfplumber.open(pdf_path) as pdf:
        for page_num, page in enumerate(pdf.pages, 1):
            structure["pages"].append({
                "page_number": page_num,
                "width": round(float(page.width), 1),
                "height": round(float(page.height), 1),
            })

            # Extract text labels with coordinates
            for word in page.extract_words():
                structure["labels"].append({
                    "page": page_num,
                    "text": word["text"],
                    "x0": round(float(word["x0"]), 1),
                    "top": round(float(word["top"]), 1),
                    "x1": round(float(word["x1"]), 1),
                    "bottom": round(float(word["bottom"]), 1),
                })

            # Extract horizontal lines spanning >50% of page width
            for line in page.lines:
                line_width = abs(float(line["x1"]) - float(line["x0"]))
                if line_width > page.width * 0.5:
                    structure["lines"].append({
                        "page": page_num,
                        "y": round(float(line["top"]), 1),
                        "x0": round(float(line["x0"]), 1),
                        "x1": round(float(line["x1"]), 1),
                    })

            # Detect checkboxes: small, roughly square rectangles
            for rect in page.rects:
                w = float(rect["x1"]) - float(rect["x0"])
                h = float(rect["bottom"]) - float(rect["top"])
                if 5 <= w <= 15 and 5 <= h <= 15 and abs(w - h) < 2:
                    structure["checkboxes"].append({
                        "page": page_num,
                        "x0": round(float(rect["x0"]), 1),
                        "top": round(float(rect["top"]), 1),
                        "x1": round(float(rect["x1"]), 1),
                        "bottom": round(float(rect["bottom"]), 1),
                        "center_x": round((float(rect["x0"]) + float(rect["x1"])) / 2, 1),
                        "center_y": round((float(rect["top"]) + float(rect["bottom"])) / 2, 1),
                    })

    # Compute row boundaries from horizontal lines
    lines_by_page: dict[int, list[float]] = {}
    for line in structure["lines"]:
        lines_by_page.setdefault(line["page"], []).append(line["y"])

    for page_num, y_coords in lines_by_page.items():
        y_coords = sorted(set(y_coords))
        for i in range(len(y_coords) - 1):
            structure["row_boundaries"].append({
                "page": page_num,
                "row_top": y_coords[i],
                "row_bottom": y_coords[i + 1],
                "row_height": round(y_coords[i + 1] - y_coords[i], 1),
            })

    return structure


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extract form structure from a non-fillable PDF."
    )
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("output", help="Output JSON file")
    args = parser.parse_args()

    structure = extract_structure(args.input)

    with open(args.output, "w") as f:
        json.dump(structure, f, indent=2)

    print(f"Pages: {len(structure['pages'])}")
    print(f"Labels: {len(structure['labels'])}")
    print(f"Lines: {len(structure['lines'])}")
    print(f"Checkboxes: {len(structure['checkboxes'])}")
    print(f"Row boundaries: {len(structure['row_boundaries'])}")
    print(f"Saved to {args.output}")


if __name__ == "__main__":
    main()
