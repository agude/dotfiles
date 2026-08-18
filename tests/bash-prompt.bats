#!/usr/bin/env bats

setup() {
    TEST_HOME="$(mktemp -d "${BATS_TEST_TMPDIR}/bash-prompt.XXXXXX")"
    HISTORY_SCRIPT="${BATS_TEST_DIRNAME}/../bash/bashrc.d/002.history.bash"
    PROMPT_SCRIPT="${BATS_TEST_DIRNAME}/../bash/bashrc.d/107.prompt.bash"
}

teardown() {
    rm -rf "$TEST_HOME"
}

@test "Bash prompt hooks remain unique after reload" {
    run env \
        HOME="$TEST_HOME" \
        TERM=dumb \
        bash --noprofile --norc -c '
            PROMPT_COMMAND=third_party_hook
            source "$1"
            source "$2"
            source "$1"
            source "$2"
            printf "%s" "$PROMPT_COMMAND"
        ' _ "$HISTORY_SCRIPT" "$PROMPT_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ "$output" == "build_prompt; history -a; third_party_hook" ]]
}

@test "Bash prompt preserves status and third-party hooks" {
    run env \
        HOME="$TEST_HOME" \
        TERM=dumb \
        bash --noprofile --norc -c '
            third_party_count=0
            third_party_hook() {
                third_party_count=$((third_party_count + 1))
            }
            PROMPT_COMMAND=third_party_hook
            source "$1"
            source "$2"
            false
            eval "$PROMPT_COMMAND"
            printf "%s\n%s" "$third_party_count" "$PS1"
        ' _ "$HISTORY_SCRIPT" "$PROMPT_SCRIPT"

    [[ "$status" -eq 0 ]]
    [[ "${lines[0]}" == "1" ]]
    [[ "${lines[1]}" == *"exit: 1"* ]]
}
