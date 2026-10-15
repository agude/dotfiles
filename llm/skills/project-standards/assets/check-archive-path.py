#!/usr/bin/env python3
"""Assert that a relative path is present in a wheel or source archive."""

from __future__ import annotations

import sys
import tarfile
import zipfile

if len(sys.argv) != 3:
    raise SystemExit("usage: check-archive-path.py ARCHIVE RELATIVE-PATH")

archive, expected = sys.argv[1:]
if archive.endswith(".whl"):
    with zipfile.ZipFile(archive) as opened:
        names = opened.namelist()
else:
    with tarfile.open(archive, "r:gz") as opened:
        names = opened.getnames()

if not any(name == expected or name.endswith(f"/{expected}") for name in names):
    raise SystemExit(f"{archive} is missing {expected}")
