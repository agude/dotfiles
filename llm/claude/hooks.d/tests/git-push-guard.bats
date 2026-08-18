#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../PreToolUse/020.git-push-guard.sh"

run_hook() {
    jq -cn --arg command "$1" '{tool_input: {command: $command}}' |
        bash "$HOOK"
}

deny_reason() {
    printf '%s\n' "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null
}

decision() {
    printf '%s\n' "$output" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null
}

# --- Should block ---

@test "blocks force push with --force" {
    run run_hook "git push --force origin feature"
    [ "$(decision)" = "deny" ]
}

@test "blocks force push with -f" {
    run run_hook "git push -f origin feature"
    [ "$(decision)" = "deny" ]
}

@test "blocks force-with-lease" {
    run run_hook "git push --force-with-lease origin feature"
    [ "$(decision)" = "deny" ]
}

@test "blocks push to main (no refspec, on main)" {
    # Mock git rev-parse to return "main"
    git() { echo "main"; }
    export -f git
    run run_hook "git push origin"
    [ "$(decision)" = "deny" ]
    unset -f git
}

@test "blocks push to master (no refspec, on master)" {
    git() { echo "master"; }
    export -f git
    run run_hook "git push origin"
    [ "$(decision)" = "deny" ]
    unset -f git
}

@test "blocks git push origin HEAD when on main" {
    git() { echo "main"; }
    export -f git
    run run_hook "git push origin HEAD"
    [ "$(decision)" = "deny" ]
    unset -f git
}

@test "blocks git push origin main" {
    run run_hook "git push origin main"
    [ "$(decision)" = "deny" ]
}

@test "blocks force push through a plus refspec" {
    run run_hook "git push origin +feature:feature"
    [ "$(decision)" = "deny" ]
}

@test "blocks fully qualified main destination" {
    run run_hook "git push origin feature:refs/heads/main"
    [ "$(decision)" = "deny" ]
}

@test "blocks fully qualified master destination" {
    run run_hook "git push origin HEAD:refs/heads/master"
    [ "$(decision)" = "deny" ]
}

@test "blocks main push after an environment prefix" {
    run run_hook "env CI=1 git push origin feature:main"
    [ "$(decision)" = "deny" ]
}

@test "blocks force push in a chained command" {
    run run_hook "printf ready && git push origin +feature:feature"
    [ "$(decision)" = "deny" ]
}

# --- Should allow ---

@test "allows push to feature branch" {
    git() { echo "feature-branch"; }
    export -f git
    run run_hook "git push origin feature-branch"
    [ "$(decision)" = "allow" ]
    unset -f git
}

@test "allows push with no remote (feature branch)" {
    git() { echo "my-feature"; }
    export -f git
    run run_hook "git push"
    [ "$(decision)" = "allow" ]
    unset -f git
}

@test "allows fully qualified feature destination" {
    run run_hook "git push origin feature:refs/heads/feature"
    [ "$(decision)" = "allow" ]
}

@test "ignores non-push git commands" {
    run run_hook "git commit -m test"
    [ "$status" -eq 0 ]
    [ -z "$(decision)" ]
}

@test "ignores non-git commands" {
    run run_hook "echo hello"
    [ "$status" -eq 0 ]
}
