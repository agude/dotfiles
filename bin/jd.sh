#!/usr/bin/env bash
# shellcheck shell=bash
#
# Johnny.Decimal Navigation Helper
#
# This script finds and selects a directory within a Johnny.Decimal file system.
# It's designed to be called by a shell function that will `cd` to the path
# this script outputs.

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
# The root directory of your Johnny.Decimal system.
JD_ROOT="${XDG_DOCUMENTS_DIR:-${HOME}/Documents}"

# --- Main Logic ---

# Change to the root directory to simplify find paths.
cd "${JD_ROOT}"

# Case 1: No arguments. Print usage and exit.
if [[ $# -eq 0 ]]; then
    echo "Usage: jd <search-string>" >&2
    echo "Navigates to a Johnny.Decimal directory by ID prefix or name." >&2
    exit 1
fi

# Case 2: One argument. Search for directories.
if [[ $# -eq 1 ]]; then
    query="$1"

    # This array holds the validation arguments for the find command.
    # It ensures we only match valid JD-formatted directories.
    JD_VALIDATION_ARGS=(
        '('
        -name '[0-9][0-9]-*' -o
        -name '[0-9][0-9].*' -o
        -name '[0-9][0-9] *'
        ')'
    )

    # --- Determine search type based on query format ---

    # Area search (e.g., "10-")
    if [[ "$query" =~ ^[0-9]{2}- ]]; then
        readarray -t matches < <(find . -maxdepth 1 -type d -iname "${query}*" -print)

    # Category search (e.g., "12" or "12 ")
    elif [[ "$query" =~ ^[0-9]{2}\s*$ ]]; then
        # Trim trailing space for a consistent search pattern
        trimmed_query=${query%% }
        readarray -t matches < <(find . -maxdepth 2 -type d -iname "${trimmed_query} *" -print)

    # ID search (e.g., "12.3")
    elif [[ "$query" =~ ^[0-9]{2}\. ]]; then
        readarray -t matches < <(find . -maxdepth 3 -type d -iname "${query}*" "${JD_VALIDATION_ARGS[@]}" -print)

    # Fallback to string search (e.g., "alex")
    else
        readarray -t matches < <(find . -maxdepth 3 -type d -iname "*${query}*" "${JD_VALIDATION_ARGS[@]}" -print)
    fi

    # Clean up paths for display and sort the results
    readarray -t matches < <(printf "%s\n" "${matches[@]}" | sed 's|^\./||' | sort)

    num_matches=${#matches[@]}

    if [[ $num_matches -eq 0 ]]; then
        echo "No Johnny.Decimal directory found for query '${query}'" >&2
        exit 1
    elif [[ $num_matches -eq 1 ]]; then
        # Success: exactly one match. Print its absolute path.
        readlink -f "${matches[0]}"
    else
        # Ambiguous: multiple matches. List them and exit.
        echo "Ambiguous query. Found ${num_matches} matches:" >&2
        printf "  %s\n" "${matches[@]}" >&2
        exit 1
    fi

# Case 3: Too many arguments.
else
    echo "Usage: jd [search-string]" >&2
    exit 1
fi
