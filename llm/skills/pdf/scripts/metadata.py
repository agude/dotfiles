# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Display PDF metadata."""

import argparse
import json

from pypdf import PdfReader


def main() -> None:
    parser = argparse.ArgumentParser(description="Display PDF metadata.")
    parser.add_argument("input", help="Input PDF file")
    parser.add_argument("--json", action="store_true", dest="as_json", help="Output as JSON")
    args = parser.parse_args()

    reader = PdfReader(args.input)
    meta = reader.metadata

    info = {
        "pages": len(reader.pages),
        "title": meta.title if meta else None,
        "author": meta.author if meta else None,
        "subject": meta.subject if meta else None,
        "creator": meta.creator if meta else None,
        "producer": meta.producer if meta else None,
        "creation_date": str(meta.creation_date) if meta and meta.creation_date else None,
        "modification_date": str(meta.modification_date) if meta and meta.modification_date else None,
    }

    if args.as_json:
        print(json.dumps(info, indent=2))
    else:
        for key, value in info.items():
            label = key.replace("_", " ").title()
            print(f"{label}: {value if value is not None else '(none)'}")


if __name__ == "__main__":
    main()
