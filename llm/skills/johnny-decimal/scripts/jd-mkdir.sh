#!/usr/bin/env bash
# shellcheck shell=bash
#
# jd-mkdir: Create a new Johnny Decimal subcategory folder
#
# Usage:
#   jd-mkdir 21 "Chase Bank"           # Auto-assigns next ID (e.g., 21.15)
#   jd-mkdir 21 "Chase Bank" --id 15   # Explicit ID: 21.15

set -euo pipefail

# --- Load shared library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=jd-lib.sh
source "${SCRIPT_DIR}/jd-lib.sh"

# --- Parse arguments ---
explicit_id=""
category=""
name=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --id)
            explicit_id="$2"
            shift 2
            ;;
        *)
            if [[ -z "$category" ]]; then
                category="$1"
            elif [[ -z "$name" ]]; then
                name="$1"
            else
                echo "Error: Unexpected argument '$1'" >&2
                exit 1
            fi
            shift
            ;;
    esac
done

# --- Validate inputs ---
if [[ -z "$category" ]] || [[ -z "$name" ]]; then
    echo "Usage: jd-mkdir <category> <name> [--id N]" >&2
    echo "  jd-mkdir 21 \"Chase Bank\"           # Auto-assigns next ID" >&2
    echo "  jd-mkdir 21 \"Chase Bank\" --id 15   # Explicit: 21.15" >&2
    exit 1
fi

# Validate category format (XX)
if [[ ! "$category" =~ ^[0-9][0-9]$ ]]; then
    echo "Error: Invalid category format '${category}'. Expected XX (e.g., 21)" >&2
    exit 1
fi

# Find the category directory (validates it exists)
category_dir=$(find_category_dir "$category") || exit 1

# Determine the ID
if [[ -n "$explicit_id" ]]; then
    # Validate explicit ID is a number
    if [[ ! "$explicit_id" =~ ^[0-9]+$ ]]; then
        echo "Error: --id must be a number, got '${explicit_id}'" >&2
        exit 1
    fi
    id="${category}.${explicit_id}"
else
    # Auto-assign next available ID
    id=$(next_available_id "$category") || exit 1
fi

# Construct the new folder path
new_folder="${category_dir}/${id} ${name}"

# Check if it already exists
if [[ -e "$new_folder" ]]; then
    echo "Error: Folder already exists: ${new_folder}" >&2
    exit 1
fi

# Create the folder
mkdir -p "$new_folder"
chmod 700 "$new_folder"

echo "Created: ${new_folder}"
