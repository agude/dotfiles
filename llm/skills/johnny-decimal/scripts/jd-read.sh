#!/usr/bin/env bash
# shellcheck shell=bash
#
# jd-read: Read notes for a Johnny Decimal ID
#
# Notes are stored in the JDex as individual markdown files per ID.
#
# Usage:
#   jd-read 31.14         # Display notes for ID 31.14
#   jd-read 31.14 --edit  # Open notes in $EDITOR (interactive only)
#   jd-read 31.14 --porcelain  # Full path output (for agents)

set -euo pipefail

# --- Load shared library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=jd-lib.sh
source "${SCRIPT_DIR}/jd-lib.sh"

# Parse common args (--porcelain)
jd_parse_common_args "$@"
set -- "${JD_REMAINING_ARGS[@]}"

# Parse local args (--edit)
EDIT_MODE="false"
args=()
for arg in "$@"; do
    case "$arg" in
        --edit|-e)
            EDIT_MODE="true"
            ;;
        *)
            args+=("$arg")
            ;;
    esac
done
set -- "${args[@]}"

# --- Main ---

if [[ $# -ne 1 ]]; then
    echo "Usage: jd-read <ID> [--edit]" >&2
    echo "  jd-read 31.14         # Display notes" >&2
    echo "  jd-read 31.14 --edit  # Open in \$EDITOR" >&2
    exit 1
fi

id="$1"

# Validate ID format
if [[ ! "$id" =~ ^[0-9][0-9]\.[0-9]+$ ]]; then
    jd_error "Invalid ID format '${id}'. Expected XX.YY (e.g., 31.14)"
    exit 1
fi

# Check JDex directory exists
if [[ ! -d "$JDEX_PATH" ]]; then
    jd_error "JDex directory not found: ${JDEX_PATH}"
    exit 1
fi

# Note file path
note_file="${JDEX_PATH}/${id}.md"

# Handle edit mode
if [[ "$EDIT_MODE" == "true" ]]; then
    if ! jd_is_interactive; then
        jd_error "--edit requires interactive mode"
        exit 1
    fi

    # Create file if it doesn't exist
    if [[ ! -f "$note_file" ]]; then
        id_name=$(get_id_name "$id" 2>/dev/null || echo "Unknown")
        {
            echo "# ${id} ${id_name}"
            echo ""
        } > "$note_file"
    fi

    # Open in editor
    editor="${EDITOR:-${VISUAL:-vi}}"
    "$editor" "$note_file"
    exit 0
fi

# Check if note file exists (for read mode)
if [[ ! -f "$note_file" ]]; then
    # Try to get the ID name for a helpful message
    id_name=$(get_id_name "$id" 2>/dev/null || echo "")
    if [[ -n "$id_name" ]]; then
        jd_warn "No notes found for ${id} (${id_name})"
    else
        jd_warn "No notes found for ${id}"
    fi
    exit 0
fi

# Display the notes
if [[ "$JD_PORCELAIN" == "true" ]]; then
    # In porcelain mode, just output the path
    echo "$note_file"
else
    cat "$note_file"
fi
