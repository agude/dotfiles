#!/usr/bin/env bash
# Codex SessionStart shim — initializes session capture and injects KB context.
set -euo pipefail

KB="${KNOWLEDGE_BASE:-}"
[[ -z "$KB" ]] && { echo '{}'; exit 0; }
command -v jq > /dev/null 2>&1 || { echo '{}'; exit 0; }

INPUT="$(cat)"
SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty')"

# Initialize buffer when capture is enabled.
if [[ "${KNOWLEDGE_OBSERVE:-}" == "1" ]] && [[ -n "$SESSION_ID" ]]; then
    "$KB/scripts/session-init" --session-id "$SESSION_ID" > /dev/null 2>&1 || true
fi

# Always inject context, even if capture is off.
CONTEXT="$("$KB/scripts/session-context" 2>/dev/null || echo "")"

if [[ -n "$CONTEXT" ]]; then
    jq -nc --arg ctx "$CONTEXT" '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": $ctx}}'
else
    echo '{}'
fi
