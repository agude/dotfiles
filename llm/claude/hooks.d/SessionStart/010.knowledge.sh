#!/usr/bin/env bash
# Claude SessionStart shim — initializes session capture and injects KB context.
#
# Reads JSON from stdin (coat-tree protocol), calls the agent-agnostic
# core scripts in the Knowledge repo, outputs plain text context to stdout,
# and propagates env vars via CLAUDE_ENV_FILE.
set -euo pipefail

INPUT="$(cat)"
KB="${KNOWLEDGE_BASE:-}"

[[ -z "$KB" ]] && exit 0

# Context output must happen even when capture setup fails.
output_context() {
    "$KB/scripts/session-context" 2>/dev/null || true
}
trap 'output_context; exit 0' EXIT

# Respect a pre-existing opt-out.
if [[ "${KNOWLEDGE_OBSERVE:-}" == "0" ]]; then
    if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
        echo "KNOWLEDGE_OBSERVE=0" >> "$CLAUDE_ENV_FILE"
    fi
    exit 0
fi

command -v jq > /dev/null 2>&1 || exit 0

SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")"
if [[ -z "$SESSION_ID" ]]; then
    SESSION_ID="$$-$(date +%s)"
fi

SESSION_FILE="$("$KB/scripts/session-init" --session-id "$SESSION_ID" 2>/dev/null || echo "")"

if [[ -n "$SESSION_FILE" ]] && [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
    echo "KNOWLEDGE_OBSERVE=1" >> "$CLAUDE_ENV_FILE"
    echo "KNOWLEDGE_SESSION_FILE=$SESSION_FILE" >> "$CLAUDE_ENV_FILE"
fi

# output_context runs from the EXIT trap.
