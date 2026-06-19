# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0"]
# ///
"""Add password protection to a PDF."""

import argparse
import os
import sys
import tempfile
from pathlib import Path

from pypdf import PdfReader, PdfWriter


def encrypt_one(input_file: str, output_file: str, user_pw: str, owner_pw: str) -> None:
    """Encrypt a single PDF."""
    reader = PdfReader(input_file)
    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)
    writer.encrypt(user_pw, owner_pw)
    with open(output_file, "wb") as f:
        writer.write(f)


def main() -> None:
    parser = argparse.ArgumentParser(description="Encrypt a PDF with password protection.")
    parser.add_argument("input", nargs="+", help="Input PDF file(s)")
    parser.add_argument("-o", "--output", default=None, help="Output PDF file (single input only)")
    parser.add_argument("-d", "--output-dir", default=None, help="Output directory (batch mode)")
    parser.add_argument("--in-place", "-i", action="store_true", help="Overwrite the input file(s)")
    parser.add_argument("--user-password", required=True, help="Password required to open the PDF")
    parser.add_argument("--owner-password", help="Password for full permissions (defaults to user password)")
    parser.add_argument("--porcelain", action="store_true", help="Machine-readable tab-delimited output")
    parser.add_argument("--fail-fast", action="store_true", help="Stop on first error")
    args = parser.parse_args()

    # Detect legacy two-positional pattern: encrypt.py input.pdf output.pdf --user-password ...
    if (len(args.input) == 2
            and not args.in_place
            and not args.output
            and not args.output_dir
            and not Path(args.input[1]).is_file()):
        print(
            f"Warning: treating '{args.input[1]}' as output path (legacy mode). "
            "Use -o/--output instead.",
            file=sys.stderr,
        )
        args.output = args.input.pop()

    multi = len(args.input) > 1

    if multi:
        if args.output:
            print("Error: -o/--output requires a single input file. Use -d/--output-dir for batch.", file=sys.stderr)
            sys.exit(1)
        if not args.in_place and not args.output_dir:
            print("Error: batch mode requires --in-place or --output-dir", file=sys.stderr)
            sys.exit(1)
    else:
        modes = sum([args.in_place, args.output is not None, args.output_dir is not None])
        if modes == 0:
            print("Error: specify -o, -d, or --in-place", file=sys.stderr)
            sys.exit(1)
        if modes > 1:
            print("Error: use only one of -o, -d, or --in-place", file=sys.stderr)
            sys.exit(1)

    if args.output_dir:
        Path(args.output_dir).mkdir(parents=True, exist_ok=True)

    owner_pw = args.owner_password or args.user_password
    failures = 0
    successes = 0

    for input_file in args.input:
        input_path = Path(input_file)

        if args.in_place:
            tmp_fd, tmp_path = tempfile.mkstemp(suffix=".pdf", dir=input_path.parent)
            os.close(tmp_fd)
            out_path = tmp_path
        elif args.output_dir:
            out_path = str(Path(args.output_dir) / input_path.name)
        else:
            out_path = args.output

        try:
            encrypt_one(input_file, out_path, args.user_password, owner_pw)

            if args.in_place:
                Path(out_path).replace(input_path)

            successes += 1
            if args.porcelain:
                print(f"ok\t{input_file}\tencrypted")
            else:
                label = "in-place" if args.in_place else out_path
                print(f"Encrypted ({label}): {input_file}")

        except Exception as e:
            if args.in_place:
                Path(out_path).unlink(missing_ok=True)
            failures += 1
            if args.porcelain:
                print(f"error\t{input_file}\t{e}")
            else:
                print(f"Error processing {input_file}: {e}", file=sys.stderr)
            if args.fail_fast:
                sys.exit(1)

    if multi and not args.porcelain:
        print(f"\nEncrypted {successes + failures} files ({successes} succeeded, {failures} failed)")

    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
