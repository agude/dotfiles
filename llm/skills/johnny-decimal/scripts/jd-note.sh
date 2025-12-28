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
#   jd-note                    # Select ID interactively, then open $EDITOR
#   jd-note 31.14              # Opens $EDITOR (interactive mode only)
#   jd-note 31.14 --porcelain  # Agent mode (requires text argument)

set -euo pipefail

# --- Load shared library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=jd-lib.sh
source "${SCRIPT_DIR}/jd-lib.sh"

# Parse common args (--porcelain)
jd_parse_common_args "$@"
set -- "${JD_REMAINING_ARGS[@]}"

# --- Functions ---

# Find all JD IDs and let user select one interactively
# Returns the selected ID via stdout
select_id_interactively() {
    local display_items=()

    # Find all subcategory directories (XX.YY format)
    while IFS= read -r dir; do
        local basename_dir
        basename_dir=$(basename "$dir")
        # Extract the ID (XX.YY) from the directory name
        if [[ "$basename_dir" =~ ^([0-9][0-9]\.[0-9]+)\ (.*)$ ]]; then
            local id="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]}"
            display_items+=("${id} ${name}")
        fi
    done < <(find "$JD_ROOT" -maxdepth 3 -type d 2>/dev/null | grep -E '/[0-9][0-9]\.[0-9]+ ' | sort)

    if [[ ${#display_items[@]} -eq 0 ]]; then
        jd_error "No JD subcategories found in ${JD_ROOT}"
        return 1
    fi

    echo "Select a location for your note:" >&2
    PS3="Enter number (or Ctrl+C to cancel): "
    select choice in "${display_items[@]}"; do
        if [[ -n "$choice" ]]; then
            # Extract the ID from the selection
            local selected_id="${choice%% *}"
            echo "$selected_id"
            return 0
        else
            echo "Invalid selection. Try again." >&2
        fi
    done < /dev/tty
}

# Open editor for note entry, return the text via stdout
get_note_from_editor() {
    local id="$1"
    local id_name="$2"
    local tmpfile
    tmpfile=$(mktemp "${TMPDIR:-/tmp}/jd-note.XXXXXX.md")

    # Pre-populate with a helpful template
    {
        echo "# Note for ${id} ${id_name}"
        echo ""
        echo "<!-- Write your note below. Lines starting with # or <!-- are ignored. -->"
        echo ""
    } > "$tmpfile"

    # Open editor (redirect to TTY since we're in a command substitution)
    local editor="${EDITOR:-${VISUAL:-vi}}"
    "$editor" "$tmpfile" < /dev/tty > /dev/tty || {
        jd_error "Editor '${editor}' failed to launch"
        rm -f "$tmpfile"
        return 1
    }

    # Extract content (skip header/comment lines, trim whitespace)
    local content
    content=$(grep -v '^#' "$tmpfile" | grep -v '^<!--' | sed '/^[[:space:]]*$/d')

    rm -f "$tmpfile"

    if [[ -z "$content" ]]; then
        return 1
    fi

    echo "$content"
}

# --- Main ---

# No arguments: interactive ID selection (if TTY available)
if [[ $# -lt 1 ]]; then
    if jd_is_interactive; then
        id=$(select_id_interactively) || exit 1
    else
        echo "Usage: jd-note <ID> [note text]" >&2
        echo "  jd-note                # Select ID interactively" >&2
        echo "  jd-note 31.14          # Opens \$EDITOR (interactive)" >&2
        echo "  jd-note 31.14 \"text\"   # Add note directly" >&2
        exit 1
    fi
else
    id="$1"
    shift
fi

# Collect remaining args as note text (may be empty)
note_text="$*"

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

# Get ID name for display
id_name=$(get_id_name "$id" 2>/dev/null || echo "Unknown")

# If no note text provided, try editor (interactive mode only)
if [[ -z "$note_text" ]]; then
    if jd_is_interactive; then
        note_text=$(get_note_from_editor "$id" "$id_name") || {
            jd_warn "No note content entered. Aborting."
            exit 0
        }
    else
        jd_error "Note text required in non-interactive mode"
        echo "Usage: jd-note <ID> <note text>" >&2
        exit 1
    fi
fi

# Note file path
note_file="${JDEX_PATH}/${id}.md"

# Get today's date
today=$(date +%Y-%m-%d)

# If note file doesn't exist, create with header
if [[ ! -f "$note_file" ]]; then
    {
        echo "# ${id} ${id_name}"
        echo ""
        echo "## ${today}"
        echo ""
        echo "$note_text"
        echo ""
    } > "$note_file"
    jd_success "Created new notes file: ${id}.md"
else
    # File exists - check if today's date header is already there
    if grep -q "^## ${today}$" "$note_file"; then
        # Today's header exists - append note under it
        {
            echo "$note_text"
            echo ""
        } >> "$note_file"
        jd_success "Added note to ${id}.md"
    else
        # No header for today - add new date section
        {
            echo "## ${today}"
            echo ""
            echo "$note_text"
            echo ""
        } >> "$note_file"
        jd_success "Added note to ${id}.md"
    fi
fi
