# /// script
# requires-python = ">=3.11"
# dependencies = ["ocrmypdf>=15.0"]
# ///
"""Add a searchable text layer to a scanned PDF."""

import argparse
import os
import shutil
import sys
import tempfile
from pathlib import Path

import ocrmypdf


def ocr_one(input_path: str, output_path: str, **kwargs) -> str:
    """OCR a single file. Returns a status string: 'ok', 'skip', or raises."""
    result = ocrmypdf.ocr(input_path, output_path, **kwargs)
    if result == ocrmypdf.ExitCode.ok:
        return "ok"
    elif result == ocrmypdf.ExitCode.already_done_ocr:
        return "skip"
    else:
        raise RuntimeError(f"OCR failed with exit code: {result}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Add searchable text layer to a scanned PDF."
    )
    parser.add_argument("input", nargs="+", help="Input PDF file(s)")
    parser.add_argument("-o", "--output", default=None, help="Output PDF file (single input only)")
    parser.add_argument("-d", "--output-dir", default=None, help="Output directory (batch mode)")
    parser.add_argument("--in-place", "-i", action="store_true", help="Overwrite the input file(s)")
    parser.add_argument("--deskew", action="store_true", help="Deskew pages before OCR")
    parser.add_argument("--rotate", action="store_true", help="Auto-rotate pages to correct orientation")
    parser.add_argument("--lang", default="eng", help="Tesseract language (default: eng)")
    parser.add_argument("--force", action="store_true", help="Re-OCR even if the PDF already has text")
    parser.add_argument("--porcelain", action="store_true", help="Machine-readable tab-delimited output")
    parser.add_argument("--fail-fast", action="store_true", help="Stop on first error")
    args = parser.parse_args()

    # --- Validate output mode ---
    # Detect legacy two-positional pattern: exactly 2 inputs where second doesn't exist as a file
    if (len(args.input) == 2
            and not args.in_place
            and not args.output
            and not args.output_dir
            and not Path(args.input[1]).exists()):
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

    if not shutil.which("tesseract"):
        print("Error: tesseract is not installed or not in PATH", file=sys.stderr)
        sys.exit(1)

    kwargs: dict = {
        "language": args.lang,
        "deskew": args.deskew,
        "rotate_pages": args.rotate,
    }
    if args.force:
        kwargs["force_ocr"] = True
    else:
        kwargs["skip_text"] = True

    # --- Process files ---
    failures = 0
    successes = 0

    for input_file in args.input:
        input_path = Path(input_file)

        # Determine output path
        if args.in_place:
            tmp_fd, tmp_path = tempfile.mkstemp(suffix=".pdf", dir=input_path.parent)
            os.close(tmp_fd)
            out_path = tmp_path
        elif args.output_dir:
            out_path = str(Path(args.output_dir) / input_path.name)
        else:
            out_path = args.output

        try:
            status = ocr_one(input_file, out_path, **kwargs)

            if status == "ok":
                if args.in_place:
                    Path(out_path).replace(input_path)
                successes += 1
                if args.porcelain:
                    print(f"ok\t{input_file}\tOCR complete")
                else:
                    label = "in-place" if args.in_place else out_path
                    print(f"OCR complete ({label}): {input_file}")

            elif status == "skip":
                if args.in_place:
                    Path(out_path).unlink(missing_ok=True)
                successes += 1
                if args.porcelain:
                    print(f"skip\t{input_file}\talready has text")
                else:
                    print(f"PDF already has text. Use --force to re-OCR: {input_file}")

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
        print(f"\nProcessed {successes + failures} files ({successes} succeeded, {failures} failed)")

    if failures:
        sys.exit(1)


if __name__ == "__main__":
    main()
