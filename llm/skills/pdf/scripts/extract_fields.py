# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Extract fillable form field metadata from a PDF to JSON."""

import argparse
import json
import sys

from pypdf import PdfReader


def get_full_field_id(annotation) -> str | None:
    """Walk the /Parent chain to build a dotted field ID."""
    components: list[str] = []
    node = annotation
    while node:
        name = node.get("/T")
        if name:
            components.append(str(name))
        node = node.get("/Parent")
    return ".".join(reversed(components)) if components else None


def make_field_dict(field, field_id: str) -> dict:
    """Build a field info dict from a pypdf field object."""
    info: dict = {"field_id": field_id}
    ft = field.get("/FT")

    if ft == "/Tx":
        info["type"] = "text"
    elif ft == "/Btn":
        info["type"] = "checkbox"
        states = field.get("/_States_", [])
        if len(states) == 2:
            if "/Off" in states:
                info["checked_value"] = states[0] if states[0] != "/Off" else states[1]
                info["unchecked_value"] = "/Off"
            else:
                info["checked_value"] = states[0]
                info["unchecked_value"] = states[1]
    elif ft == "/Ch":
        info["type"] = "choice"
        states = field.get("/_States_", [])
        info["choice_options"] = [
            {"value": s[0], "text": s[1]} if isinstance(s, list) and len(s) == 2
            else {"value": s, "text": str(s)}
            for s in states
        ]
    else:
        info["type"] = f"unknown ({ft})"

    return info


def extract_fields(reader: PdfReader) -> list[dict]:
    """Extract all form fields with their page locations."""
    fields = reader.get_fields()
    if not fields:
        return []

    field_info_by_id: dict[str, dict] = {}
    possible_radio_names: set[str] = set()

    for field_id, field in fields.items():
        if field.get("/Kids"):
            if field.get("/FT") == "/Btn":
                possible_radio_names.add(field_id)
            continue
        field_info_by_id[field_id] = make_field_dict(field, field_id)

    radio_fields: dict[str, dict] = {}

    for page_idx, page in enumerate(reader.pages):
        annotations = page.get("/Annots", [])
        for ann in annotations:
            field_id = get_full_field_id(ann)
            if field_id in field_info_by_id:
                field_info_by_id[field_id]["page"] = page_idx + 1
                rect = ann.get("/Rect")
                if rect:
                    field_info_by_id[field_id]["rect"] = [float(v) for v in rect]
            elif field_id in possible_radio_names:
                try:
                    on_values = [v for v in ann["/AP"]["/N"] if v != "/Off"]
                except (KeyError, TypeError):
                    continue
                if len(on_values) == 1:
                    rect = ann.get("/Rect")
                    if field_id not in radio_fields:
                        radio_fields[field_id] = {
                            "field_id": field_id,
                            "type": "radio_group",
                            "page": page_idx + 1,
                            "radio_options": [],
                        }
                    radio_fields[field_id]["radio_options"].append({
                        "value": on_values[0],
                        "rect": [float(v) for v in rect] if rect else None,
                    })

    # Collect fields that have a page location
    result: list[dict] = []
    for info in field_info_by_id.values():
        if "page" in info:
            result.append(info)
        else:
            print(
                f"Warning: no page location for field '{info['field_id']}', skipping",
                file=sys.stderr,
            )

    result.extend(radio_fields.values())

    # Sort by page, then by position (top-to-bottom, left-to-right)
    def sort_key(f: dict) -> list:
        if "radio_options" in f:
            rect = f["radio_options"][0].get("rect") or [0, 0, 0, 0]
        else:
            rect = f.get("rect") or [0, 0, 0, 0]
        return [f.get("page", 0), -rect[1], rect[0]]

    result.sort(key=sort_key)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extract fillable form field metadata to JSON."
    )
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("output", help="Output JSON file")
    args = parser.parse_args()

    reader = PdfReader(args.input)
    field_list = extract_fields(reader)

    with open(args.output, "w") as f:
        json.dump(field_list, f, indent=2)

    print(f"Wrote {len(field_list)} fields to {args.output}")


if __name__ == "__main__":
    main()
