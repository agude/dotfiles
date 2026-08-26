#!/usr/bin/env bats
#
# Exercises llm/opencode/plugin/knowledge.ts against a stub knowledge base.
#
# OpenCode loads plugins lazily, so each test starts `opencode serve` in an
# isolated XDG root and creates a session over HTTP. That covers session
# lifecycle and gating without contacting a model provider. Skipped when
# OpenCode is not installed (CI).

setup() {
    REPOSITORY_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    PLUGIN="${REPOSITORY_ROOT}/llm/opencode/plugin/knowledge.ts"

    OPENCODE_BIN="$(command -v opencode || true)"
    [[ -z "$OPENCODE_BIN" ]] && [[ -x "${HOME}/.opencode/bin/opencode" ]] \
        && OPENCODE_BIN="${HOME}/.opencode/bin/opencode"
    [[ -n "$OPENCODE_BIN" ]] || skip "opencode is not installed"
    command -v curl > /dev/null || skip "curl is not installed"

    TEST_ROOT="$(mktemp -d)"
    export XDG_CONFIG_HOME="${TEST_ROOT}/config"
    export XDG_DATA_HOME="${TEST_ROOT}/data"
    export STUB_KB="${TEST_ROOT}/kb"
    OUT="${STUB_KB}/out"
    SERVER_PID=""

    mkdir -p "${XDG_CONFIG_HOME}/opencode/plugin" "${STUB_KB}/scripts" "$OUT" \
             "${TEST_ROOT}/project"
    ln -s "$PLUGIN" "${XDG_CONFIG_HOME}/opencode/plugin/knowledge.ts"

    create_stub_scripts
}

teardown() {
    stop_server
    if [[ -n "${TEST_ROOT:-}" ]]; then
        rm -rf "$TEST_ROOT"
    fi
}

# Stub scripts record their arguments instead of touching the real knowledge
# base. session-init also creates the buffer, as the real one does.
create_stub_scripts() {
    cat > "${STUB_KB}/scripts/session-init" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${OUT}/init.log"
buffer="${OUT}/session-\$2.jsonl"
touch "\$buffer"
echo "\$buffer"
EOF
    cat > "${STUB_KB}/scripts/session-context" <<EOF
#!/usr/bin/env bash
echo "STUB CONTEXT"
EOF
    for script in session-append session-flush; do
        cat > "${STUB_KB}/scripts/${script}" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${OUT}/${script}.log"
EOF
    done
    chmod +x "${STUB_KB}/scripts/"*
}

start_server() {
    PORT=$(( 39000 + RANDOM % 1000 ))
    (
        cd "${TEST_ROOT}/project" || exit 1
        KNOWLEDGE_BASE="${KB_OVERRIDE:-$STUB_KB}" \
            "$OPENCODE_BIN" serve --port "$PORT" \
            > "${TEST_ROOT}/server.out" 2> "${TEST_ROOT}/server.err"
    ) &
    SERVER_PID=$!

    local waited=0
    until curl -s -m 2 "http://127.0.0.1:${PORT}/session" > /dev/null 2>&1; do
        sleep 1
        waited=$(( waited + 1 ))
        if [[ $waited -gt 30 ]]; then
            echo "server did not start; stdout:" >&2
            cat "${TEST_ROOT}/server.out" >&2
            echo "stderr:" >&2
            cat "${TEST_ROOT}/server.err" >&2
            return 1
        fi
    done
}

stop_server() {
    [[ -n "${SERVER_PID:-}" ]] || return 0
    pkill -TERM -P "$SERVER_PID" 2> /dev/null || true
    kill -TERM "$SERVER_PID" 2> /dev/null || true
    wait "$SERVER_PID" 2> /dev/null || true
    SERVER_PID=""
}

# Creates a session and prints its ID. Pass a parent ID for a child session.
create_session() {
    local body='{}'
    [[ -n "${1:-}" ]] && body="{\"parentID\":\"$1\"}"
    curl -s -m 10 -X POST "http://127.0.0.1:${PORT}/session" \
        -H 'content-type: application/json' -d "$body" \
        | sed -n 's/.*"id":"\([^"]*\)".*/\1/p'
}

@test "captures when KNOWLEDGE_OBSERVE is unset" {
    unset KNOWLEDGE_OBSERVE
    start_server
    session="$(create_session)"
    [[ -n "$session" ]]
    sleep 2
    grep -q -- "--session-id ${session}" "${OUT}/init.log"
}

@test "KNOWLEDGE_OBSERVE=0 disables capture" {
    export KNOWLEDGE_OBSERVE=0
    start_server
    create_session
    sleep 2
    [[ ! -s "${OUT}/init.log" ]]
}

@test "child sessions do not get their own buffer" {
    start_server
    parent="$(create_session)"
    sleep 1
    child="$(create_session "$parent")"
    [[ -n "$child" ]]
    sleep 2
    grep -q -- "--session-id ${parent}" "${OUT}/init.log"
    ! grep -q -- "--session-id ${child}" "${OUT}/init.log"
}

@test "a failing knowledge script warns once on stderr" {
    cat > "${STUB_KB}/scripts/session-init" <<'EOF'
#!/usr/bin/env bash
echo "session-init: cannot create session directory" >&2
exit 1
EOF
    chmod +x "${STUB_KB}/scripts/session-init"
    start_server
    create_session
    sleep 1
    create_session
    sleep 2
    run grep -c "knowledge plugin:.*session-init failed" "${TEST_ROOT}/server.err"
    [ "$output" -eq 1 ]
}

@test "a knowledge base without scripts warns and disables capture" {
    KB_OVERRIDE="${TEST_ROOT}/absent"
    start_server
    create_session
    sleep 2
    grep -q "no scripts/session-init; capture disabled" "${TEST_ROOT}/server.err"
}
