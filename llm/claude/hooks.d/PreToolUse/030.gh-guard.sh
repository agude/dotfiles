#!/usr/bin/env bash
# hook-matcher: Bash
#
# Smart GitHub CLI guard. Replaces blanket deny rules with categories:
#   - Block:  destructive repo/org operations, credential changes
#   - Allow:  PR and issue workflow commands (create, comment, edit, etc.)
#   - Defer:  mutating API calls (gh api POST/PUT/DELETE/PATCH) to user prompt

set -uo pipefail

INPUT=$(cat)
COMMAND=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Only inspect gh commands
[[ "$COMMAND" =~ ^[[:space:]]*(gh[[:space:]]) ]] || exit 0

deny() {
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"$1"}}
EOF
    exit 0
}

allow() {
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"$1"}}
EOF
    exit 0
}

ask() {
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"$1"}}
EOF
    exit 0
}

# --- Always block: destructive or credential operations ---

# Repo destruction/modification
[[ "$COMMAND" =~ gh[[:space:]]+repo[[:space:]]+(delete|archive|rename|change-visibility) ]] && deny "Destructive repo operation blocked."

# Credential and key management
[[ "$COMMAND" =~ gh[[:space:]]+(auth|ssh-key|gpg-key) ]] && deny "Credential operation blocked."

# Config changes
[[ "$COMMAND" =~ gh[[:space:]]+config[[:space:]]+set ]] && deny "Config change blocked."

# Extension management
[[ "$COMMAND" =~ gh[[:space:]]+extension[[:space:]]+(install|remove) ]] && deny "Extension management blocked."

# Codespace management
[[ "$COMMAND" =~ gh[[:space:]]+codespace ]] && deny "Codespace operation blocked."

# --- Allow: common PR and issue workflow ---

# PR operations
[[ "$COMMAND" =~ gh[[:space:]]+pr[[:space:]]+(create|comment|edit|close|merge|ready|review) ]] && allow "PR workflow."

# Issue operations
[[ "$COMMAND" =~ gh[[:space:]]+issue[[:space:]]+(create|comment|edit|close) ]] && allow "Issue workflow."

# Gist creation (not deletion)
[[ "$COMMAND" =~ gh[[:space:]]+gist[[:space:]]+create ]] && allow "Gist creation."

# --- Ask: mutating API calls and everything else risky ---

# Mutating gh api calls
[[ "$COMMAND" =~ gh[[:space:]]+api[[:space:]] ]] && \
    [[ "$COMMAND" =~ (--method[[:space:]]+(POST|PUT|DELETE|PATCH)|-X[[:space:]]+(POST|PUT|DELETE|PATCH)|--field[[:space:]]|-f[[:space:]]) ]] && \
    ask "Mutating API call — confirm."

# Secrets, releases, cache
[[ "$COMMAND" =~ gh[[:space:]]+(secret|cache)[[:space:]]+(set|delete) ]] && ask "Sensitive operation — confirm."
[[ "$COMMAND" =~ gh[[:space:]]+release[[:space:]]+delete ]] && ask "Release deletion — confirm."
[[ "$COMMAND" =~ gh[[:space:]]+gist[[:space:]]+delete ]] && ask "Gist deletion — confirm."

# If no rule matched, let it through (read-only commands, etc.)
