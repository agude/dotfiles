#!/usr/bin/env bats

setup() {
    TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/skill-portability.XXXXXX")"
    SKILL_CREATOR="${BATS_TEST_DIRNAME}/.."
    SCAFFOLD="${SKILL_CREATOR}/scripts/scaffold.sh"
    VALIDATE="${SKILL_CREATOR}/scripts/validate.sh"
    export UV_CACHE_DIR="${UV_CACHE_DIR:-/tmp/skill-creator-uv-cache}"
    SKILL_DIR="$TEST_ROOT/sample-skill"
    mkdir "$SKILL_DIR"
    cat > "$SKILL_DIR/SKILL.md" <<'SKILL'
---
name: sample-skill
description: Reconcile invoices when reviewing purchasing records.
---
Compare quantities and prices against purchase orders.
SKILL
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "scaffold creates only requested portable resources and refuses existing paths" {
    run bash "$SCAFFOLD" new-skill --scripts --references --assets --dir "$TEST_ROOT"
    [[ "$status" -eq 0 ]]
    [[ -f "$TEST_ROOT/new-skill/SKILL.md" ]]
    [[ -d "$TEST_ROOT/new-skill/scripts" ]]
    [[ -d "$TEST_ROOT/new-skill/references" ]]
    [[ -d "$TEST_ROOT/new-skill/assets" ]]
    [[ ! -e "$TEST_ROOT/new-skill/agents" ]]
    run bash "$SCAFFOLD" new-skill --dir "$TEST_ROOT"
    [[ "$status" -ne 0 ]]
    ln -s "$TEST_ROOT/missing" "$TEST_ROOT/broken-link"
    run bash "$SCAFFOLD" broken-link --dir "$TEST_ROOT"
    [[ "$status" -ne 0 ]]
    [[ -L "$TEST_ROOT/broken-link" ]]
}

@test "new scaffold requires completion before validation succeeds" {
    run bash "$SCAFFOLD" new-skill --dir "$TEST_ROOT"
    [[ "$status" -eq 0 ]]
    run bash "$VALIDATE" "$TEST_ROOT/new-skill"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"unfinished scaffold"* ]]
}

@test "portable metadata accepts folded and literal YAML strings" {
    for style in '>' '|'; do
        cat > "$SKILL_DIR/SKILL.md" <<SKILL
---
name: sample-skill
description: $style
  Reconcile invoices:
  check purchasing records.
metadata:
  version: "1.0"
---
Compare quantities.
SKILL
        run bash "$VALIDATE" "$SKILL_DIR"
        [[ "$status" -eq 0 ]]
    done
}

@test "reject malformed YAML and missing frontmatter delimiters" {
    printf '%s\n' 'name: sample-skill' 'description: Missing frontmatter' > "$SKILL_DIR/SKILL.md"
    run bash "$VALIDATE" "$SKILL_DIR"
    [[ "$status" -eq 1 ]]
    printf '%s\n' '---' 'name: sample-skill' 'description: No closing delimiter' > "$SKILL_DIR/SKILL.md"
    run bash "$VALIDATE" "$SKILL_DIR"
    [[ "$status" -eq 1 ]]
    printf '%s\n' '---' 'name: sample-skill' 'description: [broken' '---' > "$SKILL_DIR/SKILL.md"
    run bash "$VALIDATE" "$SKILL_DIR"
    [[ "$status" -eq 1 ]]
}

@test "reject duplicate keys and invalid scalar types" {
    for field in 'name: another-name' 'description: null' 'metadata: {version: 1.0}' 'license: [MIT]' 'compatibility: ""'; do
        sed '/^description:/a\
PLACEHOLDER' "$SKILL_DIR/SKILL.md" | sed "s/PLACEHOLDER/$field/" > "$TEST_ROOT/invalid.md"
        cp "$SKILL_DIR/SKILL.md" "$TEST_ROOT/original.md"
        cp "$TEST_ROOT/invalid.md" "$SKILL_DIR/SKILL.md"
        run bash "$VALIDATE" "$SKILL_DIR"
        [[ "$status" -eq 1 ]]
        cp "$TEST_ROOT/original.md" "$SKILL_DIR/SKILL.md"
    done
}

@test "host-specific allowed-tools lists warn without failing" {
    cat > "$SKILL_DIR/SKILL.md" <<'SKILL'
---
name: sample-skill
description: Reconcile invoices when checking purchasing records.
allowed-tools:
  - Read
  - Bash
---
Compare quantities and prices.
SKILL
    run bash "$VALIDATE" "$SKILL_DIR"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"WARN"*"space-separated string"* ]]
}

@test "host description restrictions and API-reserved names warn without failing" {
    for name in claude-example anthropic-example; do
        mkdir "$TEST_ROOT/$name"
        cat > "$TEST_ROOT/$name/SKILL.md" <<SKILL
---
name: $name
description: Reconcile <service> invoices when checking purchasing records.
---
Compare quantities and prices.
SKILL
        run bash "$VALIDATE" "$TEST_ROOT/$name"
        [[ "$status" -eq 0 ]]
        [[ "$output" == *"WARN"*"angle brackets"* ]]
        [[ "$output" == *"WARN"*"Claude API uploads"* ]]
    done
}

@test "UTF-8 BOM and trailing delimiter whitespace are accepted" {
    python3 - "$SKILL_DIR/SKILL.md" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_text(
    '\ufeff--- \t\nname: sample-skill\n'
    'description: Reconcile invoices when checking purchasing records.\n'
    '--- \t\nCompare quantities and prices.\n',
    encoding='utf-8',
)
PY
    run bash "$VALIDATE" "$SKILL_DIR"
    [[ "$status" -eq 0 ]]
}

@test "enforce field lengths and directory matching" {
    python3 - "$SKILL_DIR/SKILL.md" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_text('---\nname: sample-skill\ndescription: "' + 'x' * 1025 + '"\n---\nInstructions\n')
PY
    run bash "$VALIDATE" "$SKILL_DIR"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"1024"* ]]
    printf '%s\n' '---' 'name: wrong-directory' 'description: A valid description.' '---' > "$SKILL_DIR/SKILL.md"
    run bash "$VALIDATE" "$SKILL_DIR"
    [[ "$status" -eq 1 ]]
    [[ "$output" == *"match the skill directory"* ]]
}

@test "size recommendations and extension fields warn without failing" {
    sed '/^description:/a\
model: host-specific' "$SKILL_DIR/SKILL.md" > "$TEST_ROOT/extended.md"
    cp "$TEST_ROOT/extended.md" "$SKILL_DIR/SKILL.md"
    for ((i=0; i<501; i++)); do
        printf '%s\n' 'Instruction text.' >> "$SKILL_DIR/SKILL.md"
    done
    mkdir "$SKILL_DIR/custom-resources"
    run bash "$VALIDATE" "$SKILL_DIR"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"under 500 is recommended"* ]]
    [[ "$output" == *"nonstandard field"* ]]
}

@test "generic creator avoids executable host substitution examples" {
    run grep -n -E '!`|```!|\$ARGUMENTS|\$[0-9]|\$\{CLAUDE_' "$SKILL_CREATOR/SKILL.md"
    [[ "$status" -ne 0 ]]
}

prepare_updater() {
    mkdir -p "$TEST_ROOT/creator/scripts" "$TEST_ROOT/creator/references" "$TEST_ROOT/bin"
    cp "$SKILL_CREATOR/scripts/update-references.sh" "$TEST_ROOT/creator/scripts/"
    REF_DIR="$TEST_ROOT/creator/references"
    printf 'old.md\n' > "$REF_DIR/vendored.txt"
    printf 'old content\n' > "$REF_DIR/old.md"
    printf 'manual content\n' > "$REF_DIR/manual.md"
    printf 'old timestamp\n' > "$REF_DIR/last-updated.txt"
    cat > "$TEST_ROOT/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -eu
url=""
destination=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        https://*) url="$1"; shift ;;
        -o) destination="$2"; shift 2 ;;
        *) shift ;;
    esac
done
if [[ "$url" == *using-scripts.md ]]; then
    case "${FETCH_MODE:-success}" in
        fail) exit 22 ;;
        empty) : > "$destination"; exit 0 ;;
        html) printf '<!DOCTYPE html>\n<html>error</html>\n' > "$destination"; exit 0 ;;
    esac
fi
printf '# Documentation\n\n```html\n<!DOCTYPE html>\n```\n' > "$destination"
CURL
    chmod +x "$TEST_ROOT/bin/curl"
    export PATH="$TEST_ROOT/bin:$PATH"
}

@test "failed empty or HTML fetch preserves the entire old reference set" {
    prepare_updater
    for mode in fail empty html; do
        run env FETCH_MODE="$mode" bash "$TEST_ROOT/creator/scripts/update-references.sh"
        [[ "$status" -eq 1 ]]
        [[ "$(cat "$REF_DIR/old.md")" == 'old content' ]]
        [[ "$(cat "$REF_DIR/vendored.txt")" == 'old.md' ]]
        [[ "$(cat "$REF_DIR/last-updated.txt")" == 'old timestamp' ]]
        [[ ! -e "$REF_DIR/specification.md" ]]
    done
}

@test "successful refresh replaces only owned snapshots and records provenance" {
    prepare_updater
    run bash "$TEST_ROOT/creator/scripts/update-references.sh"
    [[ "$status" -eq 0 ]]
    [[ ! -e "$REF_DIR/old.md" ]]
    [[ -f "$REF_DIR/specification.md" ]]
    [[ "$(cat "$REF_DIR/manual.md")" == 'manual content' ]]
    [[ "$(wc -l < "$REF_DIR/sources.tsv")" -eq 6 ]]
    [[ "$(cat "$REF_DIR/last-updated.txt")" != 'old timestamp' ]]
}

@test "invalid ownership manifest cannot remove files outside references" {
    prepare_updater
    printf '../outside.md\n' > "$REF_DIR/vendored.txt"
    printf 'keep\n' > "$TEST_ROOT/creator/outside.md"
    run bash "$TEST_ROOT/creator/scripts/update-references.sh"
    [[ "$status" -eq 1 ]]
    [[ "$(cat "$TEST_ROOT/creator/outside.md")" == 'keep' ]]
    [[ ! -e "$REF_DIR/specification.md" ]]
}
