#!/usr/bin/env bash
# shellcheck shell=bash
#
# jd-validate: Validate filenames against Johnny Decimal conventions
#
# Usage:
#   jd-validate <filename>
#   jd-validate statement.pdf        # Warns about missing date
#   jd-validate 2024-12-27_doc.pdf   # OK

set -euo pipefail

# --- Functions ---

validate_filename() {
    local filename="$1"
    local basename
    basename=$(basename "$filename")
    local warnings=()
    local errors=()

    # Check for spaces (should use underscores)
    if [[ "$basename" =~ \  ]]; then
        warnings+=("Contains spaces - prefer underscores")
    fi

    # Check for date prefix on common transient file types
    if [[ ! "$basename" =~ ^[0-9]{4}[-_]?[0-9]{2}[-_]?[0-9]{2} ]] && \
       [[ ! "$basename" =~ ^[0-9]{8} ]]; then
        # Check if it looks like a transient file that should have a date
        if [[ "$basename" =~ (statement|receipt|invoice|bill|check|paystub) ]]; then
            warnings+=("Transient document without date prefix - consider YYYY-MM-DD_name.ext")
        fi
    fi

    # Check for special characters that might cause issues
    if [[ "$basename" =~ [\'\"\`\$\&\|\<\>\;] ]]; then
        errors+=("Contains problematic special characters")
    fi

    # Output results
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "ERRORS for '$basename':"
        for err in "${errors[@]}"; do
            echo "  - $err"
        done
    fi

    if [[ ${#warnings[@]} -gt 0 ]]; then
        echo "WARNINGS for '$basename':"
        for warn in "${warnings[@]}"; do
            echo "  - $warn"
        done
    fi

    if [[ ${#errors[@]} -eq 0 ]] && [[ ${#warnings[@]} -eq 0 ]]; then
        echo "OK: '$basename' follows conventions"
        return 0
    elif [[ ${#errors[@]} -gt 0 ]]; then
        return 1
    else
        return 0  # Warnings don't fail
    fi
}

# --- Main ---

if [[ $# -eq 0 ]]; then
    echo "Usage: jd-validate <filename> [filename...]" >&2
    exit 1
fi

exit_code=0
for file in "$@"; do
    if ! validate_filename "$file"; then
        exit_code=1
    fi
done

exit $exit_code
