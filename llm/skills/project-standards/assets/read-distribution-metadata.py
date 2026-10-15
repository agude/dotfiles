#!/usr/bin/env python3
"""Read the metadata subset required by package-check.sh."""

from __future__ import annotations

import sys
import tarfile
import zipfile


def metadata_text(archive: str) -> str:
    if archive.endswith(".whl"):
        with zipfile.ZipFile(archive) as opened:
            names = [name for name in opened.namelist() if name.endswith("/METADATA")]
            if len(names) != 1:
                raise SystemExit(f"expected one wheel METADATA file in {archive}")
            return opened.read(names[0]).decode("utf-8")
    with tarfile.open(archive, "r:gz") as opened:
        names = [name for name in opened.getnames() if name.endswith("/PKG-INFO")]
        if len(names) != 1:
            raise SystemExit(f"expected one sdist PKG-INFO file in {archive}")
        member = opened.extractfile(names[0])
        if member is None:
            raise SystemExit(f"could not read {names[0]} from {archive}")
        return member.read().decode("utf-8")


def field(text: str, name: str) -> str:
    prefix = f"{name}:"
    for line in text.splitlines():
        if line.startswith(prefix):
            return line[len(prefix) :].strip()
    raise SystemExit(f"metadata is missing {name}")


if len(sys.argv) != 3:
    raise SystemExit("usage: read-distribution-metadata.py WHEEL SDIST")

wheel_name = field(metadata_text(sys.argv[1]), "Name")
wheel_version = field(metadata_text(sys.argv[1]), "Version")
sdist_name = field(metadata_text(sys.argv[2]), "Name")
sdist_version = field(metadata_text(sys.argv[2]), "Version")
if (wheel_name, wheel_version) != (sdist_name, sdist_version):
    raise SystemExit("wheel and sdist metadata disagree")
print(f"Name={wheel_name}")
print(f"Version={wheel_version}")
print(f"Wheel-Name={wheel_name}")
print(f"Wheel-Version={wheel_version}")
