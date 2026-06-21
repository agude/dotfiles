#!/usr/bin/env bash
# shellcheck shell=bash
#
# jd-inbox: Move files to the JD inbox (00.01)
#
# Usage:
#   jd-inbox document.pdf
#   jd-inbox *.pdf
#   jd-inbox document.pdf --force
#   jd-inbox document.pdf --porcelain

set -euo pipefail

# --- Load shared library ---
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/jd-lib.sh"

# Parse common args (--porcelain, --help)
jd_parse_common_args "$@"
set -- "${JD_REMAINING_ARGS[@]}"

show_usage() {
    echo "Usage: jd-inbox [options] <source...>" >&2
    echo "  jd-inbox document.pdf                  # Move to inbox (00.01)" >&2
    echo "  jd-inbox *.pdf                          # Move multiple files" >&2
    echo "  jd-inbox --force document.pdf           # Allow overwrite" >&2
    echo "  jd-inbox --dry-run document.pdf         # Preview without moving" >&2
}

if [[ "$JD_HELP_REQUESTED" == "true" ]]; then
    show_usage
    exit 0
fi

if [[ $# -lt 1 ]]; then
    show_usage
    exit 1
fi

# Forward everything to jd-move with 00.01 as the target.
# Reconstruct --porcelain if it was set.
porcelain_flag=()
if [[ "$JD_PORCELAIN" == "true" ]]; then
    porcelain_flag=(--porcelain)
fi

exec "${SCRIPT_DIR}/jd-move.sh" "${porcelain_flag[@]}" "$@" 00.01
