#!/usr/bin/env bash
# shellcheck shell=bash
#
# jd-read: Read notes for a Johnny Decimal ID
#
# Notes are stored in the JDex as individual markdown files per ID.
#
# Usage:
#   jd-read 31.14    # Display notes for ID 31.14
#   jd-read 21.10    # Display notes for ID 21.10

set -euo pipefail

# --- Load shared library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=jd-lib.sh
source "${SCRIPT_DIR}/jd-lib.sh"

# --- Main ---

if [[ $# -ne 1 ]]; then
    echo "Usage: jd-read <ID>" >&2
    echo "  jd-read 31.14    # Display notes for that ID" >&2
    exit 1
fi

id="$1"

# Validate ID format
if [[ ! "$id" =~ ^[0-9][0-9]\.[0-9]+$ ]]; then
    echo "Error: Invalid ID format '${id}'. Expected XX.YY (e.g., 31.14)" >&2
    exit 1
fi

# Check JDex directory exists
if [[ ! -d "$JDEX_PATH" ]]; then
    echo "Error: JDex directory not found: ${JDEX_PATH}" >&2
    exit 1
fi

# Note file path
note_file="${JDEX_PATH}/${id}.md"

# Check if note file exists
if [[ ! -f "$note_file" ]]; then
    # Try to get the ID name for a helpful message
    id_name=$(get_id_name "$id" 2>/dev/null || echo "")
    if [[ -n "$id_name" ]]; then
        echo "No notes found for ${id} (${id_name})"
    else
        echo "No notes found for ${id}"
    fi
    exit 0
fi

# Display the notes
cat "$note_file"
