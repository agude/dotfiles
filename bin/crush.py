#!/usr/bin/env python3

"""Calls pngout on the files specified on the command line.

This script runs pngout on the specified files, spawning 1.5*CPU number of
concurrent processes if it finds multiprocessing. It overwrites files with the
compressed versions without asking.

Usage:
    crush [FILES]

Exit Codes:
    0: Exit successful.
    2: pngout executable not found on the user's path.
"""

from distutils.spawn import find_executable
from math import floor
from subprocess import call
import argparse


if __name__ == "__main__":
    # Parse the list of files
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "files",
        nargs="+",
        help="one or more files to process with pngcrush",
    )
    args = parser.parse_args()

    # Try to find pngout
    if find_executable("pngout") is None:
        print("Can not find pngout.")
        exit(2)

    # Get the number of jobs to run
    NJOBS = 1
    try:
        import multiprocessing as mp
    except ImportError:
        NJOBS = 1
    else:  # Only runs when try succeeds
        floor_j = int(floor(mp.cpu_count() * 1.5))
        NJOBS = max(floor_j, 1)

    # List to store the commands to run over before passing to multiprocessing
    commands = []
    for f in args.files:
        command = (
            #"nice", "-n", "19",  # Limit processor prio
            #"ionice", "-c", "2", "-n", "7",  # Limit IO prio
            "pngout", "-y", f  # Run the compression, overwrite if asked
        )
        commands.append(command)

    # Run jobs in parallel
    if NJOBS > 1:
        pool = mp.Pool(processes=NJOBS)
        pool.map(call, commands)  # No return values so we don't care about them
        pool.close()  # No more tasks to add
        pool.join()  # Wait for jobs to finish
    else:
        for com in commands:
            call(com)

    # Exit ok
    exit(0)
