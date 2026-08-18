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

@test "XDG declarations do not create directories" {
    run env -u RIPGREP_CONFIG_PATH \
        HOME="$TEST_HOME" \
        PLATFORM=linux \
        XDG_CONFIG_HOME="${TEST_HOME}/.config" \
        bash -c 'source "$1"; find "$HOME" -mindepth 1 -print -quit' \
        _ "$XDG_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "Bash and Zsh receive identical XDG declarations" {
    run env \
        -u XDG_CACHE_HOME \
        -u XDG_DATA_HOME \
        -u XDG_STATE_HOME \
        -u RIPGREP_CONFIG_PATH \
        HOME="$TEST_HOME" \
        PLATFORM=linux \
        XDG_CONFIG_HOME="${TEST_HOME}/.config" \
        bash -c '
            source "$1"
            printf "%s\n" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" \
                "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$IPYTHONDIR" \
                "$GIMP2_DIRECTORY" "$GNUPGHOME"
        ' _ "$XDG_SCRIPT"
    [[ "$status" -eq 0 ]]
    bash_output="$output"

    run env \
        -u XDG_CACHE_HOME \
        -u XDG_DATA_HOME \
        -u XDG_STATE_HOME \
        -u RIPGREP_CONFIG_PATH \
        HOME="$TEST_HOME" \
        PLATFORM=linux \
        XDG_CONFIG_HOME="${TEST_HOME}/.config" \
        zsh -f -c '
            source "$1"
            printf "%s\n" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" \
                "$XDG_STATE_HOME" "$XDG_CACHE_HOME" "$IPYTHONDIR" \
                "$GIMP2_DIRECTORY" "$GNUPGHOME"
        ' _ "$XDG_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ "$output" == "$bash_output" ]]
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
