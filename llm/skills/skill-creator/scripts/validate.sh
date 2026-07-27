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

Fails on:
  - SKILL.md missing
  - Frontmatter missing name or description
  - name does not match the directory name
  - name breaks the naming rules (lowercase, hyphens, 1-64 chars)
  - XML tags in name or description
  - description longer than 1024 characters
  - compatibility longer than 500 characters
  - SKILL.md longer than 500 lines

Warns on:
  - Reserved words (claude, anthropic) in name
  - First- or second-person description
  - description with no "when to use" signal
  - description plus when_to_use over the 1536-character listing cap
  - Unrecognized frontmatter keys
  - Unexpected top-level entries
  - scripts/ directory with no ${CLAUDE_SKILL_DIR} line
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

# Spec fields plus the Claude Code extensions. Anything else is likely a typo.
KNOWN_FIELDS="name description license compatibility metadata allowed-tools \
when_to_use argument-hint arguments disable-model-invocation user-invocable \
disallowed-tools model effort context agent background hooks paths shell"

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

warn() {
    echo "WARN  $1"
}

# Read a frontmatter scalar, or print nothing when the field is absent.
# Handles plain values and YAML folded blocks (>). Literal blocks (|) and
# quoted multi-line strings are not supported: full YAML parsing in bash is not
# practical, and those forms are rare in skill frontmatter.
extract_field() {
    local key="$1"

    awk -v key="$key" '
        $0 ~ "^" key ":[ \t]*>" { multi=1; next }
        $0 ~ "^" key ":[ \t]*.+" { sub("^" key ":[ \t]*", ""); print; found=1; exit }
        multi && /^[ \t]+/ { sub(/^[ \t]+/, ""); line = line (line ? " " : "") $0; next }
        multi && !/^[ \t]/ { print line; found=1; exit }
        END { if (multi && !found) print line }
    ' <<< "$FRONTMATTER"
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

FRONTMATTER=$(awk '/^---$/ { count++; if (count==2) exit; if (count==1) next } count==1 { print }' "$SKILL_MD")

# --- name field ---

NAME_VALUE=$(extract_field "name" | xargs)
# Resolve first, so "." and trailing slashes still yield the real directory name.
DIR_NAME=$(basename "$(cd "$SKILL_DIR" && pwd)")

if [[ -z "$NAME_VALUE" ]]; then
    check "frontmatter has name" "fail" "missing"
else
    check "frontmatter has name" "pass"

    # Naming rules
    if [[ ${#NAME_VALUE} -lt 1 || ${#NAME_VALUE} -gt 64 ]]; then
        check "name length (1-64)" "fail" "got ${#NAME_VALUE} chars"
    elif [[ "$NAME_VALUE" == *"<"* || "$NAME_VALUE" == *">"* ]]; then
        check "name has no XML tags" "fail" "'${NAME_VALUE}'"
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

    # The Skills API rejects these outright; Claude Code does not, so warn only.
    if [[ "$NAME_VALUE" == *claude* || "$NAME_VALUE" == *anthropic* ]]; then
        warn "name contains a reserved word (claude/anthropic); the Skills API rejects it"
    fi
fi

# --- description field ---

if grep -qE '^description:[[:space:]]*\|' <<< "$FRONTMATTER"; then
    check "frontmatter has description" "fail" \
        "literal block scalars (|) are not supported; use folded (>) or inline instead"
    DESC_VALUE=""
else
    DESC_VALUE=$(extract_field "description")
fi

if [[ -z "$DESC_VALUE" ]]; then
    # Only report "missing" if we didn't already report a more specific error above.
    if ! grep -qE '^description:' <<< "$FRONTMATTER"; then
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

    if [[ "$DESC_VALUE" == *"<"* || "$DESC_VALUE" == *">"* ]]; then
        check "description has no XML tags" "fail" "remove angle brackets"
    else
        check "description has no XML tags" "pass"
    fi

    # The description is injected into the system prompt, where a mixed point
    # of view degrades matching.
    if [[ "$DESC_VALUE" =~ ^(I|We|You|Your)[[:space:]\'] ]]; then
        warn "description is written in first or second person; use third person"
    fi

    if ! grep -qi 'when' <<< "$DESC_VALUE"; then
        warn "description does not say when to use the skill"
    fi

    # Claude Code truncates description plus when_to_use in the skill listing.
    WHEN_TO_USE_VALUE=$(extract_field "when_to_use")
    LISTING_LEN=$((DESC_LEN + ${#WHEN_TO_USE_VALUE}))
    if [[ $LISTING_LEN -gt 1536 ]]; then
        warn "description plus when_to_use is ${LISTING_LEN} chars; listings truncate at 1536"
    fi
fi

# --- compatibility field length (if present) ---

COMPAT_VALUE=$(extract_field "compatibility" | xargs)
if [[ -n "$COMPAT_VALUE" ]]; then
    COMPAT_LEN=${#COMPAT_VALUE}
    if [[ $COMPAT_LEN -gt 500 ]]; then
        check "compatibility length (≤500)" "fail" "got ${COMPAT_LEN} chars"
    else
        check "compatibility length (≤500)" "pass"
    fi
fi

# --- Unrecognized frontmatter keys (warn only) ---
# Top-level keys only; nested keys under metadata: are indented and skipped.

while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    if ! grep -qw -- "$key" <<< "$KNOWN_FIELDS"; then
        warn "unrecognized frontmatter key: ${key}"
    fi
done < <(grep -oE '^[A-Za-z_][A-Za-z0-9_-]*:' <<< "$FRONTMATTER" | tr -d ':' | sort -u)

# --- Line count ---

LINE_COUNT=$(wc -l < "$SKILL_MD")
if [[ $LINE_COUNT -gt 500 ]]; then
    check "SKILL.md ≤500 lines" "fail" "got ${LINE_COUNT} lines"
else
    check "SKILL.md ≤500 lines" "pass"
fi

# --- ${CLAUDE_SKILL_DIR} line when scripts/ exists (warn only) ---

if [[ -d "${SKILL_DIR}/scripts" ]]; then
    # shellcheck disable=SC2016
    if ! grep -q '${CLAUDE_SKILL_DIR}' "$SKILL_MD"; then
        warn "scripts/ exists but SKILL.md does not contain a \${CLAUDE_SKILL_DIR} line"
    fi
fi

# --- Unexpected top-level entries (warn only) ---

EXPECTED_PATTERN="^(SKILL\.md|scripts|references|assets|tests|evals|LICENSE\.txt|LICENSE|\.claude)$"
while IFS= read -r entry; do
    entry_name=$(basename "$entry")
    if ! [[ "$entry_name" =~ $EXPECTED_PATTERN ]]; then
        warn "unexpected top-level entry: ${entry_name}"
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
