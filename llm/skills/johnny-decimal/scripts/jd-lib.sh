#!/usr/bin/env bash
# shellcheck shell=bash
#
# jd-lib.sh: Shared library for Johnny Decimal scripts
#
# Source this file from other jd-* scripts:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/jd-lib.sh"
#
# Human vs Agent Mode:
#   Scripts auto-detect human mode (TTY + no --porcelain flag).
#   - Human mode: colors, short paths, interactive features (editor)
#   - Agent mode (--porcelain): full paths, no colors, never interactive
#
#   Call jd_parse_common_args "$@" early, then use JD_PORCELAIN to check mode.

# --- Configuration (exported for use by scripts that source this library) ---
export JD_ROOT="${XDG_DOCUMENTS_DIR:-${HOME}/Documents}"
export JDEX_PATH="${JD_ROOT}/00-09 System/00 System/00.00 JDex for System"

# --- Human vs Agent Mode ---

# Set to "true" by jd_parse_common_args if --porcelain is passed
JD_PORCELAIN="false"

# Colors (set if TTY and not porcelain mode)
# Exported so subshells and scripts can use them
export JD_COLOR_ID=""
export JD_COLOR_NAME=""
export JD_COLOR_PATH=""
export JD_COLOR_SUCCESS=""
export JD_COLOR_ERROR=""
export JD_COLOR_WARN=""
export JD_COLOR_RESET=""

# Initialize colors if stdout is a TTY
jd_init_colors() {
    if [[ -t 1 ]] && [[ "$JD_PORCELAIN" != "true" ]]; then
        JD_COLOR_ID=$'\033[1;34m'      # Bold blue
        JD_COLOR_NAME=$'\033[0;37m'    # White
        JD_COLOR_PATH=$'\033[0;90m'    # Gray
        JD_COLOR_SUCCESS=$'\033[0;32m' # Green
        JD_COLOR_ERROR=$'\033[0;31m'   # Red
        JD_COLOR_WARN=$'\033[0;33m'    # Yellow
        JD_COLOR_RESET=$'\033[0m'
    fi
}

# Check if we're in human-interactive mode (TTY + not porcelain)
jd_is_interactive() {
    [[ -t 1 ]] && [[ -t 0 ]] && [[ "$JD_PORCELAIN" != "true" ]]
}

# Parse common arguments (--porcelain, --help)
# Usage: jd_parse_common_args "$@"; set -- "${JD_REMAINING_ARGS[@]}"
JD_REMAINING_ARGS=()
jd_parse_common_args() {
    JD_REMAINING_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --porcelain)
                JD_PORCELAIN="true"
                shift
                ;;
            *)
                JD_REMAINING_ARGS+=("$1")
                shift
                ;;
        esac
    done
    # Initialize colors after parsing (so --porcelain disables them)
    jd_init_colors
}

# --- Output Helpers ---

# Format a JD path for display
# In human mode: just the basename (e.g., "21.10 Example Bank")
# In porcelain mode: full path
jd_format_path() {
    local path="$1"
    if [[ "$JD_PORCELAIN" == "true" ]]; then
        echo "$path"
    else
        local name
        name=$(basename "$path")
        # Color the ID portion
        if [[ "$name" =~ ^([0-9][0-9][-\.][0-9]*[0-9]?)\ (.*)$ ]]; then
            echo "${JD_COLOR_ID}${BASH_REMATCH[1]}${JD_COLOR_RESET} ${BASH_REMATCH[2]}"
        elif [[ "$name" =~ ^([0-9][0-9])\ (.*)$ ]]; then
            echo "${JD_COLOR_ID}${BASH_REMATCH[1]}${JD_COLOR_RESET} ${BASH_REMATCH[2]}"
        else
            echo "$name"
        fi
    fi
}

jd_success() {
    echo "${JD_COLOR_SUCCESS}$*${JD_COLOR_RESET}"
}

jd_error() {
    echo "${JD_COLOR_ERROR}Error: $*${JD_COLOR_RESET}" >&2
}

jd_warn() {
    echo "${JD_COLOR_WARN}Warning: $*${JD_COLOR_RESET}" >&2
}

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
        jd_error "No area found for '${input}'"
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
        jd_error "No category found for '${input}'"
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
        jd_error "Invalid ID format '${id}'. Expected XX.YY"
        return 1
    fi

    local category_dir
    category_dir=$(find_category_dir "$id") || return 1

    local subcat_dir
    subcat_dir=$(find "$category_dir" -maxdepth 1 -type d -name "${id} *" 2>/dev/null | head -1)

    if [[ -z "$subcat_dir" ]]; then
        jd_error "No subcategory found for '${id}'"
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
