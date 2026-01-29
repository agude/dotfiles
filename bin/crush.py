#!/usr/bin/env python3

"""Compress PNG files in parallel using pngout.

Runs pngout on the specified files, spawning 1.5×CPU concurrent workers.
Overwrites files in place without prompting.

Usage:
    crush FILE ...

Exit Codes:
    0: All files compressed successfully.
    1: One or more files failed to compress.
    2: pngout executable not found.
"""

import argparse
import shutil
import subprocess
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from math import floor
from os import cpu_count


def compress(path: str) -> subprocess.CompletedProcess:
    return subprocess.run(["pngout", "-y", path])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compress PNG files with pngout.")
    parser.add_argument("files", nargs="+", help="one or more PNG files to compress")
    args = parser.parse_args()

    if shutil.which("pngout") is None:
        print("Error: cannot find pngout.", file=sys.stderr)
        sys.exit(2)

    max_workers = max(floor((cpu_count() or 1) * 1.5), 1)
    failures = 0

    with ProcessPoolExecutor(max_workers=max_workers) as pool:
        futures = {pool.submit(compress, f): f for f in args.files}
        for future in as_completed(futures):
            path = futures[future]
            rc = future.result().returncode
            if rc != 0:
                print(f"pngout failed on {path} (exit {rc})", file=sys.stderr)
                failures += 1

    sys.exit(1 if failures else 0)
