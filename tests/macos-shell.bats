#!/usr/bin/env bats

setup() {
    MACOS_SCRIPT="${BATS_TEST_DIRNAME}/../zsh/zshrc.d/110.macos.zsh"
}

@test "macOS compiler flags remain unique after reload" {
    run env PATH=/usr/bin:/bin PLATFORM=mac CFLAGS='-O2 -g' zsh -f -c '
        source "$1"
        source "$1"
        print -r -- "$CFLAGS"
    ' _ "$MACOS_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ "$output" == "-falign-functions=8 -O2 -g" ]]
}

@test "macOS compiler flags collapse existing duplicates" {
    run env PATH=/usr/bin:/bin PLATFORM=mac \
        CFLAGS='-O2 -falign-functions=8 -g -falign-functions=8' \
        zsh -f -c 'source "$1"; print -r -- "$CFLAGS"' _ "$MACOS_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ "$output" == "-falign-functions=8 -O2 -g" ]]
}

@test "non-macOS compiler flags remain unchanged" {
    run env PATH=/usr/bin:/bin PLATFORM=linux CFLAGS='-O2 -g' \
        zsh -f -c 'source "$1"; print -r -- "$CFLAGS"' _ "$MACOS_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ "$output" == "-O2 -g" ]]
}
