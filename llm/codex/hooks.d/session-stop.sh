#!/usr/bin/env bash
# Codex Stop shim — appends assistant response to session buffer.
set -euo pipefail

INPUT="$(cat)"
KB="${KNOWLEDGE_BASE:-}"

[[ -z "$KB" ]] && { echo '{}'; exit 0; }
[[ "${KNOWLEDGE_OBSERVE:-}" != "1" ]] && { echo '{}'; exit 0; }
command -v jq > /dev/null 2>&1 || { echo '{}'; exit 0; }

SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty')"
MESSAGE="$(echo "$INPUT" | jq -r '.last_assistant_message // empty')"

if [[ -n "$SESSION_ID" ]] && [[ -n "$MESSAGE" ]]; then
    SESSION_DIR="${SESSION_DIR:-${XDG_RUNTIME_DIR:-/tmp}/knowledge-sessions-$(id -u)}"
    FILE="$SESSION_DIR/session-${SESSION_ID}.jsonl"
    "$KB/scripts/session-append" --file "$FILE" --role assistant --message "$MESSAGE" 2>/dev/null || true
fi

echo '{}'
