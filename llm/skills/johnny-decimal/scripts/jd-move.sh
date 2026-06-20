#!/usr/bin/env bash
# shellcheck shell=bash
#
# jd-move: Move files to a Johnny Decimal location
#
# Usage:
#   jd-move document.pdf 21.10
#   jd-move *.pdf 00.01                                    # Glob support
#   jd-move document.pdf 21.10 --name new_name.pdf         # Rename during move
#   jd-move document.pdf 91.10 --subdir Bolos/covers       # Into subdir
#   jd-move --force document.pdf 21.10                     # Allow overwrite
#   jd-move document.pdf 21.10 --porcelain                 # Output full path (for agents)

set -euo pipefail

# --- Load shared library ---
# Resolve symlink to find actual script location
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/jd-lib.sh"

# Parse common args (--porcelain)
jd_parse_common_args "$@"
set -- "${JD_REMAINING_ARGS[@]}"

# Validate JD_ROOT exists
jd_validate_root || exit 1

# --- Parse arguments ---

force=false
dry_run=false
subdir=""
rename=""
args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force|-f)
            force=true
            shift
            ;;
        --dry-run|-n)
            dry_run=true
            shift
            ;;
        --subdir)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --subdir requires a path argument" >&2
                exit 1
            fi
            subdir="$2"
            shift 2
            ;;
        --name)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --name requires a filename argument" >&2
                exit 1
            fi
            rename="$2"
            shift 2
            ;;
        *)
            args+=("$1")
            shift
            ;;
    esac
done
set -- "${args[@]}"

show_usage() {
    echo "Usage: jd-move [options] <source...> <ID>" >&2
    echo "  jd-move document.pdf 21.10                         # Move file" >&2
    echo "  jd-move *.pdf 00.01                                # Move multiple files" >&2
    echo "  jd-move my_folder 21.10                            # Move directory" >&2
    echo "  jd-move document.pdf 21.10 --name renamed.pdf      # Rename during move" >&2
    echo "  jd-move document.pdf 91.10 --subdir Bolos/covers   # Move into subdir" >&2
    echo "  jd-move --force document.pdf 21.10                 # Allow overwrite" >&2
    echo "  jd-move --dry-run document.pdf 21.10               # Preview without moving" >&2
}

if [[ "$JD_HELP_REQUESTED" == "true" ]]; then
    show_usage
    exit 0
fi

# Last positional arg is the JD ID, everything before it is sources
if [[ $# -lt 2 ]]; then
    show_usage
    exit 1
fi

target_id="${!#}"
sources=("${@:1:$#-1}")

# --- Validate inputs ---

# Validate ID format
if [[ ! "$target_id" =~ ^[0-9][0-9]\.[0-9]+$ ]]; then
    jd_error "Invalid ID format '${target_id}'. Expected XX.YY (e.g., 21.10)"
    exit 1
fi

# --name only makes sense with a single source
if [[ -n "$rename" ]] && [[ ${#sources[@]} -gt 1 ]]; then
    jd_error "--name can only be used with a single source file"
    exit 1
fi

# Check all sources exist before moving any
for source_path in "${sources[@]}"; do
    if [[ ! -e "$source_path" ]]; then
        jd_error "Source not found: ${source_path}"
        exit 1
    fi
done

# Find target directory
target_dir=$(find_id_dir "$target_id") || exit 1

# Append subdir if specified
if [[ -n "$subdir" ]]; then
    target_dir="${target_dir}/${subdir}"
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir"
    fi
fi

# --- Move each source ---

for source_path in "${sources[@]}"; do
    dest_name="${rename:-$(basename "$source_path")}"

    # Validate filename (if jd-validate exists)
    if [[ -x "${SCRIPT_DIR}/jd-validate.sh" ]]; then
        if ! "${SCRIPT_DIR}/jd-validate.sh" "$dest_name" >/dev/null 2>&1; then
            jd_warn "Filename may not follow conventions: ${dest_name}"
            "${SCRIPT_DIR}/jd-validate.sh" "$dest_name" >&2 || true
        fi
    fi

    target_path="${target_dir}/${dest_name}"

    # Check for existing file
    if [[ -e "$target_path" ]]; then
        if [[ "$force" == true ]]; then
            jd_warn "Overwriting existing file: ${dest_name}"
        else
            jd_error "Target file already exists: ${target_path}"
            echo "Use --force to overwrite" >&2
            exit 1
        fi
    fi

    if [[ "$dry_run" == true ]]; then
        if [[ "$JD_PORCELAIN" == "true" ]]; then
            echo "$target_path"
        else
            echo "Would move: $(basename "$source_path") -> ${target_id}"
            echo "  From: ${source_path}"
            echo "  To:   ${target_path}"
        fi
    else
        mv "$source_path" "$target_path"
        if [[ "$JD_PORCELAIN" == "true" ]]; then
            echo "$target_path"
        else
            jd_success "Moved: $(basename "$source_path") -> ${target_id}"
        fi
    fi
done
