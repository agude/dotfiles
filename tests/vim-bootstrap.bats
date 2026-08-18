#!/usr/bin/env bats

setup() {
    TEST_ROOT="$(mktemp -d "${BATS_TEST_TMPDIR}/vim-bootstrap.XXXXXX")"
    TEST_HOME="${TEST_ROOT}/home"
    TEST_BIN="${TEST_ROOT}/bin"
    CALLS="${TEST_ROOT}/calls"
    BOOTSTRAP_SCRIPT="${BATS_TEST_DIRNAME}/../bin/bootstrap-vim-plugins.sh"
    mkdir -p "$TEST_HOME" "$TEST_BIN" "$CALLS"

    cat > "${TEST_BIN}/curl" <<'EOF'
#!/usr/bin/env bash
output=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) output="$2"; shift 2 ;;
        *) shift ;;
    esac
done
printf 'vim-plug fixture\n' > "$output"
printf 'curl\n' > "${CALLS}/curl"
EOF

    cat > "${TEST_BIN}/nvim" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "${CALLS}/nvim"
EOF
    chmod +x "${TEST_BIN}/curl" "${TEST_BIN}/nvim"
}

teardown() {
    rm -rf "$TEST_ROOT"
}

@test "plugin bootstrap downloads vim-plug and synchronizes plugins" {
    run env \
        CALLS="$CALLS" \
        HOME="$TEST_HOME" \
        PATH="${TEST_BIN}:/usr/bin:/bin" \
        bash "$BOOTSTRAP_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ -f "${TEST_HOME}/.vim/autoload/plug.vim" ]]
    grep -Fxq 'vim-plug fixture' "${TEST_HOME}/.vim/autoload/plug.vim"
    [[ -f "${CALLS}/curl" ]]
    [[ "$(cat "${CALLS}/nvim")" == *"+PlugInstall --sync"* ]]
}
