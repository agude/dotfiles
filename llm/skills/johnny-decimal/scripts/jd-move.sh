#!/usr/bin/env bash
# shellcheck shell=bash
#
# jd-move: Move a file to a Johnny Decimal location
#
# Usage:
#   jd-move document.pdf 21.10
#   jd-move document.pdf 21.10 new_name.pdf
#   jd-move --force document.pdf 21.10   # Allow overwrite

set -euo pipefail

# --- Load shared library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=jd-lib.sh
source "${SCRIPT_DIR}/jd-lib.sh"

# --- Parse arguments ---

force=false
if [[ "${1:-}" == "--force" ]]; then
    force=true
    shift
fi

if [[ $# -lt 2 ]] || [[ $# -gt 3 ]]; then
    echo "Usage: jd-move [--force] <file> <ID> [new_name]" >&2
    echo "  jd-move document.pdf 21.10" >&2
    echo "  jd-move document.pdf 21.10 renamed.pdf" >&2
    echo "  jd-move --force document.pdf 21.10  # Allow overwrite" >&2
    exit 1
fi

source_file="$1"
target_id="$2"
new_name="${3:-$(basename "$source_file")}"

# --- Validate inputs ---

# Check source file exists
if [[ ! -f "$source_file" ]]; then
    echo "Error: Source file not found: ${source_file}" >&2
    exit 1
fi

# Validate ID format
if [[ ! "$target_id" =~ ^[0-9][0-9]\.[0-9]+$ ]]; then
    echo "Error: Invalid ID format '${target_id}'. Expected XX.YY (e.g., 21.10)" >&2
    exit 1
fi

# Validate filename (if jd-validate exists)
if [[ -x "${SCRIPT_DIR}/jd-validate.sh" ]]; then
    if ! "${SCRIPT_DIR}/jd-validate.sh" "$new_name" >/dev/null 2>&1; then
        echo "Warning: Filename may not follow conventions" >&2
        "${SCRIPT_DIR}/jd-validate.sh" "$new_name" >&2 || true
    fi
fi

# Find target directory
target_dir=$(find_id_dir "$target_id") || exit 1

# Construct target path
target_path="${target_dir}/${new_name}"

# Check for existing file
if [[ -e "$target_path" ]]; then
    if [[ "$force" == true ]]; then
        echo "Warning: Overwriting existing file: ${target_path}" >&2
    else
        echo "Error: Target file already exists: ${target_path}" >&2
        echo "Use --force to overwrite" >&2
        exit 1
    fi
fi

# --- Perform the move ---

mv "$source_file" "$target_path"
echo "Moved: ${source_file} -> ${target_path}"
