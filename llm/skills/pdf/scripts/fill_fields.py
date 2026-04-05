# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Fill fillable PDF form fields from a JSON values file."""

import argparse
import json
import sys

from pypdf import PdfReader, PdfWriter


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


def extract_field_info(reader: PdfReader) -> dict[str, dict]:
    """Extract field metadata for validation. Returns dict keyed by field_id."""
    fields = reader.get_fields()
    if not fields:
        return {}

    info: dict[str, dict] = {}
    possible_radios: set[str] = set()

    for field_id, field in fields.items():
        if field.get("/Kids"):
            if field.get("/FT") == "/Btn":
                possible_radios.add(field_id)
            continue

        entry: dict = {"field_id": field_id}
        ft = field.get("/FT")
        if ft == "/Tx":
            entry["type"] = "text"
        elif ft == "/Btn":
            entry["type"] = "checkbox"
            states = field.get("/_States_", [])
            if len(states) == 2:
                if "/Off" in states:
                    entry["checked_value"] = states[0] if states[0] != "/Off" else states[1]
                    entry["unchecked_value"] = "/Off"
                else:
                    entry["checked_value"] = states[0]
                    entry["unchecked_value"] = states[1]
        elif ft == "/Ch":
            entry["type"] = "choice"
            states = field.get("/_States_", [])
            entry["choice_options"] = [
                s[0] if isinstance(s, list) and len(s) == 2 else s
                for s in states
            ]
        else:
            entry["type"] = f"unknown ({ft})"
        info[field_id] = entry

    # Find page numbers from annotations
    for page_idx, page in enumerate(reader.pages):
        for ann in page.get("/Annots", []):
            fid = get_full_field_id(ann)
            if fid in info:
                info[fid]["page"] = page_idx + 1
            elif fid in possible_radios:
                try:
                    on_values = [v for v in ann["/AP"]["/N"] if v != "/Off"]
                except (KeyError, TypeError):
                    continue
                if len(on_values) == 1:
                    if fid not in info:
                        info[fid] = {
                            "field_id": fid,
                            "type": "radio_group",
                            "page": page_idx + 1,
                            "radio_options": [],
                        }
                    info[fid]["radio_options"].append(on_values[0])

    return info


def validate_field_value(field_meta: dict, value: str) -> str | None:
    """Return an error message if value is invalid for this field type."""
    ftype = field_meta.get("type")
    fid = field_meta["field_id"]

    if ftype == "checkbox":
        checked = field_meta.get("checked_value")
        unchecked = field_meta.get("unchecked_value")
        if value not in (checked, unchecked):
            return (
                f'Invalid value "{value}" for checkbox "{fid}". '
                f'Use "{checked}" (checked) or "{unchecked}" (unchecked)'
            )
    elif ftype == "radio_group":
        options = field_meta.get("radio_options", [])
        if value not in options:
            return f'Invalid value "{value}" for radio group "{fid}". Options: {options}'
    elif ftype == "choice":
        options = field_meta.get("choice_options", [])
        if value not in options:
            return f'Invalid value "{value}" for choice field "{fid}". Options: {options}'

    return None


def main() -> None:
    parser = argparse.ArgumentParser(description="Fill fillable PDF form fields.")
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("values", help="JSON file with field values")
    parser.add_argument("output", help="Output PDF file")
    args = parser.parse_args()

    with open(args.values) as f:
        values = json.load(f)

    reader = PdfReader(args.input)
    field_info = extract_field_info(reader)

    # Validate all values before writing
    errors: list[str] = []
    for entry in values:
        fid = entry["field_id"]
        meta = field_info.get(fid)
        if not meta:
            errors.append(f'"{fid}" is not a valid field ID')
        elif "page" in meta and entry.get("page") and entry["page"] != meta["page"]:
            errors.append(
                f'Wrong page for "{fid}": got {entry["page"]}, expected {meta["page"]}'
            )
        elif "value" in entry:
            err = validate_field_value(meta, entry["value"])
            if err:
                errors.append(err)

    if errors:
        for err in errors:
            print(f"ERROR: {err}", file=sys.stderr)
        sys.exit(1)

    # Group values by page
    by_page: dict[int, dict[str, str]] = {}
    for entry in values:
        if "value" not in entry:
            continue
        page = entry.get("page") or field_info[entry["field_id"]].get("page", 1)
        by_page.setdefault(page, {})[entry["field_id"]] = entry["value"]

    writer = PdfWriter(clone_from=reader)
    for page_num, field_values in by_page.items():
        writer.update_page_form_field_values(
            writer.pages[page_num - 1], field_values, auto_regenerate=False
        )
    writer.set_need_appearances_writer(True)

    with open(args.output, "wb") as f:
        writer.write(f)

    total = sum(len(v) for v in by_page.values())
    print(f"Filled {total} fields, saved to {args.output}")


if __name__ == "__main__":
    main()
