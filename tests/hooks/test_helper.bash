# test_helper.bash - Shared setup/teardown for hook bats tests.
#
# Each hook reads JSON from stdin and writes a decision JSON to stdout.
# Helpers here spin up a disposable git repo as the CWD so hooks that call
# `git rev-parse` see a predictable current branch.

setup_repo() {
    export TEST_REPO_DIR="$(mktemp -d)"
    export HOOKS_DIR="$BATS_TEST_DIRNAME/../../llm/coat-tree/hooks.d"

    git -C "$TEST_REPO_DIR" init -q -b main
    git -C "$TEST_REPO_DIR" config user.email "test@test.com"
    git -C "$TEST_REPO_DIR" config user.name "Test"
    touch "$TEST_REPO_DIR/.gitkeep"
    git -C "$TEST_REPO_DIR" add .gitkeep
    git -C "$TEST_REPO_DIR" commit -q -m "init"

    cd "$TEST_REPO_DIR" || return 1
}

teardown_repo() {
    cd /
    if [[ -n "${TEST_REPO_DIR:-}" ]] && [[ -d "$TEST_REPO_DIR" ]]; then
        rm -rf "$TEST_REPO_DIR"
    fi
}

# checkout_branch - Create and switch to a branch in the test repo.
checkout_branch() {
    git checkout -q -b "$1"
}

# run_hook - Invoke a hook with a JSON payload on stdin.
#
# Usage: run_hook <hook-path> <command-string>
# Sets $status and $output like bats' `run` does.
run_hook() {
    local hook="$1"
    local command="$2"
    local payload
    payload=$(printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$command" | jq -Rs .)")
    run bash -c "printf '%s' '$payload' | '$hook'"
}
