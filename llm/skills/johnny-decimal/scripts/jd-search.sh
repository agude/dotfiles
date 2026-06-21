#!/usr/bin/env bash
# shellcheck shell=bash
#
# jd-search: Search for JD folders by name or ID fragment
#
# Usage:
#   jd-search bank                  # Find folders matching "bank"
#   jd-search 21.1                  # Find IDs starting with 21.1
#   jd-search 21                    # Find category 21
#   jd-search 20-                   # Find area 20-29
#   jd-search bank --porcelain      # Full paths, no colors

set -euo pipefail

# --- Load shared library ---
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/jd-lib.sh"

# Parse common args (--porcelain, --help)
jd_parse_common_args "$@"
set -- "${JD_REMAINING_ARGS[@]}"

# Validate JD_ROOT exists
jd_validate_root || exit 1

show_usage() {
    echo "Usage: jd-search <query> [--porcelain]" >&2
    echo "  jd-search bank           # Find folders matching \"bank\"" >&2
    echo "  jd-search 21.1           # Find IDs starting with 21.1" >&2
    echo "  jd-search 21             # Find category 21" >&2
    echo "  jd-search 20-            # Find area 20-29" >&2
}

if [[ "$JD_HELP_REQUESTED" == "true" ]]; then
    show_usage
    exit 0
fi

if [[ $# -ne 1 ]]; then
    show_usage
    exit 1
fi

query="$1"

results=()
while IFS= read -r line; do
    results+=("$line")
done < <(jd_search "$query")

if [[ ${#results[@]} -eq 0 ]]; then
    jd_error "No matches for '${query}'"
    exit 1
fi

for result in "${results[@]}"; do
    if [[ "$JD_PORCELAIN" == "true" ]]; then
        echo "${JD_ROOT}/${result}"
    else
        jd_format_path "$result"
    fi
done
