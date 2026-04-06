# /// script
# requires-python = ">=3.11"
# dependencies = ["Pillow>=10.0"]
# ///
"""Overlay bounding boxes on a page image for visual QA."""

import argparse
import json

from PIL import Image, ImageDraw


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Draw bounding boxes on a page image for validation."
    )
    parser.add_argument("fields", help="fields.json file")
    parser.add_argument("image", help="Input page image (PNG)")
    parser.add_argument("output", help="Output image path")
    parser.add_argument("--page", type=int, required=True, help="Page number to visualize")
    args = parser.parse_args()

    with open(args.fields) as f:
        data = json.load(f)

    img = Image.open(args.image)
    draw = ImageDraw.Draw(img)
    count = 0

    for field in data["form_fields"]:
        if field["page_number"] != args.page:
            continue
        draw.rectangle(field["label_bounding_box"], outline="blue", width=2)
        draw.rectangle(field["entry_bounding_box"], outline="red", width=2)
        count += 2

    img.save(args.output)
    print(f"Drew {count} boxes on page {args.page}, saved to {args.output}")


if __name__ == "__main__":
    main()
