#!/usr/bin/env bats

setup() {
    TEST_HOME="$(mktemp -d "${BATS_TEST_TMPDIR}/bin-subdirs.XXXXXX")"
    mkdir -p "${TEST_HOME}/bin"
    BASH_SCRIPT="${BATS_TEST_DIRNAME}/../bash/bashrc.d/003.bin_subdirs.bash"
    ZSH_SCRIPT="${BATS_TEST_DIRNAME}/../zsh/zshrc.d/003.bin_subdirs.zsh"
}

teardown() {
    rm -rf "$TEST_HOME"
}

@test "Bash bin module parses without extglob" {
    run bash --noprofile --norc -O extglob -c 'shopt -u extglob; bash -n "$1"' _ "$BASH_SCRIPT"

    [[ "$status" -eq 0 ]]
}

@test "Bash bin module preserves disabled nullglob" {
    run env HOME="$TEST_HOME" bash --noprofile --norc -c '
        PATH=/usr/bin
        shopt -u nullglob
        source "$1"
        shopt -q nullglob
        printf "%s\n%s" "$?" "$PATH"
    ' _ "$BASH_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ "${lines[0]}" == "1" ]]
    [[ "${lines[1]}" == "/usr/bin" ]]
}

@test "Bash bin module preserves enabled nullglob and deduplicates PATH" {
    mkdir -p "${TEST_HOME}/bin/alpha" "${TEST_HOME}/bin/beta" "${TEST_HOME}/bin/.hidden"

    run env HOME="$TEST_HOME" bash --noprofile --norc -c '
        PATH=/usr/bin
        shopt -s nullglob dotglob
        source "$1"
        source "$1"
        shopt -q nullglob
        printf "%s\n%s" "$?" "$PATH"
    ' _ "$BASH_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ "${lines[0]}" == "0" ]]
    [[ "${lines[1]}" == "${TEST_HOME}/bin/beta:${TEST_HOME}/bin/alpha:/usr/bin" ]]
}

@test "Zsh bin module handles an empty directory" {
    run env HOME="$TEST_HOME" zsh -f -c '
        PATH=/usr/bin
        source "$1"
        print -r -- "$PATH"
    ' _ "$ZSH_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ "$output" == "/usr/bin" ]]
}

@test "Zsh bin module excludes hidden directories and deduplicates PATH" {
    mkdir -p "${TEST_HOME}/bin/alpha" "${TEST_HOME}/bin/beta" "${TEST_HOME}/bin/.hidden"

    run env HOME="$TEST_HOME" zsh -f -c '
        PATH=/usr/bin
        source "$1"
        source "$1"
        print -r -- "$PATH"
    ' _ "$ZSH_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ "$output" == "${TEST_HOME}/bin/beta:${TEST_HOME}/bin/alpha:/usr/bin" ]]
}
