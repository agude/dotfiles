#!/usr/bin/env bash
# Claude Stop shim — appends assistant response to session buffer.
set -euo pipefail

[[ "${KNOWLEDGE_OBSERVE:-}" == "0" ]] && exit 0

KB="${KNOWLEDGE_BASE:-}"
[[ -z "$KB" ]] && exit 0

command -v jq > /dev/null 2>&1 || exit 0

INPUT="$(cat)"
MESSAGE="$(echo "$INPUT" | jq -r '.last_assistant_message // empty')"

[[ -z "$MESSAGE" ]] && exit 0

FILE="${KNOWLEDGE_SESSION_FILE:-}"
if [[ -z "$FILE" ]]; then
    SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty')"
    [[ -z "$SESSION_ID" ]] && exit 0
    SESSION_DIR="${SESSION_DIR:-${XDG_RUNTIME_DIR:-/tmp}/knowledge-sessions-$(id -u)}"
    FILE="$SESSION_DIR/session-${SESSION_ID}.jsonl"
fi

"$KB/scripts/session-append" --file "$FILE" --role assistant --message "$MESSAGE" 2>/dev/null || true

exit 0
