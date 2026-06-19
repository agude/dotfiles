# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "pytest>=8.0",
#     "pypdf>=4.0",
#     "pdfplumber>=0.10",
#     "pypdfium2>=4.0",
#     "Pillow>=10.0",
#     "reportlab>=4.0",
#     "pytesseract>=0.3",
#     "ocrmypdf>=15.0",
# ]
# ///
"""Run the PDF skill test suite.

Usage:
    uv run tests/run.py              # run all tests
    uv run tests/run.py -v           # verbose output
    uv run tests/run.py -k merge     # run tests matching 'merge'
    uv run tests/run.py --tb=short   # shorter tracebacks
"""
import sys
from pathlib import Path

import pytest

sys.exit(pytest.main([str(Path(__file__).parent), *sys.argv[1:]]))
