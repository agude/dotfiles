#!/usr/bin/env bats

# Tests for Claude Code session hook shims.
#
# These shims translate between Claude Code's coat-tree hook protocol
# and the agent-agnostic core session scripts in the Knowledge repo.

export HOOKS_DIR="$BATS_TEST_DIRNAME/.."

setup() {
    export TEST_CONTENT_DIR="$(mktemp -d)"
    mkdir -p "$TEST_CONTENT_DIR"/{knowledge,observations/{pending,archived},questions/{open,resolved},sources}
    export KB_CONTENT_DIR="$TEST_CONTENT_DIR"
    export SESSION_DIR="$(mktemp -d)"
    chmod 700 "$SESSION_DIR"

    # CLAUDE_ENV_FILE: Claude Code writes env vars here to propagate them.
    export CLAUDE_ENV_FILE="$(mktemp)"

    # Init git repo (needed for observe/commit)
    git -C "$TEST_CONTENT_DIR" init -q
    git -C "$TEST_CONTENT_DIR" config user.email "test@test.com"
    git -C "$TEST_CONTENT_DIR" config user.name "Test"
    touch "$TEST_CONTENT_DIR/.gitkeep"
    git -C "$TEST_CONTENT_DIR" add .gitkeep
    git -C "$TEST_CONTENT_DIR" commit -q -m "init"

    # KNOWLEDGE_BASE must point to the Knowledge repo root.
    if [[ -z "${KNOWLEDGE_BASE:-}" ]] || [[ ! -d "$KNOWLEDGE_BASE/scripts" ]]; then
        skip "KNOWLEDGE_BASE not set or missing scripts/"
    fi
    export KNOWLEDGE_BASE
}

teardown() {
    [[ -d "$TEST_CONTENT_DIR" ]] && rm -rf "$TEST_CONTENT_DIR"
    [[ -d "$SESSION_DIR" ]] && rm -rf "$SESSION_DIR"
    [[ -f "$CLAUDE_ENV_FILE" ]] && rm -f "$CLAUDE_ENV_FILE"
}

# ── SessionStart shim ────────────────────────────────────────────────

@test "claude session-start outputs plain text" {
    run bash -c 'echo "{\"session_id\":\"s-1\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\"}" | "$HOOKS_DIR/SessionStart/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
    # Must NOT be JSON — plain text context injection
    ! echo "$output" | jq . >/dev/null 2>&1 || [[ "$output" != "{"* ]]
}

@test "claude session-start context includes topic areas" {
    run bash -c 'echo "{\"session_id\":\"s-2\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\"}" | "$HOOKS_DIR/SessionStart/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Topic areas"* ]]
}

@test "claude session-start sets KNOWLEDGE_OBSERVE=1 in CLAUDE_ENV_FILE" {
    echo '{"session_id":"s-3","hook_event_name":"SessionStart","source":"startup"}' \
        | "$HOOKS_DIR/SessionStart/010.knowledge.sh" > /dev/null
    grep -q "KNOWLEDGE_OBSERVE=1" "$CLAUDE_ENV_FILE"
}

@test "claude session-start sets KNOWLEDGE_SESSION_FILE in CLAUDE_ENV_FILE" {
    echo '{"session_id":"s-4","hook_event_name":"SessionStart","source":"startup"}' \
        | "$HOOKS_DIR/SessionStart/010.knowledge.sh" > /dev/null
    grep -q "KNOWLEDGE_SESSION_FILE=" "$CLAUDE_ENV_FILE"
    # The path should contain the session id
    grep "KNOWLEDGE_SESSION_FILE=" "$CLAUDE_ENV_FILE" | grep -q "s-4"
}

@test "claude session-start creates buffer file" {
    echo '{"session_id":"s-5","hook_event_name":"SessionStart","source":"startup"}' \
        | "$HOOKS_DIR/SessionStart/010.knowledge.sh" > /dev/null
    [[ -f "$SESSION_DIR/session-s-5.jsonl" ]]
}

@test "claude session-start with KNOWLEDGE_OBSERVE=0 writes KNOWLEDGE_OBSERVE=0" {
    run bash -c 'echo "{\"session_id\":\"s-off\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\"}" | KNOWLEDGE_OBSERVE=0 "$HOOKS_DIR/SessionStart/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
    # Should NOT create buffer
    [[ ! -f "$SESSION_DIR/session-s-off.jsonl" ]]
    # Should still output context
    [[ "$output" == *"Topic areas"* ]]
    # Should propagate the opt-out
    grep -q "KNOWLEDGE_OBSERVE=0" "$CLAUDE_ENV_FILE"
}

@test "claude session-start always outputs context even on init failure" {
    # Make session dir unwritable to force init failure
    chmod 000 "$SESSION_DIR"
    run bash -c 'echo "{\"session_id\":\"s-fail\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\"}" | "$HOOKS_DIR/SessionStart/010.knowledge.sh"'
    chmod 700 "$SESSION_DIR"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"Topic areas"* ]]
}

# ── UserPromptSubmit shim ────────────────────────────────────────────

@test "claude session-prompt exits 0" {
    touch "$SESSION_DIR/session-p-1.jsonl"
    export KNOWLEDGE_OBSERVE=1
    export KNOWLEDGE_SESSION_FILE="$SESSION_DIR/session-p-1.jsonl"
    run bash -c 'echo "{\"session_id\":\"p-1\",\"prompt\":\"Hello\"}" | "$HOOKS_DIR/UserPromptSubmit/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
}

@test "claude session-prompt appends user message to buffer" {
    touch "$SESSION_DIR/session-p-2.jsonl"
    export KNOWLEDGE_OBSERVE=1
    export KNOWLEDGE_SESSION_FILE="$SESSION_DIR/session-p-2.jsonl"
    echo '{"session_id":"p-2","prompt":"Test prompt"}' \
        | "$HOOKS_DIR/UserPromptSubmit/010.knowledge.sh"
    run cat "$SESSION_DIR/session-p-2.jsonl"
    [[ "$output" == *'"role":"user"'* ]]
    [[ "$output" == *'"message":"Test prompt"'* ]]
}

@test "claude session-prompt skips when KNOWLEDGE_OBSERVE=0" {
    touch "$SESSION_DIR/session-p-3.jsonl"
    export KNOWLEDGE_OBSERVE=0
    run bash -c 'echo "{\"session_id\":\"p-3\",\"prompt\":\"Hello\"}" | "$HOOKS_DIR/UserPromptSubmit/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
    # Buffer should be empty
    [[ ! -s "$SESSION_DIR/session-p-3.jsonl" ]]
}

@test "claude session-prompt proceeds when KNOWLEDGE_OBSERVE unset" {
    touch "$SESSION_DIR/session-p-unset.jsonl"
    unset KNOWLEDGE_OBSERVE
    run bash -c 'echo "{\"session_id\":\"p-unset\",\"prompt\":\"Hello\"}" | KNOWLEDGE_SESSION_FILE="$SESSION_DIR/session-p-unset.jsonl" "$HOOKS_DIR/UserPromptSubmit/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
    [[ -s "$SESSION_DIR/session-p-unset.jsonl" ]]
}

@test "claude session-prompt no-ops without buffer file" {
    export KNOWLEDGE_OBSERVE=1
    unset KNOWLEDGE_SESSION_FILE
    run bash -c 'echo "{\"session_id\":\"p-none\",\"prompt\":\"Hello\"}" | "$HOOKS_DIR/UserPromptSubmit/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
    [[ ! -f "$SESSION_DIR/session-p-none.jsonl" ]]
}

# ── Stop shim ────────────────────────────────────────────────────────

@test "claude session-stop exits 0" {
    touch "$SESSION_DIR/session-st-1.jsonl"
    export KNOWLEDGE_OBSERVE=1
    export KNOWLEDGE_SESSION_FILE="$SESSION_DIR/session-st-1.jsonl"
    run bash -c 'echo "{\"session_id\":\"st-1\",\"last_assistant_message\":\"Done\"}" | "$HOOKS_DIR/Stop/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
}

@test "claude session-stop appends assistant message to buffer" {
    touch "$SESSION_DIR/session-st-2.jsonl"
    export KNOWLEDGE_OBSERVE=1
    export KNOWLEDGE_SESSION_FILE="$SESSION_DIR/session-st-2.jsonl"
    echo '{"session_id":"st-2","last_assistant_message":"Here is the answer"}' \
        | "$HOOKS_DIR/Stop/010.knowledge.sh"
    run cat "$SESSION_DIR/session-st-2.jsonl"
    [[ "$output" == *'"role":"assistant"'* ]]
    [[ "$output" == *'"message":"Here is the answer"'* ]]
}

@test "claude session-stop skips when KNOWLEDGE_OBSERVE=0" {
    touch "$SESSION_DIR/session-st-3.jsonl"
    export KNOWLEDGE_OBSERVE=0
    run bash -c 'echo "{\"session_id\":\"st-3\",\"last_assistant_message\":\"Done\"}" | "$HOOKS_DIR/Stop/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
    [[ ! -s "$SESSION_DIR/session-st-3.jsonl" ]]
}

@test "claude session-stop proceeds when KNOWLEDGE_OBSERVE unset" {
    touch "$SESSION_DIR/session-st-unset.jsonl"
    unset KNOWLEDGE_OBSERVE
    run bash -c 'echo "{\"session_id\":\"st-unset\",\"last_assistant_message\":\"Done\"}" | KNOWLEDGE_SESSION_FILE="$SESSION_DIR/session-st-unset.jsonl" "$HOOKS_DIR/Stop/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
    [[ -s "$SESSION_DIR/session-st-unset.jsonl" ]]
}

@test "claude session-stop no-ops without buffer file" {
    export KNOWLEDGE_OBSERVE=1
    unset KNOWLEDGE_SESSION_FILE
    run bash -c 'echo "{\"session_id\":\"st-none\",\"last_assistant_message\":\"Done\"}" | "$HOOKS_DIR/Stop/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
    [[ ! -f "$SESSION_DIR/session-st-none.jsonl" ]]
}

# ── SessionEnd shim ──────────────────────────────────────────────────

@test "claude session-end exits 0" {
    touch "$SESSION_DIR/session-e-1.jsonl"
    export KNOWLEDGE_OBSERVE=1
    run bash -c 'echo "{\"session_id\":\"e-1\",\"reason\":\"other\"}" | "$HOOKS_DIR/SessionEnd/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
}

@test "claude session-end flushes buffer with enough messages" {
    local file="$SESSION_DIR/session-e-2.jsonl"
    echo '{"role":"user","message":"Q1"}' > "$file"
    echo '{"role":"assistant","message":"A1"}' >> "$file"
    echo '{"role":"user","message":"Q2"}' >> "$file"
    echo '{"role":"assistant","message":"A2"}' >> "$file"

    export KNOWLEDGE_OBSERVE=1
    run bash -c 'echo "{\"session_id\":\"e-2\",\"reason\":\"other\"}" | "$HOOKS_DIR/SessionEnd/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
    [[ ! -f "$file" ]]
    run bash -c 'ls -1 "$TEST_CONTENT_DIR/observations/pending/"*.md 2>/dev/null | wc -l'
    [[ "$output" -eq 1 ]]
}

@test "claude session-end skips when KNOWLEDGE_OBSERVE=0" {
    local file="$SESSION_DIR/session-e-3.jsonl"
    echo '{"role":"user","message":"Q1"}' > "$file"
    echo '{"role":"assistant","message":"A1"}' >> "$file"

    export KNOWLEDGE_OBSERVE=0
    run bash -c 'echo "{\"session_id\":\"e-3\",\"reason\":\"other\"}" | "$HOOKS_DIR/SessionEnd/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
    # Buffer should still exist (not flushed)
    [[ -f "$file" ]]
}

@test "claude session-end proceeds when KNOWLEDGE_OBSERVE unset" {
    local file="$SESSION_DIR/session-e-unset.jsonl"
    echo '{"role":"user","message":"Q1"}' > "$file"
    echo '{"role":"assistant","message":"A1"}' >> "$file"
    echo '{"role":"user","message":"Q2"}' >> "$file"
    echo '{"role":"assistant","message":"A2"}' >> "$file"

    unset KNOWLEDGE_OBSERVE
    run bash -c 'echo "{\"session_id\":\"e-unset\",\"reason\":\"other\"}" | KNOWLEDGE_SESSION_FILE="$file" "$HOOKS_DIR/SessionEnd/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
    # Buffer should have been flushed
    [[ ! -f "$file" ]]
}

@test "claude session-end no-ops without buffer" {
    export KNOWLEDGE_OBSERVE=1
    run bash -c 'echo "{\"session_id\":\"e-none\",\"reason\":\"other\"}" | "$HOOKS_DIR/SessionEnd/010.knowledge.sh"'
    [[ "$status" -eq 0 ]]
}

# ── Integration ──────────────────────────────────────────────────────

@test "claude full pipeline creates observation" {
    # SessionStart
    local start_output
    start_output=$(echo '{"session_id":"full-1","source":"startup"}' | "$HOOKS_DIR/SessionStart/010.knowledge.sh")

    # Source the env file to get KNOWLEDGE_OBSERVE and KNOWLEDGE_SESSION_FILE
    source "$CLAUDE_ENV_FILE"

    # Two turns
    echo '{"session_id":"full-1","prompt":"What is X?"}' | "$HOOKS_DIR/UserPromptSubmit/010.knowledge.sh"
    echo '{"session_id":"full-1","last_assistant_message":"X is Y."}' | "$HOOKS_DIR/Stop/010.knowledge.sh"
    echo '{"session_id":"full-1","prompt":"And Z?"}' | "$HOOKS_DIR/UserPromptSubmit/010.knowledge.sh"
    echo '{"session_id":"full-1","last_assistant_message":"Z is W."}' | "$HOOKS_DIR/Stop/010.knowledge.sh"

    # SessionEnd
    echo '{"session_id":"full-1","reason":"other"}' | "$HOOKS_DIR/SessionEnd/010.knowledge.sh"

    [[ ! -f "$SESSION_DIR/session-full-1.jsonl" ]]
    run bash -c 'ls -1 "$TEST_CONTENT_DIR/observations/pending/"*.md 2>/dev/null | wc -l'
    [[ "$output" -eq 1 ]]
}
