#!/usr/bin/env bash
# Codex UserPromptSubmit shim — appends user prompt to session buffer.
set -euo pipefail

INPUT="$(cat)"
KB="${KNOWLEDGE_BASE:-}"

[[ -z "$KB" ]] && { echo '{}'; exit 0; }
[[ "${KNOWLEDGE_OBSERVE:-}" != "1" ]] && { echo '{}'; exit 0; }
command -v jq > /dev/null 2>&1 || { echo '{}'; exit 0; }

SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty')"
PROMPT="$(echo "$INPUT" | jq -r '.prompt // empty')"

if [[ -n "$SESSION_ID" ]] && [[ -n "$PROMPT" ]]; then
    SESSION_DIR="${SESSION_DIR:-${XDG_RUNTIME_DIR:-/tmp}/knowledge-sessions-$(id -u)}"
    FILE="$SESSION_DIR/session-${SESSION_ID}.jsonl"
    "$KB/scripts/session-append" --file "$FILE" --role user --message "$PROMPT" 2>/dev/null || true
fi

echo '{}'
