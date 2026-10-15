#!/usr/bin/env bash
# Refresh only the explicitly selected portable authoring documentation.
set -euo pipefail

if [[ "${1:-}" == "--help" ]]; then
    cat <<'HELP'
Usage: update-references.sh

Fetch selected agentskills.io pages into references/. Requires curl and network
access. Stage every page before replacing snapshots; any failed or empty
response exits nonzero without changing existing references. Record source URLs
and UTC fetch time. Remove obsolete files only from the previous vendored.txt
manifest; leave hand-written references untouched.
HELP
    exit 0
fi
if [[ $# -ne 0 ]]; then
    echo "Error: unexpected arguments; use --help." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REF_DIR="${SCRIPT_DIR}/../references"
mkdir -p "$REF_DIR"
STAGING_DIR="$(mktemp -d "${REF_DIR}/.refresh.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

PAGES=(
    specification
    skill-creation/best-practices
    skill-creation/optimizing-descriptions
    skill-creation/using-scripts
    skill-creation/evaluating-skills
    skill-creation/quickstart
)

for page in "${PAGES[@]}"; do
    filename="${page//\//-}.md"
    url="https://agentskills.io/${page}.md"
    echo "Fetching ${url}" >&2
    # Bound connection setup and each complete transfer; avoid an indefinite
    # refresh while allowing retries for transient documentation-site errors.
    if ! curl --fail --silent --show-error --location --connect-timeout 10 \
        --max-time 60 --retry 2 "$url" -o "${STAGING_DIR}/${filename}"; then
        echo "Error: fetch failed; existing references are unchanged." >&2
        exit 1
    fi
    if [[ ! -s "${STAGING_DIR}/${filename}" ]] || \
        ! LC_ALL=C grep -q '[^[:space:]]' "${STAGING_DIR}/${filename}" || \
        LC_ALL=C awk 'NF { print; exit }' "${STAGING_DIR}/${filename}" | \
            grep -qiE '^[[:space:]]*<!doctype html|^[[:space:]]*<html([[:space:]>])'; then
        echo "Error: empty or HTML response for ${url}; references are unchanged." >&2
        exit 1
    fi
    printf '%s\n' "$filename" >> "${STAGING_DIR}/vendored.txt"
    printf '%s\t%s\n' "$filename" "$url" >> "${STAGING_DIR}/sources.tsv"
done

date -u '+%Y-%m-%dT%H:%M:%SZ' > "${STAGING_DIR}/last-updated.txt"

# Validate all old manifest paths before modifying anything. Never let a
# malformed manifest remove a directory or escape references/.
if [[ -f "${REF_DIR}/vendored.txt" ]]; then
    while IFS= read -r filename; do
        [[ -n "$filename" ]] || continue
        if ! [[ "$filename" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*\.md$ ]]; then
            echo "Error: invalid vendored path: ${filename}" >&2
            exit 1
        fi
    done < "${REF_DIR}/vendored.txt"
fi

if [[ -f "${REF_DIR}/vendored.txt" ]]; then
    while IFS= read -r filename; do
        [[ -n "$filename" ]] || continue
        if ! grep -qxF "$filename" "${STAGING_DIR}/vendored.txt"; then
            rm -f "${REF_DIR}/${filename}"
        fi
    done < "${REF_DIR}/vendored.txt"
fi
for filename in "${STAGING_DIR}"/*.md; do
    mv "$filename" "${REF_DIR}/"
done
for filename in vendored.txt sources.tsv last-updated.txt; do
    mv "${STAGING_DIR}/${filename}" "${REF_DIR}/${filename}"
done
printf 'Updated %s reference pages.\n' "${#PAGES[@]}"
