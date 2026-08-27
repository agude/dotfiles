#!/usr/bin/env bats

setup() {
    TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/skill-portability.XXXXXX")"
    SKILL_CREATOR="${BATS_TEST_DIRNAME}/.."
    SCAFFOLD="${SKILL_CREATOR}/scripts/scaffold.sh"
    VALIDATE="${SKILL_CREATOR}/scripts/validate.sh"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "scaffold emits portable skill and optional Codex metadata" {
    run bash "$SCAFFOLD" sample-skill --scripts --references --assets --codex --dir "$TEST_ROOT"
    [[ "$status" -eq 0 ]]

    SKILL_DIR="$TEST_ROOT/sample-skill"
    [[ -f "$SKILL_DIR/SKILL.md" ]]
    [[ -f "$SKILL_DIR/agents/openai.yaml" ]]
    [[ -d "$SKILL_DIR/scripts" ]]
    [[ -d "$SKILL_DIR/references" ]]
    [[ -d "$SKILL_DIR/assets" ]]
    run grep -q 'CLAUDE_SKILL_DIR' "$SKILL_DIR/SKILL.md"
    [[ "$status" -ne 0 ]]
}

@test "portable skill validates for multiple harness names" {
    run bash "$SCAFFOLD" sample-skill --codex --dir "$TEST_ROOT"
    [[ "$status" -eq 0 ]]
    SKILL_DIR="$TEST_ROOT/sample-skill"

    run bash "$VALIDATE" "$SKILL_DIR"
    [[ "$status" -eq 0 ]]

    run bash "$VALIDATE" --client claude "$SKILL_DIR"
    [[ "$status" -eq 0 ]]

    run bash "$VALIDATE" --client codex "$SKILL_DIR"
    [[ "$status" -eq 0 ]]

    run bash "$VALIDATE" --client future-harness "$SKILL_DIR"
    [[ "$status" -eq 0 ]]
}
