---
name: pdf
description: Extracts, OCRs, fills, converts, splits, merges, rotates, secures, watermarks, and analyzes PDF files. Use when working with PDFs, forms, scanned documents, PDF text, or PDF metadata.
compatibility: Requires uv and Python 3.11+. OCR scripts require tesseract.
---

# PDF Processing

Use the bundled scripts for standard PDF operations. Preserve the source file
by default. Write a separate output file, inspect it, and replace the source
only when the task explicitly requires an in-place change.

`$SKILL_DIR` is the absolute directory containing this skill's `SKILL.md`.
Run scripts with:

```bash
uv run "$SKILL_DIR/scripts/<script>.py" --help
```

## Select a workflow

| Task | Default workflow | Read for detail |
| --- | --- | --- |
| Read text | Run `extract_text.py`. Use `ocr_text.py` if extraction returns little or no text. | — |
| Create a searchable scan | Run `ocr_pdf.py` to a new output file. Add `--rotate` or `--deskew` only when needed. | — |
| Fill a form | Run `check_fields.py`, then use the fillable or non-fillable workflow below. | `references/form-filling.md` |
| Merge, split, rotate, convert, or secure | Use the matching bundled script. | — |
| Create or customize a PDF, including watermarking | Use the established Python-library or CLI recipe. | `references/python-libraries.md` or `references/cli-tools.md` |

Pass `--porcelain` when a script supports it and an agent consumes its output
programmatically. For batch work, use `--fail-fast` when the script supports
it and one failed input makes the remaining work invalid. Scripts that change
files accept `-o`/`--output`, `-d`/`--output-dir`, or `-i`/`--in-place` as
their operation permits.

## Standard operations

Use a named output file for a single input unless the request requires
in-place modification.

| Operation | Command pattern |
| --- | --- |
| Extract text | `extract_text.py input.pdf` |
| Extract tables | `extract_text.py --tables input.pdf` |
| OCR to text | `ocr_text.py input.pdf` |
| OCR to searchable PDF | `ocr_pdf.py input.pdf -o searchable.pdf` |
| Detect page orientation | `detect_orientation.py input.pdf` |
| Merge | `merge.py -o merged.pdf first.pdf second.pdf` |
| Split pages | `split.py input.pdf -d pages/` |
| Extract a page range | `split.py input.pdf -o excerpt.pdf --pages 1-5` |
| Rotate | `rotate.py input.pdf -o rotated.pdf --angle 90` |
| Render pages | `pdf_to_images.py input.pdf -d images/` |
| Show metadata | `metadata.py input.pdf` |
| Encrypt | `encrypt.py input.pdf -o protected.pdf --user-password <password>` |
| Decrypt | `decrypt.py input.pdf -o decrypted.pdf --password <password>` |
| Add a supplied text layer | `add_text_layer.py input.pdf output.pdf --file transcript.txt` |

Prefix each pattern with `uv run "$SKILL_DIR/scripts/"`. Run the script with
`--help` before using an option not shown here.

Do not put passwords in shell history, source files, logs, or status reports.
Use the environment, prompt, or secret-handling mechanism established by the
target environment.

## Non-default and batch operations

All bundled scripts are self-contained with PEP 723 dependencies. They accept
multiple inputs where noted. Use `--porcelain` for machine-readable output:
text-reading scripts emit JSONL; file-producing scripts emit tab-delimited
status. Use `--fail-fast` to stop a batch on its first failure; otherwise the
scripts continue and report failures.

| Script | Useful non-default operations |
| --- | --- |
| `extract_text.py` | `--tables` writes CSV; `--pages 1-3,5` limits extraction; multiple inputs print file headers. |
| `ocr_text.py` | `--pages 1-3,5` limits OCR; multiple inputs print file headers. Requires `tesseract`. |
| `ocr_pdf.py` | `-i` updates one or more files atomically; `-d output-dir/` writes batch output; `--rotate` and `--deskew` preprocess scans. |
| `detect_orientation.py` | `--pages 1-3,5` limits detection. Requires `tesseract`. |
| `check_fields.py` | Accepts multiple PDFs. Exits 0 when at least one input has fillable fields and 1 when none do; use `--porcelain` for JSONL results. |
| `split.py` | `-d output-dir/` splits every page; `-d output-dir/ input1.pdf input2.pdf` gives each source a subdirectory. |
| `rotate.py` | `--pages 1,3,5` limits rotation; `-i` or `-d output-dir/` supports batches. |
| `metadata.py` | `--json` returns metadata as JSON. |
| `encrypt.py` | `--owner-password` sets the full-permission password separately; `-i` or `-d output-dir/` supports batches. |
| `decrypt.py` | `-i` or `-d output-dir/` supports batches; unencrypted files are skipped with a message. |
| `pdf_to_images.py` | `--pages 1-3,5` limits rendering; `--dpi 300` controls resolution; `-d output-dir/` supports batches. Rendering uses `pypdfium2`, not Poppler. |

The file-producing scripts retain their legacy two-positional output syntax
for compatibility, but use `-o` or `-d` in new commands. A single `-o` output
requires one input; a batch requires `-i` or `-d`.

Use a manual text layer when OCR cannot read content such as handwriting but a
transcription exists:

```bash
uv run "$SKILL_DIR/scripts/add_text_layer.py" input.pdf output.pdf \
  --file transcript.txt
```

This makes scanned pages searchable and selectable without replacing the
visible image.

To add supplied text in place, use
`add_text_layer.py -i input.pdf "transcription"`. The script writes through an
atomic temporary file.

## Read and OCR PDFs

1. Run `extract_text.py` first. It is faster and preserves text from
   born-digital PDFs.
2. If the result is missing, sparse, or unusable, run `ocr_text.py`.
3. To produce a searchable document, run `ocr_pdf.py -o <output.pdf>`.
4. Render the output with `pdf_to_images.py` when visual verification matters.

OCR requires `tesseract`. Use `--lang <language>` when the document is not in
English. Use `--rotate` for incorrectly oriented scans and `--deskew` for
skewed pages. Do not force OCR on a PDF that already has usable text unless
the task requires replacing its text layer.

## Fill forms

Start every form task by detecting fields. The script exits 0 when the PDF has
fillable fields and 1 when it does not:

```bash
uv run "$SKILL_DIR/scripts/check_fields.py" input.pdf
```

### Fillable forms

1. Extract field metadata with `extract_fields.py input.pdf fields.json`. The
   JSON records each field's ID, type, page, and bounding box.
2. Render the source PDF with `pdf_to_images.py` to confirm each field's
   purpose.
3. Create a values JSON file using the extracted field IDs and allowed values.
4. Fill the form with `fill_fields.py input.pdf values.json output.pdf`. It
   validates field IDs, page numbers, and allowed values before writing.
5. Render `output.pdf` and verify the completed fields.

For checkboxes, radio groups, and choice fields, use the values reported in
the field metadata exactly. Read `references/form-filling.md` for the JSON
format and field-type rules.

### Non-fillable forms

1. Run `extract_structure.py input.pdf structure.json`.
2. Use its labels, lines, checkboxes, and row boundaries to create
   `fields.json`.
3. Validate it with `check_boxes.py fields.json`.
4. Use `validation_image.py` to overlay the fields on a rendered source page
   when coordinate accuracy is uncertain.
5. Fill the PDF with `fill_annotations.py input.pdf fields.json output.pdf`.
   It accepts PDF and image coordinate systems.
6. Render the output and inspect every completed page.

If structure extraction cannot identify reliable labels, use the visual or
hybrid coordinate workflow in `references/form-filling.md`. It uses rendered
page dimensions; crop and zoom the page when visual estimation needs more
precision. Validate bounding boxes before writing the final PDF.

## Verify outputs

Verify each file-producing operation before reporting completion:

1. Confirm the output exists and the script completed without an error.
2. Reopen or extract text from the output as appropriate.
3. Render affected pages to images when layout, rotation, OCR, or form entries
   matter.
4. For encrypted files, verify the intended password behavior without exposing
   the password.

Use `metadata.py` to inspect metadata and `check_fields.py` to confirm form
fields when relevant. Do not claim visual accuracy without inspecting rendered
pages.

## Reference material

- `references/form-filling.md`: field values, coordinate systems,
  `fields.json`, and non-fillable form workflows.
- `references/python-libraries.md`: custom work with pypdf, pdfplumber,
  reportlab, and pypdfium2. Read this before using ReportLab; its built-in
  fonts render Unicode subscript and superscript glyphs as black boxes. Use
  `<sub>` and `<super>` in `Paragraph` objects instead.
- `references/cli-tools.md`: system tools including Poppler, qpdf, pdftk, and
  ocrmypdf.
