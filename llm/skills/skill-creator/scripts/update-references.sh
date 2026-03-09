#!/usr/bin/env bash
# update-references.sh — Fetch the latest Agent Skills docs from agentskills.io.
#
# Usage: update-references.sh
#
# Parses the sitemap to discover pages, fetches each page's .md variant, and
# writes them to the references/ directory alongside this script's skill.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: update-references.sh

Fetch the latest Agent Skills docs from agentskills.io.

Parses the sitemap to discover pages, fetches each page's .md variant, and
writes them to the references/ directory alongside this script's skill.
Records the fetch date in references/.last-updated.
EOF
}

if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REF_DIR="${SCRIPT_DIR}/../references"

mkdir -p "$REF_DIR"

# Record existing .md files so we can detect stale ones after fetching.
declare -A EXISTING_FILES
for f in "${REF_DIR}"/*.md; do
    [[ -f "$f" ]] && EXISTING_FILES["$(basename "$f")"]=1
done

# Fetch sitemap and extract URLs
SITEMAP=$(curl -sL "https://agentskills.io/sitemap.xml")
URLS=$(echo "$SITEMAP" | grep -o '<loc>[^<]*' | sed 's/<loc>//')

FETCHED=0
FAILED=()
REFRESHED_FILES=()

for url in $URLS; do
    # Extract path: https://agentskills.io/foo/bar -> foo/bar
    path="${url#https://agentskills.io/}"

    # Skip pages not relevant to skill authoring
    case "$path" in
        home|client-implementation*) continue ;;
    esac

    # Convert slashes to hyphens for filename: foo/bar -> foo-bar.md
    filename="${path//\//-}.md"
    md_url="${url}.md"

    echo "Fetching ${md_url} ..."
    if curl -sfL "$md_url" -o "${REF_DIR}/${filename}"; then
        if [[ ! -s "${REF_DIR}/${filename}" ]]; then
            echo "  Warning: empty response from ${md_url}, removing" >&2
            rm -f "${REF_DIR}/${filename}"
            FAILED+=("$md_url")
        else
            FETCHED=$((FETCHED + 1))
            REFRESHED_FILES+=("$filename")
        fi
    else
        rm -f "${REF_DIR}/${filename}"
        echo "  Warning: failed to fetch ${md_url}" >&2
        FAILED+=("$md_url")
    fi
done

# Remove stale .md files not refreshed in this run
REMOVED=()
declare -A REFRESHED_SET
for f in "${REFRESHED_FILES[@]}"; do
    REFRESHED_SET["$f"]=1
done

for f in "${!EXISTING_FILES[@]}"; do
    if [[ -z "${REFRESHED_SET[$f]:-}" ]]; then
        echo "Removing stale: ${f}"
        rm -f "${REF_DIR}/${f}"
        REMOVED+=("$f")
    fi
done

# Record fetch date
date -Iseconds > "${REF_DIR}/.last-updated"

# --- Summary ---
echo ""
echo "Fetched ${FETCHED} reference file(s) into ${REF_DIR}/"
if [[ ${#REMOVED[@]} -gt 0 ]]; then
    echo "Removed ${#REMOVED[@]} stale file(s): ${REMOVED[*]}"
fi
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "Failed to fetch ${#FAILED[@]} URL(s):"
    for f in "${FAILED[@]}"; do
        echo "  - $f"
    done
fi
echo "Last updated: $(cat "${REF_DIR}/.last-updated")"
