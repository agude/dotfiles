---
name: pdf
description: >-
  Process PDF files: extract text and tables, fill forms (fillable and
  non-fillable), merge, split, rotate, encrypt, decrypt, extract metadata,
  convert to images, and OCR scanned documents. Use whenever the user mentions
  a .pdf file or asks to produce, read, modify, or analyze one.
compatibility: Requires uv and Python 3.11+. OCR scripts require tesseract.
allowed-tools: "Bash({baseDir}/scripts/:*) Read"
---

# PDF Processing

## Quick Start

All scripts run via `uv run` with no manual dependency installation:

```bash
uv run {baseDir}/scripts/extract_text.py document.pdf
```

## Decision Tree

**Reading / extracting content:**

1. Run `extract_text.py` first (fast, works on born-digital PDFs)
2. If little/no text is returned, the PDF is scanned — use `ocr_text.py`
3. For tables specifically, `extract_text.py --tables` outputs structured data

**Filling a form:**

1. Run `check_fields.py` to detect fillable form fields
2. If fillable: follow the [Fillable Form Workflow](#fillable-form-workflow)
3. If not fillable: follow the [Non-Fillable Form Workflow](#non-fillable-form-workflow)
4. See [references/form-filling.md](references/form-filling.md) for detailed
   instructions on the non-fillable workflow (coordinate systems, visual
   estimation, hybrid approach)

**Common operations:**

| Task | Script |
|------|--------|
| Extract text | `extract_text.py input.pdf` |
| Extract tables | `extract_text.py --tables input.pdf` |
| OCR scanned PDF to text | `ocr_text.py input.pdf` |
| Add OCR text layer to PDF | `ocr_pdf.py input.pdf output.pdf` |
| Detect page orientation | `detect_orientation.py input.pdf` |
| OCR + auto-rotate | `ocr_pdf.py --rotate input.pdf output.pdf` |
| Merge PDFs | `merge.py -o out.pdf a.pdf b.pdf c.pdf` |
| Split PDF | `split.py input.pdf output_dir/` |
| Split page range | `split.py input.pdf output.pdf --pages 1-5` |
| Rotate pages | `rotate.py input.pdf output.pdf --angle 90` |
| Rotate specific pages | `rotate.py input.pdf output.pdf --angle 90 --pages 1,3,5` |
| Show metadata | `metadata.py input.pdf` |
| Encrypt PDF | `encrypt.py input.pdf output.pdf --user-password secret` |
| Decrypt PDF | `decrypt.py input.pdf output.pdf --password secret` |
| Convert to images | `pdf_to_images.py input.pdf output_dir/` |
| Check for form fields | `check_fields.py input.pdf` |

All scripts accept `--help` for full usage.

**Custom PDF work (reportlab, advanced pdfplumber, etc.):**

See [references/python-libraries.md](references/python-libraries.md) and
[references/cli-tools.md](references/cli-tools.md) for recipes.

## Script Reference

Every script is self-contained with inline dependencies (PEP 723). Run any
script with `uv run {baseDir}/scripts/<name>.py`.

### Text Extraction

**`extract_text.py`** — Extract text or tables from born-digital PDFs.
- `extract_text.py input.pdf` — print all text to stdout
- `extract_text.py --tables input.pdf` — extract tables as CSV
- `extract_text.py --pages 1-3 input.pdf` — specific page range

**`ocr_text.py`** — OCR scanned/image PDFs to text via tesseract.
- `ocr_text.py input.pdf` — print OCR text to stdout
- `ocr_text.py --pages 1-3 input.pdf` — specific page range
- Requires `tesseract` installed on the system

**`ocr_pdf.py`** — Add searchable text layer to a scanned PDF.
- `ocr_pdf.py input.pdf output.pdf` — produce searchable PDF
- `ocr_pdf.py --rotate input.pdf output.pdf` — auto-rotate pages first
- `ocr_pdf.py --deskew input.pdf output.pdf` — deskew before OCR
- Requires `tesseract` installed on the system

**`detect_orientation.py`** — Detect page rotation using tesseract OSD.
- `detect_orientation.py input.pdf` — report orientation per page
- `detect_orientation.py --pages 1-3 input.pdf` — specific pages
- Requires `tesseract` installed on the system

### Manipulation

**`merge.py`** — Combine multiple PDFs into one.
- `merge.py -o merged.pdf a.pdf b.pdf c.pdf`

**`split.py`** — Split a PDF into pages or a range.
- `split.py input.pdf output_dir/` — one file per page
- `split.py input.pdf output.pdf --pages 1-5` — extract page range

**`rotate.py`** — Rotate PDF pages.
- `rotate.py input.pdf output.pdf --angle 90` — all pages
- `rotate.py input.pdf output.pdf --angle 90 --pages 1,3` — specific pages

**`metadata.py`** — Display PDF metadata.
- `metadata.py input.pdf` — print title, author, creator, etc.
- `metadata.py --json input.pdf` — output as JSON

### Security

**`encrypt.py`** — Add password protection.
- `encrypt.py input.pdf output.pdf --user-password read_pw`
- `encrypt.py input.pdf output.pdf --user-password read_pw --owner-password admin_pw`

**`decrypt.py`** — Remove password protection.
- `decrypt.py input.pdf output.pdf --password secret`

### Conversion

**`pdf_to_images.py`** — Convert PDF pages to PNG images.
- `pdf_to_images.py input.pdf output_dir/` — all pages
- `pdf_to_images.py --pages 1-3 --dpi 300 input.pdf output_dir/`
- Uses pypdfium2 (no poppler dependency)

### Form Filling

**`check_fields.py`** — Detect whether a PDF has fillable form fields.
- `check_fields.py input.pdf` — prints result and exits 0 (has fields) or 1

**`extract_fields.py`** — Dump fillable field metadata to JSON.
- `extract_fields.py input.pdf fields.json`
- Output includes field IDs, types, pages, bounding boxes

**`fill_fields.py`** — Fill fillable form fields from a JSON values file.
- `fill_fields.py input.pdf values.json output.pdf`
- Validates field IDs and values before writing

**`extract_structure.py`** — Extract layout from non-fillable PDFs.
- `extract_structure.py input.pdf structure.json`
- Outputs text labels, horizontal lines, checkboxes, row boundaries

**`fill_annotations.py`** — Fill non-fillable PDFs via text annotations.
- `fill_annotations.py input.pdf fields.json output.pdf`
- Accepts both PDF and image coordinate systems

**`check_boxes.py`** — Validate bounding boxes in a fields.json file.
- `check_boxes.py fields.json` — checks for overlaps and sizing errors

**`validation_image.py`** — Overlay bounding boxes on a page image for QA.
- `validation_image.py --page 1 fields.json page_1.png output.png`

## Fillable Form Workflow

1. Confirm the PDF has fillable fields:
   ```bash
   uv run {baseDir}/scripts/check_fields.py input.pdf
   ```

2. Extract field metadata:
   ```bash
   uv run {baseDir}/scripts/extract_fields.py input.pdf field_info.json
   ```

3. Convert to images to understand each field's purpose:
   ```bash
   uv run {baseDir}/scripts/pdf_to_images.py input.pdf images/
   ```

4. Examine the images and `field_info.json`. Create `values.json`:
   ```json
   [
     {
       "field_id": "last_name",
       "page": 1,
       "value": "Smith"
     },
     {
       "field_id": "citizen_yes",
       "page": 1,
       "value": "/On"
     }
   ]
   ```
   - For checkboxes, use the `checked_value` / `unchecked_value` from field_info
   - For radio groups, use one of the `radio_options` values
   - For choice fields, use one of the `choice_options` values

5. Fill the form:
   ```bash
   uv run {baseDir}/scripts/fill_fields.py input.pdf values.json output.pdf
   ```

6. Verify by converting the output to images:
   ```bash
   uv run {baseDir}/scripts/pdf_to_images.py output.pdf verify/
   ```

## Non-Fillable Form Workflow

For PDFs without fillable form fields, text is added as annotations. This
workflow requires determining where to place text on each page.

**Read [references/form-filling.md](references/form-filling.md) for the
complete workflow.** Summary of the three approaches:

### Approach A: Structure-Based (preferred)

1. Extract form structure:
   ```bash
   uv run {baseDir}/scripts/extract_structure.py input.pdf structure.json
   ```
2. If `structure.json` has meaningful text labels, use their coordinates to
   build `fields.json` (see reference for format)
3. Validate: `uv run {baseDir}/scripts/check_boxes.py fields.json`
4. Fill: `uv run {baseDir}/scripts/fill_annotations.py input.pdf fields.json output.pdf`

### Approach B: Visual Estimation (fallback)

1. Convert to images: `uv run {baseDir}/scripts/pdf_to_images.py input.pdf images/`
2. Examine images, estimate field positions in pixel coordinates
3. Use `magick` to crop and zoom for precision (see reference)
4. Build `fields.json` with `image_width`/`image_height` keys
5. Validate and fill as above

### Approach C: Hybrid

Use structure extraction for most fields, visual estimation for any the
structure extraction missed (e.g., circular checkboxes). Convert all
coordinates to PDF coordinate space. See reference for conversion formulas.

## Reportlab Warning

Never use Unicode subscript/superscript characters in reportlab PDFs. The
built-in fonts lack these glyphs, rendering them as black boxes. Use
`<sub>` and `<super>` tags in Paragraph objects instead.
