#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../PreToolUse/010.git-guard.sh"

run_hook() {
    jq -cn --arg command "$1" '{tool_input: {command: $command}}' |
        bash "$HOOK"
}

# --- Should block ---

@test "blocks git commit --no-verify" {
    run run_hook "git commit --no-verify -m test"
    [ "$status" -eq 2 ]
}

@test "blocks git commit -n" {
    run run_hook "git commit -n -m test"
    [ "$status" -eq 2 ]
}

@test "blocks git merge -n" {
    run run_hook "git merge -n feature"
    [ "$status" -eq 2 ]
}

@test "blocks git revert -n" {
    run run_hook "git revert -n HEAD"
    [ "$status" -eq 2 ]
}

@test "blocks git cherry-pick -n" {
    run run_hook "git cherry-pick -n abc123"
    [ "$status" -eq 2 ]
}

@test "blocks git am -n" {
    run run_hook "git am -n < patch"
    [ "$status" -eq 2 ]
}

@test "blocks --no-gpg-sign" {
    run run_hook "git commit --no-gpg-sign -m test"
    [ "$status" -eq 2 ]
}

@test "blocks -c commit.gpgsign=false" {
    run run_hook "git -c commit.gpgsign=false commit -m test"
    [ "$status" -eq 2 ]
}

@test "blocks --no-verify on push" {
    run run_hook "git push --no-verify"
    [ "$status" -eq 2 ]
}

@test "blocks bypass after an environment prefix" {
    run run_hook "env CI=1 git commit --no-verify -m test"
    [ "$status" -eq 2 ]
}

@test "blocks bypass in a chained command" {
    run run_hook "printf ready && git commit --no-verify -m test"
    [ "$status" -eq 2 ]
}

# --- Should allow ---

@test "allows git log -n 5" {
    run run_hook "git log -n 5"
    [ "$status" -eq 0 ]
}

@test "allows git clean -n" {
    run run_hook "git clean -n"
    [ "$status" -eq 0 ]
}

@test "allows git fetch -n" {
    run run_hook "git fetch -n origin"
    [ "$status" -eq 0 ]
}

@test "allows normal git commit" {
    run run_hook "git commit -m test"
    [ "$status" -eq 0 ]
}

@test "allows non-git commands" {
    run run_hook "echo hello"
    [ "$status" -eq 0 ]
}

@test "allows git diff" {
    run run_hook "git diff HEAD"
    [ "$status" -eq 0 ]
}

@test "allows bypass text inside a commit message" {
    run run_hook "git commit -m 'Document --no-verify behavior'"
    [ "$status" -eq 0 ]
}

@test "allows bypass text inside a heredoc body" {
    command=$'git commit -F - <<\'EOF\'\nDocument --no-verify behavior\nEOF'
    run run_hook "$command"
    [ "$status" -eq 0 ]
}
