#!/usr/bin/env bash
# Claude SessionEnd shim — flushes session buffer into a KB observation.
set -euo pipefail

[[ "${KNOWLEDGE_OBSERVE:-}" == "0" ]] && exit 0

KB="${KNOWLEDGE_BASE:-}"
[[ -z "$KB" ]] && exit 0

command -v jq > /dev/null 2>&1 || exit 0

INPUT="$(cat)"
SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty')"

[[ -z "$SESSION_ID" ]] && exit 0

FILE="${KNOWLEDGE_SESSION_FILE:-}"
if [[ -z "$FILE" ]]; then
    SESSION_DIR="${SESSION_DIR:-${XDG_RUNTIME_DIR:-/tmp}/knowledge-sessions-$(id -u)}"
    FILE="$SESSION_DIR/session-${SESSION_ID}.jsonl"
fi

[[ -f "$FILE" ]] || exit 0

exec "$KB/scripts/session-flush" "$FILE"
