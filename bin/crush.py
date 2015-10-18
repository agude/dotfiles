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

from subprocess import call  # Access external programs
from sys import argv
from os.path import isfile

# Multiprocessing does not exist in some older versions of python
HasMP = True
NJOBS = 1
try:
    import multiprocessing as mp
except ImportError:
    HasMP = False
else:  # Only runs when try succeeds
    from math import floor
    if HasMP:
        NJOBS = int(floor(mp.cpu_count() * 1.5))

# Try to find pngout
from distutils.spawn import find_executable
if find_executable("pngout") is None:
    print("Can not find pngout.")
    exit(2)

# Input files, 1: slicing removes this programs name from the list
inputfiles = [f for f in argv if isfile(f)][1:]

# List to store the commands to run over before passing to multiprocessing
commands = []
for f in inputfiles:
    command = (
            #"nice", "-n", "19",  # Limit processor prio
            #"ionice", "-c", "2", "-n", "7",  # Limit IO prio
            "pngout", "-y", f  # Run the compression, overwrite if asked
            )
    commands.append(command)

# Run jobs in parallel
if HasMP and NJOBS > 1:
    pool = mp.Pool(processes=NJOBS)
    pool.map(call, commands)  # No return values so we don't care about them
    pool.close()  # No more tasks to add
    pool.join()  # Wait for jobs to finish
else:
    for com in commands:
        call(com)

# Exit ok
exit(0)
