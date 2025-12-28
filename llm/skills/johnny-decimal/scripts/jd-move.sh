#!/usr/bin/env bash
# shellcheck shell=bash
#
# jd-move: Move a file to a Johnny Decimal location
#
# Usage:
#   jd-move document.pdf 21.10
#   jd-move document.pdf 21.10 new_name.pdf
#   jd-move --force document.pdf 21.10   # Allow overwrite
#   jd-move document.pdf 21.10 --porcelain  # Output full path (for agents)

set -euo pipefail

# --- Load shared library ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=jd-lib.sh
source "${SCRIPT_DIR}/jd-lib.sh"

# Parse common args (--porcelain)
jd_parse_common_args "$@"
set -- "${JD_REMAINING_ARGS[@]}"

# --- Parse arguments ---

force=false
args=()
for arg in "$@"; do
    case "$arg" in
        --force|-f)
            force=true
            ;;
        *)
            args+=("$arg")
            ;;
    esac
done
set -- "${args[@]}"

if [[ $# -lt 2 ]] || [[ $# -gt 3 ]]; then
    echo "Usage: jd-move [--force] <file> <ID> [new_name]" >&2
    echo "  jd-move document.pdf 21.10" >&2
    echo "  jd-move document.pdf 21.10 renamed.pdf" >&2
    echo "  jd-move --force document.pdf 21.10  # Allow overwrite" >&2
    exit 1
fi

source_file="$1"
target_id="$2"
new_name="${3:-$(basename "$source_file")}"

# --- Validate inputs ---

# Check source file exists
if [[ ! -f "$source_file" ]]; then
    jd_error "Source file not found: ${source_file}"
    exit 1
fi

# Validate ID format
if [[ ! "$target_id" =~ ^[0-9][0-9]\.[0-9]+$ ]]; then
    jd_error "Invalid ID format '${target_id}'. Expected XX.YY (e.g., 21.10)"
    exit 1
fi

# Validate filename (if jd-validate exists)
if [[ -x "${SCRIPT_DIR}/jd-validate.sh" ]]; then
    if ! "${SCRIPT_DIR}/jd-validate.sh" "$new_name" >/dev/null 2>&1; then
        jd_warn "Filename may not follow conventions"
        "${SCRIPT_DIR}/jd-validate.sh" "$new_name" >&2 || true
    fi
fi

# Find target directory
target_dir=$(find_id_dir "$target_id") || exit 1

# Construct target path
target_path="${target_dir}/${new_name}"

# Check for existing file
if [[ -e "$target_path" ]]; then
    if [[ "$force" == true ]]; then
        jd_warn "Overwriting existing file: ${new_name}"
    else
        jd_error "Target file already exists: ${target_path}"
        echo "Use --force to overwrite" >&2
        exit 1
    fi
fi

# --- Perform the move ---

mv "$source_file" "$target_path"

if [[ "$JD_PORCELAIN" == "true" ]]; then
    echo "$target_path"
else
    jd_success "Moved: $(basename "$source_file") -> ${target_id}"
fi
