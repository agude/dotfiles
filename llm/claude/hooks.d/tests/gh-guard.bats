#!/usr/bin/env bats

HOOK="$BATS_TEST_DIRNAME/../PreToolUse/030.gh-guard.sh"

run_hook() {
    jq -cn --arg command "$1" '{tool_input: {command: $command}}' |
        bash "$HOOK"
}

decision() {
    printf '%s\n' "$output" |
        jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null
}

@test "denies repository deletion" {
    run run_hook "gh repo delete owner/repository"
    [[ "$(decision)" == "deny" ]]
}

@test "denies destructive gh command after environment prefix" {
    run run_hook "env GH_HOST=github.com gh repo delete owner/repository"
    [[ "$(decision)" == "deny" ]]
}

@test "denies destructive gh command in a chain" {
    run run_hook "printf ready && gh repo delete owner/repository"
    [[ "$(decision)" == "deny" ]]
}

@test "asks before PR merge" {
    run run_hook "gh pr merge 42"
    [[ "$(decision)" == "ask" ]]
}

@test "asks before mutating API request" {
    run run_hook "gh api --method DELETE repos/owner/repository/hooks/1"
    [[ "$(decision)" == "ask" ]]
}

@test "asks before unmatched variable mutation" {
    run run_hook "gh variable set DEPLOY_ENV --body production"
    [[ "$(decision)" == "ask" ]]
}

@test "asks before newly introduced destructive subcommand" {
    run run_hook "gh ruleset delete 123"
    [[ "$(decision)" == "ask" ]]
}

@test "allows routine PR creation" {
    run run_hook "gh pr create --fill"
    [[ "$(decision)" == "allow" ]]
}

@test "allows routine issue comments" {
    run run_hook "gh issue comment 42 --body fixed"
    [[ "$(decision)" == "allow" ]]
}

@test "allows known read-only commands" {
    run run_hook "gh repo view owner/repository"
    [[ "$(decision)" == "allow" ]]

    run run_hook "gh pr list"
    [[ "$(decision)" == "allow" ]]

    run run_hook "gh api repos/owner/repository"
    [[ "$(decision)" == "allow" ]]
}

@test "ignores non-gh commands" {
    run run_hook "git status"
    [[ "$status" -eq 0 ]]
    [[ -z "$(decision)" ]]
}
