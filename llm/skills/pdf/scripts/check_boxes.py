# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Validate bounding boxes in a fields.json file."""

import argparse
import json
import sys


def rects_intersect(r1: list, r2: list) -> bool:
    """Check if two [x0, y0, x1, y1] rectangles overlap."""
    disjoint_h = r1[0] >= r2[2] or r1[2] <= r2[0]
    disjoint_v = r1[1] >= r2[3] or r1[3] <= r2[1]
    return not (disjoint_h or disjoint_v)


def validate(fields_data: dict) -> list[str]:
    """Return a list of error/success messages."""
    messages: list[str] = []
    form_fields = fields_data.get("form_fields", [])
    messages.append(f"Checking {len(form_fields)} fields")

    # Collect all rects with their source info
    rects: list[tuple[list, str, dict]] = []  # (rect, type, field)
    for f in form_fields:
        rects.append((f["label_bounding_box"], "label", f))
        rects.append((f["entry_bounding_box"], "entry", f))

    has_error = False

    # Check for intersections
    for i, (ri, ti, fi) in enumerate(rects):
        for j in range(i + 1, len(rects)):
            rj, tj, fj = rects[j]
            if fi["page_number"] != fj["page_number"]:
                continue
            if rects_intersect(ri, rj):
                has_error = True
                if fi is fj:
                    messages.append(
                        f"FAIL: label/entry overlap for '{fi['description']}' "
                        f"({ri} vs {rj})"
                    )
                else:
                    messages.append(
                        f"FAIL: {ti} of '{fi['description']}' ({ri}) "
                        f"intersects {tj} of '{fj['description']}' ({rj})"
                    )
                if len(messages) >= 20:
                    messages.append("Too many errors; fix and re-run")
                    return messages

        # Check entry box height vs font size
        if ti == "entry" and "entry_text" in fi:
            font_size = fi["entry_text"].get("font_size", 14)
            height = ri[3] - ri[1]
            if height < font_size:
                has_error = True
                messages.append(
                    f"FAIL: entry box height ({height:.1f}) for "
                    f"'{fi['description']}' is shorter than font size ({font_size})"
                )

    if not has_error:
        messages.append("OK: all bounding boxes are valid")

    return messages


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate bounding boxes in fields.json.")
    parser.add_argument("input", help="fields.json file to validate")
    args = parser.parse_args()

    with open(args.input) as f:
        data = json.load(f)

    messages = validate(data)
    has_fail = False
    for msg in messages:
        print(msg)
        if msg.startswith("FAIL"):
            has_fail = True

    sys.exit(1 if has_fail else 0)


if __name__ == "__main__":
    main()
