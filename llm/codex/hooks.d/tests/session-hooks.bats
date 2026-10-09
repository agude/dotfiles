#!/usr/bin/env bats

# Tests for Codex session hook shims.
#
# The shims only route each Codex hook to its knowledge-base adapter. The
# adapters' capture behavior is tested in the knowledge-base repository, so
# these tests replace them with stubs and check routing alone: the right
# adapter runs, it receives the hook input unchanged, its exit status
# reaches Codex, and a missing adapter leaves the session unaffected.

export HOOKS_DIR="$BATS_TEST_DIRNAME/.."

EVENTS=(session-start session-prompt session-stop session-end)

setup() {
    export KNOWLEDGE_BASE="$BATS_TEST_TMPDIR/knowledge"
    mkdir -p "$KNOWLEDGE_BASE/scripts/adapters/codex"
}

# install_stub - Write an adapter that records its stdin and identity.
#
# Usage: install_stub EVENT [EXIT_STATUS]
install_stub() {
    local event="$1" status="${2:-0}"
    local stub="$KNOWLEDGE_BASE/scripts/adapters/codex/$event"
    cat > "$stub" <<EOF
#!/usr/bin/env bash
cat > "$BATS_TEST_TMPDIR/$event.stdin"
echo "adapter:$event"
exit $status
EOF
    chmod +x "$stub"
}

@test "each shim runs its own adapter" {
    local event
    for event in "${EVENTS[@]}"; do
        install_stub "$event"
    done
    for event in "${EVENTS[@]}"; do
        run bash -c 'echo "{}" | "$HOOKS_DIR/$1.sh"' _ "$event"
        [[ "$status" -eq 0 ]]
        [[ "$output" == "adapter:$event" ]]
    done
}

@test "each shim passes hook input to the adapter unchanged" {
    local event input="$BATS_TEST_TMPDIR/input.json"
    printf '{"session_id":"s-1","prompt":"caf\xc3\xa9\\n\\ttab"}\n\n' > "$input"
    for event in "${EVENTS[@]}"; do
        install_stub "$event"
        run bash -c '"$HOOKS_DIR/$1.sh" < "$2"' _ "$event" "$input"
        [[ "$status" -eq 0 ]]
        cmp "$input" "$BATS_TEST_TMPDIR/$event.stdin"
    done
}

@test "each shim returns the adapter's exit status" {
    local event
    for event in "${EVENTS[@]}"; do
        install_stub "$event" 3
        run bash -c 'echo "{}" | "$HOOKS_DIR/$1.sh"' _ "$event"
        [[ "$status" -eq 3 ]]
    done
}

@test "each shim returns an empty response when the adapter is missing" {
    local event
    for event in "${EVENTS[@]}"; do
        run bash -c 'echo "{\"session_id\":\"s-1\"}" | "$HOOKS_DIR/$1.sh"' _ "$event"
        [[ "$status" -eq 0 ]]
        [[ "$output" == "{}" ]]
    done
}

@test "each shim returns an empty response when the adapter is not executable" {
    local event
    for event in "${EVENTS[@]}"; do
        install_stub "$event"
        chmod -x "$KNOWLEDGE_BASE/scripts/adapters/codex/$event"
        run bash -c 'echo "{}" | "$HOOKS_DIR/$1.sh"' _ "$event"
        [[ "$status" -eq 0 ]]
        [[ "$output" == "{}" ]]
    done
}

@test "each shim returns an empty response without KNOWLEDGE_BASE" {
    local event
    for event in "${EVENTS[@]}"; do
        install_stub "$event"
        run env -u KNOWLEDGE_BASE bash -c 'echo "{}" | "$HOOKS_DIR/$1.sh"' _ "$event"
        [[ "$status" -eq 0 ]]
        [[ "$output" == "{}" ]]
    done
}
