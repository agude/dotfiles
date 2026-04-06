# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Fill non-fillable PDFs by adding FreeText annotations."""

import argparse
import json

from pypdf import PdfReader, PdfWriter
from pypdf.annotations import FreeText


def transform_image_to_pdf(bbox: list, img_w: float, img_h: float, pdf_w: float, pdf_h: float):
    """Convert image-space bbox [x0, y0, x1, y1] to pypdf rect coordinates."""
    x_scale = pdf_w / img_w
    y_scale = pdf_h / img_h
    left = bbox[0] * x_scale
    right = bbox[2] * x_scale
    # Image y=0 is top; PDF y=0 is bottom
    top = pdf_h - (bbox[1] * y_scale)
    bottom = pdf_h - (bbox[3] * y_scale)
    return (left, bottom, right, top)


def transform_pdf_coords(bbox: list, pdf_h: float):
    """Convert PDF-space bbox [x0, top, x1, bottom] to pypdf rect.

    Input uses pdfplumber convention: y=0 at top, increases downward.
    pypdf FreeText rect uses PDF convention: y=0 at bottom.
    """
    left = bbox[0]
    right = bbox[2]
    pypdf_top = pdf_h - bbox[1]
    pypdf_bottom = pdf_h - bbox[3]
    return (left, pypdf_bottom, right, pypdf_top)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Fill non-fillable PDFs with text annotations."
    )
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("fields", help="JSON file with field definitions")
    parser.add_argument("output", help="Output PDF file")
    args = parser.parse_args()

    with open(args.fields) as f:
        data = json.load(f)

    reader = PdfReader(args.input)
    writer = PdfWriter()
    writer.append(reader)

    # Get actual PDF dimensions per page
    pdf_dims: dict[int, tuple[float, float]] = {}
    for i, page in enumerate(reader.pages):
        mb = page.mediabox
        pdf_dims[i + 1] = (float(mb.width), float(mb.height))

    count = 0
    for field in data["form_fields"]:
        entry_text = field.get("entry_text", {})
        text = entry_text.get("text", "")
        if not text:
            continue

        page_num = field["page_number"]
        pdf_w, pdf_h = pdf_dims[page_num]

        page_info = next(p for p in data["pages"] if p["page_number"] == page_num)

        if "pdf_width" in page_info:
            rect = transform_pdf_coords(field["entry_bounding_box"], pdf_h)
        else:
            rect = transform_image_to_pdf(
                field["entry_bounding_box"],
                page_info["image_width"], page_info["image_height"],
                pdf_w, pdf_h,
            )

        font_name = entry_text.get("font", "Arial")
        font_size = str(entry_text.get("font_size", 14)) + "pt"
        font_color = entry_text.get("font_color", "000000")

        annotation = FreeText(
            text=text,
            rect=rect,
            font=font_name,
            font_size=font_size,
            font_color=font_color,
            border_color=None,
            background_color=None,
        )
        writer.add_annotation(page_number=page_num - 1, annotation=annotation)
        count += 1

    with open(args.output, "wb") as f:
        writer.write(f)

    print(f"Added {count} text annotations, saved to {args.output}")


if __name__ == "__main__":
    main()
