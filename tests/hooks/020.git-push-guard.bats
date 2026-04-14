#!/usr/bin/env bats

load test_helper

setup() { setup_repo; }
teardown() { teardown_repo; }

HOOK="llm/coat-tree/hooks.d/PreToolUse/020.git-push-guard.sh"

@test "non-git-push command passes through" {
    run_hook "$BATS_TEST_DIRNAME/../../$HOOK" "ls -la"
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "empty command passes through" {
    run_hook "$BATS_TEST_DIRNAME/../../$HOOK" ""
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "git status passes through" {
    run_hook "$BATS_TEST_DIRNAME/../../$HOOK" "git status"
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "blocks --force" {
    run_hook "$BATS_TEST_DIRNAME/../../$HOOK" "git push --force origin feature"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *'"permissionDecision":"deny"'* ]]
    [[ "$output" == *"Force push"* ]]
}

@test "blocks -f short flag" {
    run_hook "$BATS_TEST_DIRNAME/../../$HOOK" "git push -f origin feature"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *'"permissionDecision":"deny"'* ]]
    [[ "$output" == *"Force push"* ]]
}

@test "blocks --force-with-lease" {
    run_hook "$BATS_TEST_DIRNAME/../../$HOOK" "git push --force-with-lease origin feature"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *'"permissionDecision":"deny"'* ]]
    [[ "$output" == *"Force push"* ]]
}

@test "blocks explicit push to main" {
    checkout_branch feature
    run_hook "$BATS_TEST_DIRNAME/../../$HOOK" "git push origin main"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *'"permissionDecision":"deny"'* ]]
    [[ "$output" == *"main/master"* ]]
}

@test "blocks explicit push to master" {
    checkout_branch feature
    run_hook "$BATS_TEST_DIRNAME/../../$HOOK" "git push origin master"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *'"permissionDecision":"deny"'* ]]
    [[ "$output" == *"main/master"* ]]
}

@test "blocks refspec pushing to main" {
    checkout_branch feature
    run_hook "$BATS_TEST_DIRNAME/../../$HOOK" "git push origin feature:main"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *'"permissionDecision":"deny"'* ]]
    [[ "$output" == *"main/master"* ]]
}

@test "blocks bare push when current branch is main" {
    run_hook "$BATS_TEST_DIRNAME/../../$HOOK" "git push"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *'"permissionDecision":"deny"'* ]]
    [[ "$output" == *"main/master"* ]]
}

@test "allows push to feature branch" {
    checkout_branch feature
    run_hook "$BATS_TEST_DIRNAME/../../$HOOK" "git push origin feature"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *'"permissionDecision":"allow"'* ]]
}

@test "allows bare push from feature branch" {
    checkout_branch feature
    run_hook "$BATS_TEST_DIRNAME/../../$HOOK" "git push"
    [[ "$status" -eq 0 ]]
    [[ "$output" == *'"permissionDecision":"allow"'* ]]
}
