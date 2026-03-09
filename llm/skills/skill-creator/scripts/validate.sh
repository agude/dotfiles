#!/usr/bin/env bash
# validate.sh — Validate a skill directory against the Agent Skills spec.
#
# Usage: validate.sh <skill-directory>
#
# Checks SKILL.md existence, frontmatter fields, naming conventions, and size
# limits. Exits 0 if all checks pass, 1 if any fail.

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: validate.sh <skill-directory>

Validate a skill directory against the Agent Skills specification.

Checks:
  - SKILL.md exists
  - Frontmatter contains name and description
  - name matches directory name
  - name follows naming rules (lowercase, hyphens, 1-64 chars)
  - description is non-empty and ≤1024 characters
  - SKILL.md is ≤500 lines
EOF
}

if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -lt 1 ]]; then
    usage >&2
    exit 1
fi

SKILL_DIR="$1"
FAILURES=0

check() {
    local label="$1"
    local result="$2"  # "pass" or "fail"
    local detail="${3:-}"

    if [[ "$result" == "pass" ]]; then
        echo "PASS  $label"
    else
        echo "FAIL  $label${detail:+: $detail}"
        FAILURES=$((FAILURES + 1))
    fi
}

# --- SKILL.md exists ---

SKILL_MD="${SKILL_DIR}/SKILL.md"
if [[ ! -f "$SKILL_MD" ]]; then
    check "SKILL.md exists" "fail" "not found at ${SKILL_MD}"
    echo ""
    echo "${FAILURES} check(s) failed."
    exit 1
fi
check "SKILL.md exists" "pass"

# --- Extract frontmatter ---
# Frontmatter is between the first two lines matching exactly "---".
# NOTE: Description parsing below only handles plain scalars and YAML folded
# block scalars (>). It does not handle literal block scalars (|) or quoted
# strings. Full YAML parsing in bash isn't practical; these cases are rare in
# skill frontmatter.

FRONTMATTER=$(awk '/^---$/ { count++; if (count==2) exit; if (count==1) next } count==1 { print }' "$SKILL_MD")

# --- name field ---

NAME_VALUE=$(echo "$FRONTMATTER" | grep -E '^name:\s*' | head -1 | sed 's/^name:\s*//' | xargs)
DIR_NAME=$(basename "$SKILL_DIR")

if [[ -z "$NAME_VALUE" ]]; then
    check "frontmatter has name" "fail" "missing"
else
    check "frontmatter has name" "pass"

    # Naming rules
    if [[ ${#NAME_VALUE} -lt 1 || ${#NAME_VALUE} -gt 64 ]]; then
        check "name length (1-64)" "fail" "got ${#NAME_VALUE} chars"
    elif ! [[ "$NAME_VALUE" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
        check "name format" "fail" "'${NAME_VALUE}' must be lowercase alphanumeric and hyphens"
    elif [[ "$NAME_VALUE" == *--* ]]; then
        check "name no consecutive hyphens" "fail" "'${NAME_VALUE}'"
    else
        check "name format" "pass"
    fi

    # name matches directory
    if [[ "$NAME_VALUE" != "$DIR_NAME" ]]; then
        check "name matches directory" "fail" "name='${NAME_VALUE}' dir='${DIR_NAME}'"
    else
        check "name matches directory" "pass"
    fi
fi

# --- description field ---
# Handle both single-line and multi-line (>) YAML descriptions.
# Detect unsupported literal block scalars (|) and give a targeted error.

if echo "$FRONTMATTER" | grep -qE '^description:\s*\|'; then
    check "frontmatter has description" "fail" \
        "literal block scalars (|) are not supported; use folded (>) or inline instead"
    DESC_VALUE=""
else
    DESC_VALUE=$(awk '
        /^description:\s*>/ { multi=1; next }
        /^description:\s*.+/ { gsub(/^description:\s*/, ""); print; found=1; exit }
        multi && /^  / { gsub(/^  /, ""); line = line (line ? " " : "") $0; next }
        multi && !/^  / { print line; found=1; exit }
        END { if (multi && !found) print line }
    ' <<< "$FRONTMATTER")
fi

if [[ -z "$DESC_VALUE" ]]; then
    # Only report "missing" if we didn't already report a more specific error above.
    if ! echo "$FRONTMATTER" | grep -qE '^description:'; then
        check "frontmatter has description" "fail" "missing"
    fi
else
    check "frontmatter has description" "pass"

    DESC_LEN=${#DESC_VALUE}
    if [[ $DESC_LEN -gt 1024 ]]; then
        check "description length (≤1024)" "fail" "got ${DESC_LEN} chars"
    else
        check "description length (≤1024)" "pass"
    fi
fi

# --- Line count ---

LINE_COUNT=$(wc -l < "$SKILL_MD")
if [[ $LINE_COUNT -gt 500 ]]; then
    check "SKILL.md ≤500 lines" "fail" "got ${LINE_COUNT} lines"
else
    check "SKILL.md ≤500 lines" "pass"
fi

# --- {baseDir} line when scripts/ exists (warn only) ---

if [[ -d "${SKILL_DIR}/scripts" ]]; then
    if ! grep -q '{baseDir}' "$SKILL_MD"; then
        echo "WARN  scripts/ exists but SKILL.md does not contain a {baseDir} line"
    fi
fi

# --- Unexpected top-level entries (warn only) ---

EXPECTED_PATTERN="^(SKILL\.md|scripts|references|assets|evals|LICENSE\.txt|LICENSE|\.claude)$"
while IFS= read -r entry; do
    entry_name=$(basename "$entry")
    if ! [[ "$entry_name" =~ $EXPECTED_PATTERN ]]; then
        echo "WARN  unexpected top-level entry: ${entry_name}"
    fi
done < <(find "$SKILL_DIR" -maxdepth 1 -mindepth 1 -exec basename {} \;)

# --- Summary ---

echo ""
if [[ $FAILURES -eq 0 ]]; then
    echo "All checks passed."
    exit 0
else
    echo "${FAILURES} check(s) failed."
    exit 1
fi
