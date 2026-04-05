# Python PDF Libraries Reference

Recipes and tips for PDF processing with Python. Install any library via
`uv run --with <package>` or add to a PEP 723 script header.

## pypdf — Basic Operations

### Read and extract text
```python
from pypdf import PdfReader

reader = PdfReader("document.pdf")
print(f"Pages: {len(reader.pages)}")

for page in reader.pages:
    print(page.extract_text())
```

### Merge PDFs
```python
from pypdf import PdfWriter, PdfReader

writer = PdfWriter()
for path in ["a.pdf", "b.pdf", "c.pdf"]:
    for page in PdfReader(path).pages:
        writer.add_page(page)

with open("merged.pdf", "wb") as f:
    writer.write(f)
```

### Split PDF
```python
reader = PdfReader("input.pdf")
for i, page in enumerate(reader.pages):
    writer = PdfWriter()
    writer.add_page(page)
    with open(f"page_{i + 1}.pdf", "wb") as f:
        writer.write(f)
```

### Rotate pages
```python
reader = PdfReader("input.pdf")
writer = PdfWriter()
page = reader.pages[0]
page.rotate(90)  # clockwise
writer.add_page(page)
with open("rotated.pdf", "wb") as f:
    writer.write(f)
```

### Metadata
```python
reader = PdfReader("document.pdf")
meta = reader.metadata
print(f"Title: {meta.title}, Author: {meta.author}")
```

### Watermark
```python
from pypdf import PdfReader, PdfWriter

watermark = PdfReader("watermark.pdf").pages[0]
reader = PdfReader("document.pdf")
writer = PdfWriter()

for page in reader.pages:
    page.merge_page(watermark)
    writer.add_page(page)

with open("watermarked.pdf", "wb") as f:
    writer.write(f)
```

### Password protection
```python
from pypdf import PdfReader, PdfWriter

reader = PdfReader("input.pdf")
writer = PdfWriter()
for page in reader.pages:
    writer.add_page(page)

writer.encrypt("user_password", "owner_password")
with open("encrypted.pdf", "wb") as f:
    writer.write(f)
```

### Crop pages
```python
reader = PdfReader("input.pdf")
writer = PdfWriter()
page = reader.pages[0]
# Coordinates in points: left, bottom, right, top
page.mediabox.left = 50
page.mediabox.bottom = 50
page.mediabox.right = 550
page.mediabox.top = 750
writer.add_page(page)
with open("cropped.pdf", "wb") as f:
    writer.write(f)
```

## pdfplumber — Text and Table Extraction

### Extract text with layout
```python
import pdfplumber

with pdfplumber.open("document.pdf") as pdf:
    for page in pdf.pages:
        print(page.extract_text())
```

### Extract tables
```python
import pdfplumber

with pdfplumber.open("document.pdf") as pdf:
    for page in pdf.pages:
        for table in page.extract_tables():
            for row in table:
                print(row)
```

### Tables to pandas DataFrame
```python
import pdfplumber
import pandas as pd

with pdfplumber.open("document.pdf") as pdf:
    all_tables = []
    for page in pdf.pages:
        for table in page.extract_tables():
            if table:
                df = pd.DataFrame(table[1:], columns=table[0])
                all_tables.append(df)
    if all_tables:
        combined = pd.concat(all_tables, ignore_index=True)
```

### Custom table extraction settings
```python
table_settings = {
    "vertical_strategy": "lines",
    "horizontal_strategy": "lines",
    "snap_tolerance": 3,
    "intersection_tolerance": 15,
}
tables = page.extract_tables(table_settings)
```

### Text with coordinates
```python
with pdfplumber.open("document.pdf") as pdf:
    page = pdf.pages[0]
    for char in page.chars[:10]:
        print(f"'{char['text']}' at ({char['x0']:.1f}, {char['top']:.1f})")

    # Extract text within a bounding box (left, top, right, bottom)
    region = page.within_bbox((100, 100, 400, 200))
    print(region.extract_text())
```

### Debug layout
```python
with pdfplumber.open("document.pdf") as pdf:
    img = pdf.pages[0].to_image(resolution=150)
    img.save("debug_layout.png")
```

## reportlab — PDF Creation

### Basic PDF
```python
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas

c = canvas.Canvas("hello.pdf", pagesize=letter)
width, height = letter
c.drawString(100, height - 100, "Hello World!")
c.line(100, height - 120, 400, height - 120)
c.save()
```

### Multi-page with Platypus
```python
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak
from reportlab.lib.styles import getSampleStyleSheet

doc = SimpleDocTemplate("report.pdf", pagesize=letter)
styles = getSampleStyleSheet()
story = [
    Paragraph("Report Title", styles["Title"]),
    Spacer(1, 12),
    Paragraph("Body text. " * 20, styles["Normal"]),
    PageBreak(),
    Paragraph("Page 2", styles["Heading1"]),
]
doc.build(story)
```

### Tables with styling
```python
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle
from reportlab.lib import colors

data = [
    ["Product", "Q1", "Q2"],
    ["Widgets", "120", "135"],
    ["Gadgets", "85", "92"],
]

table = Table(data)
table.setStyle(TableStyle([
    ("BACKGROUND", (0, 0), (-1, 0), colors.grey),
    ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
    ("ALIGN", (0, 0), (-1, -1), "CENTER"),
    ("GRID", (0, 0), (-1, -1), 1, colors.black),
]))
```

### Subscripts and superscripts

**Never use Unicode subscript/superscript characters** (e.g.,
`\u2080`-`\u2089`, `\u2070`-`\u2079`) in reportlab. Built-in fonts lack
these glyphs — they render as solid black boxes.

Use XML tags in Paragraph objects:
```python
from reportlab.platypus import Paragraph
from reportlab.lib.styles import getSampleStyleSheet
styles = getSampleStyleSheet()

chemical = Paragraph("H<sub>2</sub>O", styles["Normal"])
squared = Paragraph("x<super>2</super>", styles["Normal"])
```

For canvas-drawn text, manually adjust font size and y-position.

## pypdfium2 — Rendering and Text

### Render pages to images
```python
import pypdfium2 as pdfium

pdf = pdfium.PdfDocument("document.pdf")
for i, page in enumerate(pdf):
    bitmap = page.render(scale=2.0)
    img = bitmap.to_pil()
    img.save(f"page_{i + 1}.png", "PNG")
```

### Extract text
```python
import pypdfium2 as pdfium

pdf = pdfium.PdfDocument("document.pdf")
for i, page in enumerate(pdf):
    text = page.get_text()
    print(f"Page {i + 1}: {len(text)} chars")
```

## Memory Management for Large PDFs

```python
def process_in_chunks(pdf_path, chunk_size=10):
    reader = PdfReader(pdf_path)
    total = len(reader.pages)
    for start in range(0, total, chunk_size):
        end = min(start + chunk_size, total)
        writer = PdfWriter()
        for i in range(start, end):
            writer.add_page(reader.pages[i])
        with open(f"chunk_{start // chunk_size}.pdf", "wb") as f:
            writer.write(f)
```
