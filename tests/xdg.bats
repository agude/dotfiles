#!/usr/bin/env bats

setup() {
    TEST_HOME="$(mktemp -d "${BATS_TEST_TMPDIR}/xdg.XXXXXX")"
    XDG_SCRIPT="${BATS_TEST_DIRNAME}/../shared/sharedrc.d/001.xdg_base_directory.sh"
}

teardown() {
    rm -rf "$TEST_HOME"
}

run_xdg() {
    run env -u RIPGREP_CONFIG_PATH \
        HOME="$TEST_HOME" \
        PLATFORM=linux \
        XDG_CONFIG_HOME="${TEST_HOME}/.config" \
        bash -c 'source "$1"; printf "%s" "${RIPGREP_CONFIG_PATH+x}"' \
        _ "$XDG_SCRIPT"
}

@test "shell startup leaves missing ripgrep config unset" {
    run_xdg

    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "shell startup exports an existing ripgrep config" {
    mkdir -p "${TEST_HOME}/.config/ripgrep"
    : > "${TEST_HOME}/.config/ripgrep/config"

    run_xdg

    [[ "$status" -eq 0 ]]
    [[ "$output" == "x" ]]
}

@test "shell reload clears a removed default ripgrep config" {
    mkdir -p "${TEST_HOME}/.config/ripgrep"
    : > "${TEST_HOME}/.config/ripgrep/config"

    run env -u RIPGREP_CONFIG_PATH \
        HOME="$TEST_HOME" \
        PLATFORM=linux \
        XDG_CONFIG_HOME="${TEST_HOME}/.config" \
        bash -c 'source "$1"; rm "$2"; source "$1"; printf "%s" "${RIPGREP_CONFIG_PATH+x}"' \
        _ "$XDG_SCRIPT" "${TEST_HOME}/.config/ripgrep/config"

    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "shell startup preserves a custom ripgrep config path" {
    run env \
        HOME="$TEST_HOME" \
        PLATFORM=linux \
        RIPGREP_CONFIG_PATH="${TEST_HOME}/custom-ripgrep.conf" \
        XDG_CONFIG_HOME="${TEST_HOME}/.config" \
        bash -c 'source "$1"; printf "%s" "$RIPGREP_CONFIG_PATH"' \
        _ "$XDG_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ "$output" == "${TEST_HOME}/custom-ripgrep.conf" ]]
}
