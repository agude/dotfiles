#!/usr/bin/env bats

setup() {
    TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/bash-startup.XXXXXX")"
    TEST_HOME="${TEST_ROOT}/home"
    TEST_BIN="${TEST_ROOT}/bin"
    CONTROL_MARKER="${TEST_ROOT}/terminal-control-ran"
    BASHRC="${BATS_TEST_DIRNAME}/../bash/bashrc"
    mkdir -p "$TEST_HOME" "$TEST_BIN"

    cat > "${TEST_BIN}/stty" <<'EOF'
#!/usr/bin/env bash
: > "$CONTROL_MARKER"
EOF
    cat > "${TEST_BIN}/mesg" <<'EOF'
#!/usr/bin/env bash
: > "$CONTROL_MARKER"
EOF
    chmod +x "${TEST_BIN}/stty" "${TEST_BIN}/mesg"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "interactive Bash skips terminal controls without a TTY" {
    run env \
        CONTROL_MARKER="$CONTROL_MARKER" \
        HOME="$TEST_HOME" \
        PATH="${TEST_BIN}:${PATH}" \
        bash --noprofile --norc -i -c 'source "$1"; exit 0' _ "$BASHRC" \
        < /dev/null

    [[ "$status" -eq 0 ]]
    [[ ! -e "$CONTROL_MARKER" ]]
}
