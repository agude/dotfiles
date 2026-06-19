# /// script
# requires-python = ">=3.11"
# dependencies = ["pypdf>=4.0", "reportlab>=4.0"]
# ///
"""Add an invisible text layer to an image-based PDF.

This is useful when OCR fails (e.g., handwriting) but you have a manual
transcription. The text becomes searchable/selectable while the original
image remains visible.

Usage:
    add_text_layer.py input.pdf output.pdf "Your transcription text here"
    add_text_layer.py input.pdf output.pdf --file transcription.txt
    add_text_layer.py -i input.pdf "Your transcription text here"
"""

import argparse
import sys
from io import BytesIO
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from reportlab.pdfgen import canvas


def create_text_layer(text: str, width: float, height: float) -> bytes:
    """Create a PDF with invisible text positioned in the content area."""
    buffer = BytesIO()
    c = canvas.Canvas(buffer, pagesize=(width, height))

    # Use a small font, render mode 3 = invisible
    c.setFont("Helvetica", 10)

    # Split text into lines and position in upper portion of page
    lines = text.strip().split('\n')
    y = height - 72  # Start 1 inch from top
    line_height = 14

    for line in lines:
        if line.strip():
            # Render mode 3 = invisible (fill and stroke are not rendered)
            c._code.append('3 Tr')  # Set text render mode to invisible
            c.drawString(72, y, line)
        y -= line_height
        if y < 72:  # Don't go below 1 inch margin
            break

    c.save()
    return buffer.getvalue()


def add_text_layer(input_path: Path, output_path: Path, text: str) -> None:
    """Add invisible text layer to each page of a PDF."""
    reader = PdfReader(input_path)
    writer = PdfWriter()

    for page in reader.pages:
        # Get page dimensions
        mediabox = page.mediabox
        width = float(mediabox.width)
        height = float(mediabox.height)

        # Create text layer PDF
        text_pdf_bytes = create_text_layer(text, width, height)
        text_reader = PdfReader(BytesIO(text_pdf_bytes))
        text_page = text_reader.pages[0]

        # Merge: text layer underneath, original on top
        text_page.merge_page(page)
        writer.add_page(text_page)

    with open(output_path, 'wb') as f:
        writer.write(f)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Add invisible text layer to image-based PDF"
    )
    parser.add_argument("input", type=Path, help="Input PDF file")
    parser.add_argument(
        "output", type=Path, nargs="?", help="Output PDF file (omit with -i)"
    )
    parser.add_argument(
        "text", nargs="?", help="Transcription text (or use --file)"
    )
    parser.add_argument(
        "-i", "--in-place", action="store_true",
        help="Modify input file in place"
    )
    parser.add_argument(
        "--file", type=Path, help="Read transcription from file"
    )

    args = parser.parse_args()

    # Determine output path
    if args.in_place:
        output_path = args.input
        text_arg = args.output  # With -i, second positional is text
    else:
        if not args.output:
            parser.error("output is required unless using -i")
        output_path = args.output
        text_arg = args.text

    # Get transcription text
    if args.file:
        text = args.file.read_text()
    elif text_arg:
        text = str(text_arg)
    else:
        parser.error("Transcription text required (positional or --file)")

    # Handle in-place via temp file
    if args.in_place:
        import tempfile
        with tempfile.NamedTemporaryFile(
            suffix=".pdf", delete=False, dir=args.input.parent
        ) as tmp:
            tmp_path = Path(tmp.name)
        try:
            add_text_layer(args.input, tmp_path, text)
            tmp_path.replace(args.input)
            print(f"ok\t{args.input}")
        except Exception:
            tmp_path.unlink(missing_ok=True)
            raise
    else:
        add_text_layer(args.input, output_path, text)
        print(f"ok\t{output_path}")


if __name__ == "__main__":
    main()
