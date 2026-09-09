#!/usr/bin/env bats

setup() {
    TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/pi-bootstrap.XXXXXX")"
    TEST_BIN="${TEST_ROOT}/bin"
    CALLS="${TEST_ROOT}/calls"
    BOOTSTRAP_SCRIPT="${BATS_TEST_DIRNAME}/../bin/bootstrap-pi-packages.sh"
    mkdir -p "$TEST_BIN" "$CALLS"

    cat > "${TEST_BIN}/pi" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${CALLS}/pi"
EOF
    chmod +x "${TEST_BIN}/pi"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "Pi bootstrap installs every pinned package" {
    run env \
        CALLS="$CALLS" \
        PATH="${TEST_BIN}:/usr/bin:/bin" \
        bash "$BOOTSTRAP_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ "$(cat "${CALLS}/pi")" == "install npm:pi-web-access@0.28.0" ]]
}

@test "Pi bootstrap fails clearly without Pi" {
    run env PATH="/usr/bin:/bin" bash "$BOOTSTRAP_SCRIPT"

    [[ "$status" -ne 0 ]]
    [[ "$output" == *"Pi is required"* ]]
}
