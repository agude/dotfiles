#!/usr/bin/env bash
# shellcheck shell=bash
#
# jd-list: List contents of a Johnny Decimal location
#
# Usage:
#   jd-list              # List all areas
#   jd-list 20           # List categories in area 20-29
#   jd-list 21           # List subcategories in category 21
#   jd-list 21.10        # List files in subcategory 21.10
#   jd-list --porcelain  # Full paths, no colors (for scripts/agents)

set -euo pipefail

# --- Load shared library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=jd-lib.sh
source "${SCRIPT_DIR}/jd-lib.sh"

# Parse common args (--porcelain)
jd_parse_common_args "$@"
set -- "${JD_REMAINING_ARGS[@]}"

# --- Functions ---

list_areas() {
    while IFS= read -r path; do
        jd_format_path "$path"
    done < <(find "$JD_ROOT" -maxdepth 1 -type d -name '[0-9][0-9]-[0-9][0-9] *' | sort)
}

list_categories() {
    local area_prefix="$1"
    local area_dir
    area_dir=$(find "$JD_ROOT" -maxdepth 1 -type d -name "${area_prefix}-[0-9][0-9] *" 2>/dev/null | head -1)

    if [[ -z "$area_dir" ]]; then
        jd_error "No area found matching '${area_prefix}'"
        exit 1
    fi

    while IFS= read -r path; do
        jd_format_path "$path"
    done < <(find "$area_dir" -maxdepth 1 -type d -name '[0-9][0-9] *' | sort)
}

list_subcategories() {
    local category="$1"
    local category_dir
    category_dir=$(find_category_dir "$category") || exit 1

    while IFS= read -r path; do
        jd_format_path "$path"
    done < <(find "$category_dir" -maxdepth 1 -type d -name "${category}.[0-9]* *" | sort)
}

list_files() {
    local id="$1"
    local subcat_dir
    subcat_dir=$(find_id_dir "$id") || exit 1

    if [[ "$JD_PORCELAIN" == "true" ]]; then
        ls -la "$subcat_dir"
    else
        echo "${JD_COLOR_ID}${id}${JD_COLOR_RESET} $(get_id_name "$id")"
        echo ""
        ls -la "$subcat_dir"
    fi
}

# --- Main ---

if [[ $# -eq 0 ]]; then
    list_areas
elif [[ $# -eq 1 ]]; then
    query="$1"

    if [[ "$query" =~ ^[0-9]0$ ]]; then
        # Area query (e.g., "20" for 20-29)
        list_categories "$query"
    elif [[ "$query" =~ ^[0-9][0-9]$ ]]; then
        # Category query (e.g., "21")
        list_subcategories "$query"
    elif [[ "$query" =~ ^[0-9][0-9]\.[0-9]+$ ]]; then
        # ID query (e.g., "21.10")
        list_files "$query"
    else
        jd_error "Invalid query format '${query}'"
        echo "Usage: jd-list [XX|XX.YY] [--porcelain]" >&2
        exit 1
    fi
else
    echo "Usage: jd-list [area|category|id] [--porcelain]" >&2
    echo "  jd-list              # List all areas" >&2
    echo "  jd-list 20           # List categories in 20-29" >&2
    echo "  jd-list 21           # List subcategories in 21" >&2
    echo "  jd-list 21.10        # List files in 21.10" >&2
    echo "  jd-list --porcelain  # Full paths (for agents)" >&2
    exit 1
fi
