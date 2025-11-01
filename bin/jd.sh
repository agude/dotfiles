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
    echo "Navigates to a Johnny.Decimal directory." >&2
    exit 1
fi

# Case 2: One argument. Search for directories starting with that argument.
if [[ $# -eq 1 ]]; then
    query="$1"
    # Find all potential matches using JD structure logic:
    # - Areas (e.g., 10-19) are only searched for at the top level.
    # - Categories/IDs (e.g., 11, 11.50) are searched for at any depth.
    # We use a shell array to handle spaces in paths correctly.
    readarray -t matches < <( ( \
        find . -maxdepth 2 -type d -name "${query}*" -name "[0-9][0-9]-*" -print; \
        find . -type d -name "${query}*" -name "[0-9][0-9].*" -print \
    ) | sort -u | sed 's|^\./||')


    num_matches=${#matches[@]}

    if [[ $num_matches -eq 0 ]]; then
        echo "No Johnny.Decimal directory found starting with '${query}'" >&2
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
