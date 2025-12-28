#!/usr/bin/env bash
# shellcheck shell=bash
#
# jd-lib.sh: Shared library for Johnny Decimal scripts
#
# Source this file from other jd-* scripts:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/jd-lib.sh"

# --- Configuration (exported for use by scripts that source this library) ---
export JD_ROOT="${XDG_DOCUMENTS_DIR:-${HOME}/Documents}"
export JDEX_PATH="${JD_ROOT}/00-09 System/00 System/00.00 JDex for System"

# --- Path Finding Functions ---

# Find the area directory for a given category or ID
# Usage: find_area_dir 21 or find_area_dir 21.10
# Returns: Full path to area directory (e.g., /path/to/20-29 Finances)
find_area_dir() {
    local input="$1"
    local category="${input%%.*}"
    local area_prefix="${category:0:1}0"

    local area_dir
    area_dir=$(find "$JD_ROOT" -maxdepth 1 -type d -name "${area_prefix}-[0-9][0-9] *" 2>/dev/null | head -1)

    if [[ -z "$area_dir" ]]; then
        echo "Error: No area found for '${input}'" >&2
        return 1
    fi

    echo "$area_dir"
}

# Find the category directory for a given category or ID
# Usage: find_category_dir 21 or find_category_dir 21.10
# Returns: Full path to category directory (e.g., /path/to/21 Banks)
find_category_dir() {
    local input="$1"
    local category="${input%%.*}"

    local area_dir
    area_dir=$(find_area_dir "$input") || return 1

    local category_dir
    category_dir=$(find "$area_dir" -maxdepth 1 -type d -name "${category} *" 2>/dev/null | head -1)

    if [[ -z "$category_dir" ]]; then
        echo "Error: No category found for '${input}'" >&2
        return 1
    fi

    echo "$category_dir"
}

# Find the subcategory (ID) directory
# Usage: find_id_dir 21.10
# Returns: Full path to subcategory directory (e.g., /path/to/21.10 Example Bank)
find_id_dir() {
    local id="$1"

    if [[ ! "$id" =~ ^[0-9][0-9]\.[0-9]+$ ]]; then
        echo "Error: Invalid ID format '${id}'. Expected XX.YY" >&2
        return 1
    fi

    local category_dir
    category_dir=$(find_category_dir "$id") || return 1

    local subcat_dir
    subcat_dir=$(find "$category_dir" -maxdepth 1 -type d -name "${id} *" 2>/dev/null | head -1)

    if [[ -z "$subcat_dir" ]]; then
        echo "Error: No subcategory found for '${id}'" >&2
        return 1
    fi

    echo "$subcat_dir"
}

# Get the name portion of an ID's folder
# Usage: get_id_name 21.10
# Returns: Just the name (e.g., "Example Bank")
get_id_name() {
    local id="$1"

    local subcat_dir
    subcat_dir=$(find_id_dir "$id" 2>/dev/null) || return 1

    # Extract just the name part (after "XX.YY ")
    basename "$subcat_dir" | sed "s/^${id} //"
}

# Find the next available ID number in a category
# Usage: next_available_id 21
# Returns: Next ID (e.g., "21.15")
next_available_id() {
    local category="$1"

    local category_dir
    category_dir=$(find_category_dir "$category") || return 1

    # Find all existing subcategory numbers
    local max_num=9  # Start after system IDs (XX.00-XX.09)

    while IFS= read -r dir; do
        # Extract the number after the dot
        local dirname
        dirname=$(basename "$dir")
        if [[ "$dirname" =~ ^${category}\.([0-9]+) ]]; then
            local num="${BASH_REMATCH[1]}"
            # Remove leading zeros for comparison
            num=$((10#$num))
            if [[ $num -gt $max_num ]]; then
                max_num=$num
            fi
        fi
    done < <(find "$category_dir" -maxdepth 1 -type d -name "${category}.[0-9]* *" 2>/dev/null)

    local next_num=$((max_num + 1))
    echo "${category}.${next_num}"
}
