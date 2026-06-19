"""Tests for PDF skill scripts.

Run via: uv run tests/run.py [-v] [-k pattern]

All tests generate fixture PDFs on the fly — no external test data needed.
OCR tests are skipped when tesseract is not installed.
"""

import json
import shutil
import subprocess
import sys
from io import BytesIO
from pathlib import Path

import pytest
from pypdf import PdfReader
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"

HAS_TESSERACT = shutil.which("tesseract") is not None


def run(name: str, *args: str) -> subprocess.CompletedProcess:
    """Run a skill script with the current interpreter."""
    return subprocess.run(
        [sys.executable, str(SCRIPTS / name), *args],
        capture_output=True, text=True,
    )


def make_pdf(
    tmp_path: Path, text: str = "Hello World",
    pages: int = 1, name: str = "test.pdf",
) -> Path:
    """Create a simple born-digital PDF."""
    path = tmp_path / name
    buf = BytesIO()
    c = canvas.Canvas(buf, pagesize=letter)
    _, h = letter
    for i in range(pages):
        c.drawString(72, h - 72, f"{text} - Page {i + 1}")
        if i < pages - 1:
            c.showPage()
    c.save()
    path.write_bytes(buf.getvalue())
    return path


def make_fillable_pdf(tmp_path: Path, name: str = "fillable.pdf") -> Path:
    """Create a PDF with a fillable text field."""
    path = tmp_path / name
    buf = BytesIO()
    c = canvas.Canvas(buf, pagesize=letter)
    _, h = letter
    c.drawString(72, h - 72, "Test Form")
    c.acroForm.textfield(
        name="full_name", x=100, y=700, width=200, height=20,
    )
    c.save()
    path.write_bytes(buf.getvalue())
    return path


# ---- extract_text.py ----


class TestExtractText:
    def test_basic(self, tmp_path):
        pdf = make_pdf(tmp_path, "Sample Text")
        r = run("extract_text.py", str(pdf))
        assert r.returncode == 0
        assert "Sample Text" in r.stdout

    def test_page_range(self, tmp_path):
        pdf = make_pdf(tmp_path, "Content", pages=3)
        r = run("extract_text.py", "--pages", "1,3", str(pdf))
        assert r.returncode == 0
        assert "Page 1" in r.stdout
        assert "Page 3" in r.stdout
        assert "Page 2" not in r.stdout

    def test_porcelain(self, tmp_path):
        pdf = make_pdf(tmp_path, "JSONL Test")
        r = run("extract_text.py", "--porcelain", str(pdf))
        assert r.returncode == 0
        data = json.loads(r.stdout.strip())
        assert "JSONL Test" in data["text"]

    def test_batch_headers(self, tmp_path):
        a = make_pdf(tmp_path, "AAA", name="a.pdf")
        b = make_pdf(tmp_path, "BBB", name="b.pdf")
        r = run("extract_text.py", str(a), str(b))
        assert r.returncode == 0
        assert f"=== {a} ===" in r.stdout
        assert f"=== {b} ===" in r.stdout


# ---- merge.py ----


class TestMerge:
    def test_basic(self, tmp_path):
        a = make_pdf(tmp_path, "First", pages=2, name="a.pdf")
        b = make_pdf(tmp_path, "Second", pages=1, name="b.pdf")
        out = tmp_path / "merged.pdf"
        r = run("merge.py", "-o", str(out), str(a), str(b))
        assert r.returncode == 0
        assert len(PdfReader(out).pages) == 3


# ---- split.py ----


class TestSplit:
    def test_per_page(self, tmp_path):
        pdf = make_pdf(tmp_path, "Split", pages=3)
        out_dir = tmp_path / "pages"
        r = run("split.py", str(pdf), "-d", str(out_dir))
        assert r.returncode == 0
        assert len(list(out_dir.glob("*.pdf"))) == 3

    def test_page_range(self, tmp_path):
        pdf = make_pdf(tmp_path, "Range", pages=5)
        out = tmp_path / "subset.pdf"
        r = run("split.py", str(pdf), "-o", str(out), "--pages", "2-4")
        assert r.returncode == 0
        assert len(PdfReader(out).pages) == 3

    def test_legacy_dir(self, tmp_path):
        pdf = make_pdf(tmp_path, "Legacy")
        out_dir = tmp_path / "legacy_out"
        r = run("split.py", str(pdf), str(out_dir))
        assert r.returncode == 0
        assert out_dir.is_dir()

    def test_batch(self, tmp_path):
        a = make_pdf(tmp_path, "A", pages=2, name="a.pdf")
        b = make_pdf(tmp_path, "B", pages=3, name="b.pdf")
        out_dir = tmp_path / "batch"
        r = run("split.py", "-d", str(out_dir), str(a), str(b))
        assert r.returncode == 0
        assert len(list((out_dir / "a").glob("*.pdf"))) == 2
        assert len(list((out_dir / "b").glob("*.pdf"))) == 3

    def test_porcelain(self, tmp_path):
        pdf = make_pdf(tmp_path, pages=2)
        out_dir = tmp_path / "p"
        r = run("split.py", str(pdf), "-d", str(out_dir), "--porcelain")
        assert r.returncode == 0
        assert r.stdout.startswith("ok\t")


# ---- rotate.py ----


class TestRotate:
    def test_basic(self, tmp_path):
        pdf = make_pdf(tmp_path, "Rotate")
        out = tmp_path / "rotated.pdf"
        r = run("rotate.py", str(pdf), "-o", str(out), "--angle", "90")
        assert r.returncode == 0
        page = PdfReader(out).pages[0]
        assert page.get("/Rotate") == 90


# ---- metadata.py ----


class TestMetadata:
    def test_basic(self, tmp_path):
        pdf = make_pdf(tmp_path)
        r = run("metadata.py", str(pdf))
        assert r.returncode == 0
        assert "Pages: 1" in r.stdout

    def test_json_output(self, tmp_path):
        pdf = make_pdf(tmp_path)
        r = run("metadata.py", "--json", str(pdf))
        assert r.returncode == 0
        data = json.loads(r.stdout)
        assert data["pages"] == 1

    def test_porcelain(self, tmp_path):
        pdf = make_pdf(tmp_path)
        r = run("metadata.py", "--porcelain", str(pdf))
        assert r.returncode == 0
        data = json.loads(r.stdout.strip())
        assert data["pages"] == 1


# ---- encrypt.py / decrypt.py ----


class TestEncryptDecrypt:
    def test_encrypt_basic(self, tmp_path):
        pdf = make_pdf(tmp_path, "Secret")
        out = tmp_path / "enc.pdf"
        r = run("encrypt.py", str(pdf), "-o", str(out), "--user-password", "pw")
        assert r.returncode == 0
        assert PdfReader(out).is_encrypted

    def test_round_trip(self, tmp_path):
        pdf = make_pdf(tmp_path, "Round Trip")
        enc = tmp_path / "enc.pdf"
        dec = tmp_path / "dec.pdf"
        run("encrypt.py", str(pdf), "-o", str(enc), "--user-password", "pw")
        r = run("decrypt.py", str(enc), "-o", str(dec), "--password", "pw")
        assert r.returncode == 0
        reader = PdfReader(dec)
        assert not reader.is_encrypted
        assert "Round Trip" in reader.pages[0].extract_text()

    def test_decrypt_not_encrypted(self, tmp_path):
        pdf = make_pdf(tmp_path, "Plain")
        out = tmp_path / "dec.pdf"
        r = run("decrypt.py", str(pdf), "-o", str(out), "--password", "any")
        assert r.returncode == 0
        assert "not encrypted" in r.stdout.lower() or "skip" in r.stdout.lower()

    def test_decrypt_wrong_password(self, tmp_path):
        pdf = make_pdf(tmp_path, "Secret")
        enc = tmp_path / "enc.pdf"
        dec = tmp_path / "dec.pdf"
        run("encrypt.py", str(pdf), "-o", str(enc), "--user-password", "right")
        r = run("decrypt.py", str(enc), "-o", str(dec), "--password", "wrong")
        assert r.returncode != 0

    def test_encrypt_batch_inplace(self, tmp_path):
        a = make_pdf(tmp_path, "A", name="a.pdf")
        b = make_pdf(tmp_path, "B", name="b.pdf")
        r = run("encrypt.py", "-i", "--user-password", "pw", str(a), str(b))
        assert r.returncode == 0
        assert PdfReader(a).is_encrypted
        assert PdfReader(b).is_encrypted

    def test_encrypt_batch_output_dir(self, tmp_path):
        a = make_pdf(tmp_path, "A", name="a.pdf")
        b = make_pdf(tmp_path, "B", name="b.pdf")
        out_dir = tmp_path / "encrypted"
        r = run(
            "encrypt.py", "-d", str(out_dir),
            "--user-password", "pw", str(a), str(b),
        )
        assert r.returncode == 0
        assert PdfReader(out_dir / "a.pdf").is_encrypted
        assert PdfReader(out_dir / "b.pdf").is_encrypted

    def test_encrypt_legacy(self, tmp_path):
        pdf = make_pdf(tmp_path, "Legacy")
        out = tmp_path / "enc.pdf"
        r = run("encrypt.py", str(pdf), str(out), "--user-password", "pw")
        assert r.returncode == 0
        assert "legacy" in r.stderr.lower()
        assert PdfReader(out).is_encrypted

    def test_encrypt_porcelain(self, tmp_path):
        pdf = make_pdf(tmp_path)
        out = tmp_path / "enc.pdf"
        r = run(
            "encrypt.py", str(pdf), "-o", str(out),
            "--user-password", "pw", "--porcelain",
        )
        assert r.returncode == 0
        assert r.stdout.startswith("ok\t")

    def test_decrypt_batch_inplace(self, tmp_path):
        a = make_pdf(tmp_path, "A", name="a.pdf")
        b = make_pdf(tmp_path, "B", name="b.pdf")
        run("encrypt.py", "-i", "--user-password", "pw", str(a), str(b))
        r = run("decrypt.py", "-i", "--password", "pw", str(a), str(b))
        assert r.returncode == 0
        assert not PdfReader(a).is_encrypted
        assert not PdfReader(b).is_encrypted


# ---- check_fields.py ----


class TestCheckFields:
    def test_has_fields(self, tmp_path):
        pdf = make_fillable_pdf(tmp_path)
        r = run("check_fields.py", str(pdf))
        assert r.returncode == 0
        assert "fillable form fields" in r.stdout

    def test_no_fields(self, tmp_path):
        pdf = make_pdf(tmp_path)
        r = run("check_fields.py", str(pdf))
        assert r.returncode == 1
        assert "does not have" in r.stdout

    def test_porcelain(self, tmp_path):
        pdf = make_fillable_pdf(tmp_path)
        r = run("check_fields.py", "--porcelain", str(pdf))
        assert r.returncode == 0
        data = json.loads(r.stdout.strip())
        assert data["has_fields"] is True
        assert data["field_count"] > 0

    def test_batch_mixed(self, tmp_path):
        fillable = make_fillable_pdf(tmp_path, "fill.pdf")
        plain = make_pdf(tmp_path, name="plain.pdf")
        r = run("check_fields.py", str(fillable), str(plain))
        assert r.returncode == 0  # at least one has fields


# ---- pdf_to_images.py ----


class TestPdfToImages:
    def test_basic(self, tmp_path):
        pdf = make_pdf(tmp_path, pages=2)
        out_dir = tmp_path / "images"
        r = run("pdf_to_images.py", str(pdf), "-d", str(out_dir))
        assert r.returncode == 0
        assert len(list(out_dir.glob("*.png"))) == 2

    def test_page_range(self, tmp_path):
        pdf = make_pdf(tmp_path, pages=5)
        out_dir = tmp_path / "images"
        r = run("pdf_to_images.py", str(pdf), "-d", str(out_dir), "--pages", "1,3")
        assert r.returncode == 0
        assert len(list(out_dir.glob("*.png"))) == 2

    def test_max_dim(self, tmp_path):
        pdf = make_pdf(tmp_path)
        out_dir = tmp_path / "small"
        r = run(
            "pdf_to_images.py", str(pdf), "-d", str(out_dir),
            "--max-dim", "100",
        )
        assert r.returncode == 0
        from PIL import Image
        img = Image.open(out_dir / "page_1.png")
        assert max(img.size) <= 100

    def test_legacy(self, tmp_path):
        pdf = make_pdf(tmp_path)
        out_dir = tmp_path / "imgs"
        r = run("pdf_to_images.py", str(pdf), str(out_dir))
        assert r.returncode == 0
        assert out_dir.is_dir()
        assert len(list(out_dir.glob("*.png"))) == 1

    def test_batch(self, tmp_path):
        a = make_pdf(tmp_path, pages=1, name="a.pdf")
        b = make_pdf(tmp_path, pages=2, name="b.pdf")
        out_dir = tmp_path / "batch"
        r = run("pdf_to_images.py", "-d", str(out_dir), str(a), str(b))
        assert r.returncode == 0
        assert len(list((out_dir / "a").glob("*.png"))) == 1
        assert len(list((out_dir / "b").glob("*.png"))) == 2

    def test_porcelain(self, tmp_path):
        pdf = make_pdf(tmp_path)
        out_dir = tmp_path / "p"
        r = run("pdf_to_images.py", str(pdf), "-d", str(out_dir), "--porcelain")
        assert r.returncode == 0
        assert r.stdout.startswith("ok\t")


# ---- add_text_layer.py ----


class TestAddTextLayer:
    def test_basic(self, tmp_path):
        pdf = make_pdf(tmp_path)
        out = tmp_path / "layered.pdf"
        r = run("add_text_layer.py", str(pdf), str(out), "Invisible text")
        assert r.returncode == 0
        assert out.exists()
        assert len(PdfReader(out).pages) == 1

    def test_from_file(self, tmp_path):
        pdf = make_pdf(tmp_path)
        txt = tmp_path / "transcript.txt"
        txt.write_text("From file text")
        out = tmp_path / "layered.pdf"
        r = run("add_text_layer.py", str(pdf), str(out), "--file", str(txt))
        assert r.returncode == 0
        assert out.exists()

    def test_in_place(self, tmp_path):
        pdf = make_pdf(tmp_path)
        r = run("add_text_layer.py", "-i", str(pdf), "Added text")
        assert r.returncode == 0
        assert pdf.stat().st_size > 0


# ---- OCR scripts (tesseract required) ----


@pytest.mark.skipif(not HAS_TESSERACT, reason="tesseract not installed")
class TestOCR:
    def test_ocr_text(self, tmp_path):
        pdf = make_pdf(tmp_path, "OCR Test Text")
        r = run("ocr_text.py", str(pdf))
        assert r.returncode == 0

    def test_ocr_text_porcelain(self, tmp_path):
        pdf = make_pdf(tmp_path, "Porcelain OCR")
        r = run("ocr_text.py", "--porcelain", str(pdf))
        assert r.returncode == 0
        data = json.loads(r.stdout.strip())
        assert "text" in data

    def test_ocr_pdf(self, tmp_path):
        pdf = make_pdf(tmp_path, "OCR PDF")
        out = tmp_path / "ocr_out.pdf"
        r = run("ocr_pdf.py", str(pdf), "-o", str(out))
        assert r.returncode == 0

    def test_detect_orientation(self, tmp_path):
        pdf = make_pdf(tmp_path, "Orientation " * 50)
        r = run("detect_orientation.py", str(pdf))
        assert r.returncode == 0

    def test_detect_orientation_porcelain(self, tmp_path):
        pdf = make_pdf(tmp_path, "Orientation")
        r = run("detect_orientation.py", "--porcelain", str(pdf))
        assert r.returncode == 0
        data = json.loads(r.stdout.strip())
        assert "pages" in data


# ---- Form filling scripts ----


class TestFormFilling:
    def test_extract_fields(self, tmp_path):
        pdf = make_fillable_pdf(tmp_path)
        out = tmp_path / "fields.json"
        r = run("extract_fields.py", str(pdf), str(out))
        assert r.returncode == 0
        fields = json.loads(out.read_text())
        assert len(fields) > 0
        names = [f["field_id"] for f in fields]
        assert any("name" in n.lower() for n in names)

    def test_fill_fields(self, tmp_path):
        pdf = make_fillable_pdf(tmp_path)
        fields_file = tmp_path / "fields.json"
        run("extract_fields.py", str(pdf), str(fields_file))
        fields = json.loads(fields_file.read_text())
        text_fields = [f for f in fields if f.get("type") == "text"]
        if not text_fields:
            pytest.skip("No text fields found in test PDF")
        values = [{"field_id": text_fields[0]["field_id"], "value": "Jane Doe"}]
        values_file = tmp_path / "values.json"
        values_file.write_text(json.dumps(values))
        out = tmp_path / "filled.pdf"
        r = run("fill_fields.py", str(pdf), str(values_file), str(out))
        assert r.returncode == 0
        assert out.exists()

    def test_extract_structure(self, tmp_path):
        pdf = make_pdf(tmp_path, "Structure Test")
        out = tmp_path / "structure.json"
        r = run("extract_structure.py", str(pdf), str(out))
        assert r.returncode == 0
        structure = json.loads(out.read_text())
        assert len(structure["pages"]) == 1
        assert len(structure["labels"]) > 0


# ---- Validation scripts ----


class TestValidation:
    def test_check_boxes_valid(self, tmp_path):
        fields_data = {
            "pages": [{"page_number": 1, "pdf_width": 612, "pdf_height": 792}],
            "form_fields": [
                {
                    "page_number": 1,
                    "description": "Name",
                    "field_label": "Name",
                    "label_bounding_box": [10, 10, 50, 25],
                    "entry_bounding_box": [55, 10, 200, 25],
                    "entry_text": {"text": "Test", "font_size": 10},
                },
                {
                    "page_number": 1,
                    "description": "Email",
                    "field_label": "Email",
                    "label_bounding_box": [10, 30, 50, 45],
                    "entry_bounding_box": [55, 30, 200, 45],
                    "entry_text": {"text": "test@example.com", "font_size": 10},
                },
            ],
        }
        fields_file = tmp_path / "fields.json"
        fields_file.write_text(json.dumps(fields_data))
        r = run("check_boxes.py", str(fields_file))
        assert r.returncode == 0
        assert "OK" in r.stdout

    def test_check_boxes_overlap(self, tmp_path):
        fields_data = {
            "pages": [{"page_number": 1, "pdf_width": 612, "pdf_height": 792}],
            "form_fields": [
                {
                    "page_number": 1,
                    "description": "Field A",
                    "field_label": "A",
                    "label_bounding_box": [10, 10, 50, 25],
                    "entry_bounding_box": [55, 10, 200, 25],
                },
                {
                    "page_number": 1,
                    "description": "Field B",
                    "field_label": "B",
                    "label_bounding_box": [40, 15, 80, 30],
                    "entry_bounding_box": [85, 15, 200, 30],
                },
            ],
        }
        fields_file = tmp_path / "fields.json"
        fields_file.write_text(json.dumps(fields_data))
        r = run("check_boxes.py", str(fields_file))
        assert r.returncode == 1
        assert "FAIL" in r.stdout

    def test_validation_image(self, tmp_path):
        pdf = make_pdf(tmp_path)
        img_dir = tmp_path / "imgs"
        run("pdf_to_images.py", str(pdf), "-d", str(img_dir))
        page_img = img_dir / "page_1.png"
        assert page_img.exists()
        fields_data = {
            "pages": [{"page_number": 1, "image_width": 100, "image_height": 100}],
            "form_fields": [
                {
                    "page_number": 1,
                    "description": "Test",
                    "field_label": "Test",
                    "label_bounding_box": [10, 10, 50, 25],
                    "entry_bounding_box": [55, 10, 90, 25],
                },
            ],
        }
        fields_file = tmp_path / "fields.json"
        fields_file.write_text(json.dumps(fields_data))
        out_img = tmp_path / "debug.png"
        r = run(
            "validation_image.py", "--page", "1",
            str(fields_file), str(page_img), str(out_img),
        )
        assert r.returncode == 0
        assert out_img.exists()
