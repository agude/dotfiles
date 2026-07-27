#!/usr/bin/env bash
# update-references.sh — Fetch the latest Agent Skills docs into references/.
#
# Usage: update-references.sh
#
# Sources:
#   - agentskills.io (the portable Agent Skills specification), discovered
#     through the sitemap
#   - Anthropic's Claude Code and platform docs, which cover the Claude-only
#     extensions to the specification

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: update-references.sh

Fetch the latest Agent Skills docs from agentskills.io and Anthropic.

Discovers agentskills.io pages through the sitemap, fetches each page's .md
variant, and adds Anthropic's Claude Code and platform skill docs. Writes
everything to references/ and records the fetch date in
references/.last-updated.

Only files this script vendored are removed when they disappear upstream;
hand-written files in references/ are left alone.
EOF
}

if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
REF_DIR="${SCRIPT_DIR}/../references"

# Tracks which files this script owns, so hand-written references survive.
MANIFEST="${REF_DIR}/.vendored"

# Anthropic docs, as "url filename" pairs. These cover the Claude Code
# extensions and authoring guidance that agentskills.io does not.
ANTHROPIC_DOCS=(
    "https://code.claude.com/docs/en/skills.md claude-code-skills.md"
    "https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices.md anthropic-best-practices.md"
    "https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview.md anthropic-overview.md"
)

mkdir -p "$REF_DIR"

FETCHED=0
FAILED=()
REFRESHED_FILES=()

# Fetch one markdown page. Leaves no file behind on failure.
fetch_doc() {
    local url="$1"
    local filename="$2"
    local destination="${REF_DIR}/${filename}"

    echo "Fetching ${url} ..."
    if ! curl -sfL "$url" -o "$destination"; then
        rm -f "$destination"
        echo "  Warning: failed to fetch ${url}" >&2
        FAILED+=("$url")
        return
    fi

    if [[ ! -s "$destination" ]]; then
        rm -f "$destination"
        echo "  Warning: empty response from ${url}, removing" >&2
        FAILED+=("$url")
        return
    fi

    FETCHED=$((FETCHED + 1))
    REFRESHED_FILES+=("$filename")
}

# --- agentskills.io, discovered through the sitemap ---

SITEMAP=$(curl -sL "https://agentskills.io/sitemap.xml")
URLS=$(echo "$SITEMAP" | grep -o '<loc>[^<]*' | sed 's/<loc>//')

for url in $URLS; do
    # Extract path: https://agentskills.io/foo/bar -> foo/bar
    path="${url#https://agentskills.io/}"

    # Skip pages not relevant to skill authoring
    case "$path" in
        home|client-implementation*) continue ;;
    esac

    # Convert slashes to hyphens for filename: foo/bar -> foo-bar.md
    fetch_doc "${url}.md" "${path//\//-}.md"
done

# --- Anthropic docs ---

for doc in "${ANTHROPIC_DOCS[@]}"; do
    fetch_doc "${doc% *}" "${doc#* }"
done

# --- Remove vendored files that vanished upstream ---
# Skipped when nothing was fetched, so a network outage can't wipe references/.

REMOVED=()
if [[ $FETCHED -gt 0 && -f "$MANIFEST" ]]; then
    while IFS= read -r previous_file; do
        [[ -n "$previous_file" ]] || continue
        if ! printf '%s\n' "${REFRESHED_FILES[@]}" | grep -qxF "$previous_file"; then
            echo "Removing stale: ${previous_file}"
            rm -f "${REF_DIR}/${previous_file}"
            REMOVED+=("$previous_file")
        fi
    done < "$MANIFEST"
fi

if [[ $FETCHED -gt 0 ]]; then
    printf '%s\n' "${REFRESHED_FILES[@]}" | sort > "$MANIFEST"
    date -Iseconds > "${REF_DIR}/.last-updated"
fi

# --- Summary ---
echo ""
echo "Fetched ${FETCHED} reference file(s) into ${REF_DIR}/"
if [[ ${#REMOVED[@]} -gt 0 ]]; then
    echo "Removed ${#REMOVED[@]} stale file(s): ${REMOVED[*]}"
fi
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "Failed to fetch ${#FAILED[@]} URL(s):"
    for failure in "${FAILED[@]}"; do
        echo "  - $failure"
    done
fi
echo "Last updated: $(cat "${REF_DIR}/.last-updated")"
