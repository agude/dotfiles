#!/usr/bin/env bats

# Tests for Codex session hook shims.
#
# These shims translate between Codex's JSON hook protocol and the
# agent-agnostic core session scripts in the Knowledge repo.

export HOOKS_DIR="$BATS_TEST_DIRNAME/.."
export REPOSITORY_ROOT="$BATS_TEST_DIRNAME/../../../.."

setup() {
    export TEST_CONTENT_DIR="$(mktemp -d)"
    mkdir -p "$TEST_CONTENT_DIR"/{knowledge,observations/{pending,archived},questions/{open,resolved},sources}
    export KB_CONTENT_DIR="$TEST_CONTENT_DIR"
    export SESSION_DIR="$(mktemp -d)"
    chmod 700 "$SESSION_DIR"

    export KNOWLEDGE_BASE="${REPOSITORY_ROOT}/tests/fixtures/knowledge"
    export KNOWLEDGE_OBSERVE=1
}

teardown() {
    [[ -d "$TEST_CONTENT_DIR" ]] && rm -rf "$TEST_CONTENT_DIR"
    [[ -d "$SESSION_DIR" ]] && rm -rf "$SESSION_DIR"
}

# ── SessionStart shim ────────────────────────────────────────────────

@test "codex session-start outputs valid JSON" {
    run bash -c 'echo "{\"session_id\":\"cs-1\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\"}" | "$HOOKS_DIR/session-start.sh"'
    [[ "$status" -eq 0 ]]
    echo "$output" | jq . >/dev/null 2>&1
}

@test "codex session-start includes additionalContext" {
    run bash -c 'echo "{\"session_id\":\"cs-2\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\"}" | "$HOOKS_DIR/session-start.sh"'
    [[ "$status" -eq 0 ]]
    local ctx
    ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // empty')
    [[ -n "$ctx" ]]
}

@test "codex session-start context includes topic areas" {
    run bash -c 'echo "{\"session_id\":\"cs-3\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\"}" | "$HOOKS_DIR/session-start.sh"'
    local ctx
    ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext')
    [[ "$ctx" == *"Topic areas"* ]]
}

@test "codex session-start creates buffer file" {
    run bash -c 'echo "{\"session_id\":\"cs-4\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\"}" | "$HOOKS_DIR/session-start.sh"'
    [[ -f "$SESSION_DIR/session-cs-4.jsonl" ]]
}

@test "codex session-start with KNOWLEDGE_OBSERVE=0 skips buffer" {
    run bash -c 'echo "{\"session_id\":\"cs-off\",\"hook_event_name\":\"SessionStart\",\"source\":\"startup\"}" | KNOWLEDGE_OBSERVE=0 "$HOOKS_DIR/session-start.sh"'
    [[ "$status" -eq 0 ]]
    [[ ! -f "$SESSION_DIR/session-cs-off.jsonl" ]]
    # Should still output context
    echo "$output" | jq . >/dev/null 2>&1
    local ctx
    ctx=$(echo "$output" | jq -r '.hookSpecificOutput.additionalContext // empty')
    [[ -n "$ctx" ]]
}

# ── UserPromptSubmit shim ────────────────────────────────────────────

@test "codex session-prompt outputs valid JSON" {
    touch "$SESSION_DIR/session-cp-1.jsonl"
    run bash -c 'echo "{\"session_id\":\"cp-1\",\"prompt\":\"Hello\"}" | "$HOOKS_DIR/session-prompt.sh"'
    [[ "$status" -eq 0 ]]
    echo "$output" | jq . >/dev/null 2>&1
}

@test "codex session-prompt appends user message to buffer" {
    touch "$SESSION_DIR/session-cp-2.jsonl"
    run bash -c 'echo "{\"session_id\":\"cp-2\",\"prompt\":\"Test prompt\"}" | "$HOOKS_DIR/session-prompt.sh"'
    [[ "$status" -eq 0 ]]
    run cat "$SESSION_DIR/session-cp-2.jsonl"
    [[ "$output" == *'"role":"user"'* ]]
    [[ "$output" == *'"message":"Test prompt"'* ]]
}

@test "codex session-prompt skips when KNOWLEDGE_OBSERVE unset" {
    touch "$SESSION_DIR/session-cp-unset.jsonl"
    run bash -c 'echo "{\"session_id\":\"cp-unset\",\"prompt\":\"Hello\"}" | KNOWLEDGE_OBSERVE= "$HOOKS_DIR/session-prompt.sh"'
    [[ "$status" -eq 0 ]]
    [[ ! -s "$SESSION_DIR/session-cp-unset.jsonl" ]]
}

@test "codex session-prompt no-ops without buffer" {
    run bash -c 'echo "{\"session_id\":\"cp-none\",\"prompt\":\"Hello\"}" | "$HOOKS_DIR/session-prompt.sh"'
    [[ "$status" -eq 0 ]]
    [[ ! -f "$SESSION_DIR/session-cp-none.jsonl" ]]
}

# ── Stop shim ────────────────────────────────────────────────────────

@test "codex session-stop outputs valid JSON" {
    touch "$SESSION_DIR/session-cst-1.jsonl"
    run bash -c 'echo "{\"session_id\":\"cst-1\",\"last_assistant_message\":\"Done\"}" | "$HOOKS_DIR/session-stop.sh"'
    [[ "$status" -eq 0 ]]
    echo "$output" | jq . >/dev/null 2>&1
}

@test "codex session-stop appends assistant message to buffer" {
    touch "$SESSION_DIR/session-cst-2.jsonl"
    run bash -c 'echo "{\"session_id\":\"cst-2\",\"last_assistant_message\":\"Here is the answer\"}" | "$HOOKS_DIR/session-stop.sh"'
    [[ "$status" -eq 0 ]]
    run cat "$SESSION_DIR/session-cst-2.jsonl"
    [[ "$output" == *'"role":"assistant"'* ]]
    [[ "$output" == *'"message":"Here is the answer"'* ]]
}

@test "codex session-stop skips when KNOWLEDGE_OBSERVE unset" {
    touch "$SESSION_DIR/session-cst-unset.jsonl"
    run bash -c 'echo "{\"session_id\":\"cst-unset\",\"last_assistant_message\":\"Done\"}" | KNOWLEDGE_OBSERVE= "$HOOKS_DIR/session-stop.sh"'
    [[ "$status" -eq 0 ]]
    [[ ! -s "$SESSION_DIR/session-cst-unset.jsonl" ]]
}

@test "codex session-stop no-ops without buffer" {
    run bash -c 'echo "{\"session_id\":\"cst-none\",\"last_assistant_message\":\"Done\"}" | "$HOOKS_DIR/session-stop.sh"'
    [[ "$status" -eq 0 ]]
    [[ ! -f "$SESSION_DIR/session-cst-none.jsonl" ]]
}

# ── SessionEnd shim ──────────────────────────────────────────────────

@test "codex session-end outputs valid JSON" {
    touch "$SESSION_DIR/session-ce-1.jsonl"
    run bash -c 'echo "{\"session_id\":\"ce-1\",\"reason\":\"other\"}" | "$HOOKS_DIR/session-end.sh"'
    [[ "$status" -eq 0 ]]
    echo "$output" | jq . >/dev/null 2>&1
}

@test "codex session-end flushes buffer with enough messages" {
    local file="$SESSION_DIR/session-ce-2.jsonl"
    echo '{"role":"user","message":"Q1"}' > "$file"
    echo '{"role":"assistant","message":"A1"}' >> "$file"
    echo '{"role":"user","message":"Q2"}' >> "$file"
    echo '{"role":"assistant","message":"A2"}' >> "$file"

    run bash -c 'echo "{\"session_id\":\"ce-2\",\"reason\":\"other\"}" | "$HOOKS_DIR/session-end.sh"'
    [[ "$status" -eq 0 ]]
    # Flush runs in background; wait for it.
    local tries=0
    while [[ -f "$file" ]] && (( tries < 20 )); do
        sleep 0.2
        tries=$((tries + 1))
    done
    [[ ! -f "$file" ]]
    run bash -c 'ls -1 "$TEST_CONTENT_DIR/observations/pending/"*.md 2>/dev/null | wc -l'
    [[ "$output" -eq 1 ]]
}

@test "codex session-end skips when KNOWLEDGE_OBSERVE unset" {
    local file="$SESSION_DIR/session-ce-unset.jsonl"
    echo '{"role":"user","message":"Q1"}' > "$file"
    echo '{"role":"assistant","message":"A1"}' >> "$file"

    run bash -c 'echo "{\"session_id\":\"ce-unset\",\"reason\":\"other\"}" | KNOWLEDGE_OBSERVE= "$HOOKS_DIR/session-end.sh"'
    [[ "$status" -eq 0 ]]
    # Buffer should still exist (not flushed)
    [[ -f "$file" ]]
}

@test "codex session-end no-ops without buffer" {
    run bash -c 'echo "{\"session_id\":\"ce-none\",\"reason\":\"other\"}" | "$HOOKS_DIR/session-end.sh"'
    [[ "$status" -eq 0 ]]
}

# ── Integration ──────────────────────────────────────────────────────

@test "codex full pipeline creates observation" {
    # SessionStart
    echo '{"session_id":"full-1","source":"startup"}' | "$HOOKS_DIR/session-start.sh" > /dev/null

    # Two turns
    echo '{"session_id":"full-1","prompt":"What is X?"}' | "$HOOKS_DIR/session-prompt.sh" > /dev/null
    echo '{"session_id":"full-1","last_assistant_message":"X is Y."}' | "$HOOKS_DIR/session-stop.sh" > /dev/null
    echo '{"session_id":"full-1","prompt":"And Z?"}' | "$HOOKS_DIR/session-prompt.sh" > /dev/null
    echo '{"session_id":"full-1","last_assistant_message":"Z is W."}' | "$HOOKS_DIR/session-stop.sh" > /dev/null

    # SessionEnd (flush runs in background)
    echo '{"session_id":"full-1","reason":"other"}' | "$HOOKS_DIR/session-end.sh" > /dev/null

    local tries=0
    while [[ -f "$SESSION_DIR/session-full-1.jsonl" ]] && (( tries < 20 )); do
        sleep 0.2
        tries=$((tries + 1))
    done
    [[ ! -f "$SESSION_DIR/session-full-1.jsonl" ]]
    run bash -c 'ls -1 "$TEST_CONTENT_DIR/observations/pending/"*.md 2>/dev/null | wc -l'
    [[ "$output" -eq 1 ]]
}
