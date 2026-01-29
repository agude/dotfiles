#!/usr/bin/env bash
# shellcheck shell=bash
#
# Run a command at lowest CPU and I/O priority.
# Usage: tnice COMMAND [ARGS ...]

set -e
set -u

if [[ $# -eq 0 ]]; then
    echo "Usage: tnice COMMAND [ARGS ...]" >&2
    exit 1
fi

if command -v ionice &>/dev/null; then
    nice -n 19 ionice -c 2 -n 7 "$@"
else
    nice -n 19 "$@"
fi
