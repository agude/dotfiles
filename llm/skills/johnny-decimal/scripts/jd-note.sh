#!/usr/bin/env bash
# shellcheck shell=bash
#
# jd-note: Add a timestamped note to a Johnny Decimal ID
#
# Notes are stored in the JDex as individual markdown files per ID.
#
# Usage:
#   jd-note 31.14 "The patio is poured over brick, over more brick"
#   jd-note 21.10 "Updated autopay settings"

set -euo pipefail

# --- Load shared library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=jd-lib.sh
source "${SCRIPT_DIR}/jd-lib.sh"

# --- Main ---

if [[ $# -lt 2 ]]; then
    echo "Usage: jd-note <ID> <note text>" >&2
    echo "  jd-note 31.14 \"The patio is poured over brick\"" >&2
    exit 1
fi

id="$1"
shift
note_text="$*"

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

# Get today's date
today=$(date +%Y-%m-%d)

# If note file doesn't exist, create with header
if [[ ! -f "$note_file" ]]; then
    id_name=$(get_id_name "$id" || echo "Unknown")
    {
        echo "# ${id} ${id_name}"
        echo ""
        echo "## ${today}"
        echo ""
        echo "$note_text"
        echo ""
    } > "$note_file"
    echo "Created new notes file: ${note_file}"
else
    # File exists - check if today's date header is already there
    if grep -q "^## ${today}$" "$note_file"; then
        # Today's header exists - append note under it
        # We need to insert after the header, so we use a temp approach
        # Find line number of today's header, then insert after blank line
        {
            echo "$note_text"
            echo ""
        } >> "$note_file"
        echo "Added note to ${id}.md (under existing ${today} header)"
    else
        # No header for today - add new date section
        {
            echo "## ${today}"
            echo ""
            echo "$note_text"
            echo ""
        } >> "$note_file"
        echo "Added note to ${id}.md"
    fi
fi
