#!/usr/bin/env bash
# shellcheck shell=bash
#
# Johnny.Decimal Navigation Helper
#
# This script finds and selects a directory within a Johnny.Decimal file system.
# It's designed to be called by a shell function that will `cd` to the path
# this script outputs.
#
# Usage:
#   jd <search-string>    # Search by ID, category, area, or name
#   jd 21.10              # Navigate to specific ID
#   jd 21                 # Navigate to category (or select if ambiguous)
#   jd taxes              # Search by name

set -euo pipefail

# --- Load shared library ---
# Try multiple locations for portability
if [[ -f "${HOME}/.dotfiles/llm/skills/johnny-decimal/scripts/jd-lib.sh" ]]; then
    # shellcheck source=../llm/skills/johnny-decimal/scripts/jd-lib.sh
    source "${HOME}/.dotfiles/llm/skills/johnny-decimal/scripts/jd-lib.sh"
else
    echo "Error: jd-lib.sh not found" >&2
    exit 1
fi

# Initialize colors for display
jd_init_colors

# --- Main Logic ---

# Case 1: No arguments. Print usage and exit.
if [[ $# -eq 0 ]]; then
    echo "Usage: jd <search-string>" >&2
    echo "Navigates to a Johnny.Decimal directory by ID prefix or name." >&2
    exit 1
fi

# Case 2: Too many arguments.
if [[ $# -gt 1 ]]; then
    echo "Usage: jd <search-string>" >&2
    exit 1
fi

# Case 3: One argument. Search for directories.
query="$1"

# Search using library function
mapfile -t matches < <(jd_search "$query")
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
    select choice in "${matches[@]}"; do
        if [[ -n "$choice" ]]; then
            target_dir="$choice"
            break
        else
            echo "Invalid selection. Try again." >&2
        fi
    done < /dev/tty
fi

# Print absolute path for the shell function to use.
if [[ -n "$target_dir" ]]; then
    # Use portable method instead of readlink -f (not available on macOS)
    (cd "${JD_ROOT}/${target_dir}" && pwd -P)
fi
