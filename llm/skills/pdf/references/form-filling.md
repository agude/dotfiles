# Form Filling Reference

Detailed workflows for filling PDF forms. See SKILL.md for the summary.

## Fillable Form Field Types

The `extract_fields.py` script outputs JSON with these field types:

### Text fields
```json
{
  "field_id": "last_name",
  "type": "text",
  "page": 1,
  "rect": [100, 500, 300, 520]
}
```
Set `"value"` to any string.

### Checkboxes
```json
{
  "field_id": "agree_terms",
  "type": "checkbox",
  "page": 1,
  "checked_value": "/Yes",
  "unchecked_value": "/Off"
}
```
Set `"value"` to `checked_value` or `unchecked_value` exactly.

### Radio groups
```json
{
  "field_id": "gender",
  "type": "radio_group",
  "page": 1,
  "radio_options": [
    {"value": "/Male", "rect": [100, 400, 112, 412]},
    {"value": "/Female", "rect": [150, 400, 162, 412]}
  ]
}
```
Set `"value"` to one of the `radio_options` values.

### Choice fields (dropdowns)
```json
{
  "field_id": "state",
  "type": "choice",
  "page": 1,
  "choice_options": [
    {"value": "CA", "text": "California"},
    {"value": "NY", "text": "New York"}
  ]
}
```
Set `"value"` to one of the `choice_options` values.

## Non-Fillable Form: Coordinate Systems

Non-fillable forms use `fields.json` with a different format than fillable
forms. Two coordinate systems are supported:

### PDF coordinates
- Use `pdf_width` and `pdf_height` in the pages array
- y=0 is at the **top** of the page (pdfplumber convention)
- Coordinates come directly from `extract_structure.py` output

### Image coordinates
- Use `image_width` and `image_height` in the pages array
- y=0 is at the **top-left** of the image
- Coordinates are pixel positions from page images

The `fill_annotations.py` script auto-detects the system from the pages array
and handles conversion internally.

## Non-Fillable Form: fields.json Format

```json
{
  "pages": [
    {"page_number": 1, "pdf_width": 612, "pdf_height": 792}
  ],
  "form_fields": [
    {
      "page_number": 1,
      "description": "Last name entry field",
      "field_label": "Last Name",
      "label_bounding_box": [43, 63, 87, 73],
      "entry_bounding_box": [92, 63, 260, 79],
      "entry_text": {"text": "Smith", "font_size": 10}
    },
    {
      "page_number": 1,
      "description": "US Citizen Yes checkbox",
      "field_label": "Yes",
      "label_bounding_box": [260, 200, 280, 210],
      "entry_bounding_box": [285, 197, 292, 205],
      "entry_text": {"text": "X"}
    }
  ]
}
```

All bounding boxes are `[x0, y0, x1, y1]` (left, top, right, bottom).

### entry_text options

| Key | Default | Description |
|-----|---------|-------------|
| `text` | (required) | The text to render |
| `font_size` | 14 | Font size in points |
| `font` | Arial | Font name |
| `font_color` | 000000 | Hex color (no # prefix) |

## Approach A: Structure-Based Coordinates (Preferred)

Use when `extract_structure.py` finds meaningful text labels.

### Step 1: Extract structure

```bash
uv run scripts/extract_structure.py input.pdf structure.json
```

### Step 2: Analyze the output

Read `structure.json` and identify:

1. **Label groups**: Adjacent text elements forming one label (e.g., "Last" +
   "Name" are separate words at similar y-coordinates)
2. **Row structure**: Labels with similar `top` values share a row
3. **Field columns**: Entry areas start after the label ends
   (`entry_x0 = label_x1 + 5`)
4. **Checkboxes**: Use the checkbox coordinates directly

### Step 3: Build fields.json

For text fields:
- `entry_x0` = label `x1` + small gap (5 points)
- `entry_x1` = next label's `x0`, or end of row
- `entry_top` = same as label `top`
- `entry_bottom` = row boundary line below, or `label_bottom + row_height`

For checkboxes:
- Use the checkbox rectangle from `structure.json` directly as the
  `entry_bounding_box`

Use `pdf_width`/`pdf_height` in the pages array (not image dimensions).

### Step 4: Validate

```bash
uv run scripts/check_boxes.py fields.json
```

Fix any overlaps or sizing errors before filling.

### Step 5: Fill

```bash
uv run scripts/fill_annotations.py input.pdf fields.json output.pdf
```

## Approach B: Visual Estimation (Fallback)

Use when the PDF is scanned/image-based and structure extraction finds no
usable text labels.

### Step 1: Convert to images

```bash
uv run scripts/pdf_to_images.py input.pdf images/
```

### Step 2: Rough estimation

Examine each page image. For each form field, note approximate pixel
coordinates of the label and entry area.

### Step 3: Zoom refinement (critical for accuracy)

For each field, crop a region around the estimated position:

```bash
magick images/page_1.png -crop 300x80+50+120 +repage crops/name_field.png
```

If `magick` is unavailable, try `convert` with the same arguments.

Examine the crop to find precise boundaries, then convert back to full-image
coordinates:

```
full_x = crop_x + crop_offset_x
full_y = crop_y + crop_offset_y
```

### Step 4: Build fields.json

Use `image_width`/`image_height` in the pages array:

```json
{
  "pages": [
    {"page_number": 1, "image_width": 1700, "image_height": 2200}
  ],
  "form_fields": [...]
}
```

### Step 5: Validate, fill, verify

Same as Approach A steps 4-5.

## Approach C: Hybrid

When structure extraction works for most fields but misses some (e.g.,
circular checkboxes, unusual form controls):

1. Use Approach A for fields detected in `structure.json`
2. Use Approach B's zoom refinement for missing fields
3. Convert image coordinates to PDF coordinates:
   ```
   pdf_x = image_x * (pdf_width / image_width)
   pdf_y = image_y * (pdf_height / image_height)
   ```
4. Use a single coordinate system in `fields.json` — convert everything to
   PDF coordinates with `pdf_width`/`pdf_height`

## Verification

Always verify the output:

```bash
uv run scripts/pdf_to_images.py output.pdf verify/
```

If text is mispositioned:
- **Approach A**: Confirm you used PDF coordinates from `structure.json`
  with `pdf_width`/`pdf_height`
- **Approach B**: Confirm image dimensions match and pixel coordinates are
  accurate
- **Hybrid**: Check coordinate conversions for visually-estimated fields

Use `validation_image.py` to overlay boxes on the original page image before
filling, to catch errors early:

```bash
uv run scripts/validation_image.py --page 1 fields.json images/page_1.png debug.png
```
