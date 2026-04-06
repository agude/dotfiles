# CLI Tools Reference

Command-line tools for PDF processing. These are system packages, not Python
libraries.

## pdftotext (poppler-utils)

```bash
# Extract text
pdftotext input.pdf output.txt

# Preserve layout
pdftotext -layout input.pdf output.txt

# Specific pages (first 5)
pdftotext -f 1 -l 5 input.pdf output.txt

# Text with bounding box coordinates (XML output)
pdftotext -bbox-layout input.pdf output.xml
```

Install: `apt install poppler-utils` / `brew install poppler`

## pdftoppm (poppler-utils)

```bash
# Convert to PNG at 300 DPI
pdftoppm -png -r 300 input.pdf output_prefix

# Specific pages at high resolution
pdftoppm -png -r 600 -f 1 -l 3 input.pdf pages

# JPEG with quality setting
pdftoppm -jpeg -jpegopt quality=85 -r 200 input.pdf output
```

## pdfimages (poppler-utils)

```bash
# Extract embedded images as JPEG
pdfimages -j input.pdf output_prefix

# Extract in original format
pdfimages -all input.pdf images/img

# List image info without extracting
pdfimages -list input.pdf
```

## qpdf

### Merge and split
```bash
# Merge PDFs
qpdf --empty --pages file1.pdf file2.pdf -- merged.pdf

# Extract page range
qpdf input.pdf --pages . 1-5 -- pages1-5.pdf

# Complex page selection
qpdf input.pdf --pages input.pdf 1,3-5,8,10-end -- extracted.pdf

# Merge specific pages from multiple files
qpdf --empty --pages doc1.pdf 1-3 doc2.pdf 5-7 -- combined.pdf

# Split into groups of N pages
qpdf --split-pages=3 input.pdf output_%02d.pdf
```

### Rotation
```bash
# Rotate page 1 by 90 degrees
qpdf input.pdf output.pdf --rotate=+90:1
```

### Encryption
```bash
# Add password with restricted permissions
qpdf --encrypt user_pw owner_pw 256 --print=none --modify=none -- input.pdf encrypted.pdf

# Check encryption status
qpdf --show-encryption encrypted.pdf

# Decrypt (requires password)
qpdf --password=secret --decrypt encrypted.pdf decrypted.pdf
```

### Optimization and repair
```bash
# Linearize for web streaming
qpdf --linearize input.pdf optimized.pdf

# Check for structural issues
qpdf --check input.pdf

# Show PDF structure
qpdf --show-all-pages input.pdf > structure.txt
```

Install: `apt install qpdf` / `brew install qpdf`

## pdftk

```bash
# Merge
pdftk file1.pdf file2.pdf cat output merged.pdf

# Split into individual pages
pdftk input.pdf burst

# Rotate page 1 east (90 degrees clockwise)
pdftk input.pdf rotate 1east output rotated.pdf
```

Install: `apt install pdftk` / `brew install pdftk-java`

## ocrmypdf

```bash
# Basic OCR (adds invisible text layer)
ocrmypdf input.pdf output.pdf

# Deskew before OCR
ocrmypdf --deskew input.pdf output.pdf

# Force re-OCR on a PDF that already has text
ocrmypdf --force-ocr input.pdf output.pdf

# Skip pages that already have text
ocrmypdf --skip-text input.pdf output.pdf

# Specify language
ocrmypdf -l deu input.pdf output.pdf

# Multiple languages
ocrmypdf -l eng+fra input.pdf output.pdf
```

Install: `apt install ocrmypdf` / `brew install ocrmypdf`
(Also requires `tesseract` and language packs.)
