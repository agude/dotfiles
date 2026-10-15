#!/usr/bin/env python3
"""Assert that a relative path is present in a wheel."""

from __future__ import annotations

import sys
import zipfile


if len(sys.argv) != 3:
    raise SystemExit("usage: check-wheel-path.py WHEEL RELATIVE-PATH")

wheel, expected = sys.argv[1:]
with zipfile.ZipFile(wheel) as opened:
    if expected not in opened.namelist():
        raise SystemExit(f"wheel is missing {expected}")
