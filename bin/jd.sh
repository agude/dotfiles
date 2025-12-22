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
        matches=()
        while IFS= read -r line; do
            matches+=("$line")
        done < <(find . -maxdepth 1 -type d -iname "${query}*" -print)

    # Category search (e.g., "12" or "12 ")
    elif [[ "$query" =~ ^[0-9]{2}\s*$ ]]; then
        # Trim trailing space for a consistent search pattern
        trimmed_query=${query%% }
        matches=()
        while IFS= read -r line; do
            matches+=("$line")
        done < <(find . -maxdepth 2 -type d -iname "${trimmed_query} *" -print)

    # ID search (e.g., "12.3")
    elif [[ "$query" =~ ^[0-9]{2}\. ]]; then
        matches=()
        while IFS= read -r line; do
            matches+=("$line")
        done < <(find . -maxdepth 3 -type d -iname "${query}*" "${JD_VALIDATION_ARGS[@]}" -print)

    # Fallback to string search (e.g., "alex")
    else
        matches=()
        while IFS= read -r line; do
            matches+=("$line")
        done < <(find . -maxdepth 3 -type d -iname "*${query}*" "${JD_VALIDATION_ARGS[@]}" -print)
    fi

    # Clean up paths for display and sort the results
    cleaned_matches=()
    while IFS= read -r line; do
        cleaned_matches+=("$line")
    done < <(printf "%s\n" "${matches[@]}" | sed 's|^\./||' | sort)
    matches=("${cleaned_matches[@]}")

    num_matches=${#matches[@]}
    target_dir=""

    if [[ $num_matches -eq 0 ]]; then
        echo "No Johnny.Decimal directory found for query '${query}'" >&2
        exit 1
    elif [[ $num_matches -eq 1 ]]; then
        # Success: exactly one match.
        target_dir="${matches[0]}"
    else
        # Ambiguous: multiple matches. Use `select` to have the user choose.
        echo "Ambiguous query. Found ${num_matches} matches:" >&2
        PS3="Please enter a number (or Ctrl+C to cancel): "
        # The `select` menu prints to stderr, and reads from the tty.
        select choice in "${matches[@]}"; do
            if [[ -n "$choice" ]]; then
                target_dir="$choice"
                break
            else
                echo "Invalid selection. Try again." >&2
            fi
        done < /dev/tty
    fi

    # If a directory was selected, print its absolute path for the shell function to use.
    # Use portable method instead of readlink -f (not available on macOS)
    if [[ -n "$target_dir" ]]; then
        (cd "$target_dir" && pwd -P)
    fi

# Case 3: Too many arguments.
else
    echo "Usage: jd [search-string]" >&2
    exit 1
fi
