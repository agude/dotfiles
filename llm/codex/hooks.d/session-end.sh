#!/usr/bin/env bash
# Codex SessionEnd shim — flushes session buffer into a KB observation.
set -euo pipefail

INPUT="$(cat)"
KB="${KNOWLEDGE_BASE:-}"

[[ -z "$KB" ]] && { echo '{}'; exit 0; }
[[ "${KNOWLEDGE_OBSERVE:-}" != "1" ]] && { echo '{}'; exit 0; }
command -v jq > /dev/null 2>&1 || { echo '{}'; exit 0; }

SESSION_ID="$(echo "$INPUT" | jq -r '.session_id // empty')"

if [[ -n "$SESSION_ID" ]]; then
    SESSION_DIR="${SESSION_DIR:-${XDG_RUNTIME_DIR:-/tmp}/knowledge-sessions-$(id -u)}"
    FILE="$SESSION_DIR/session-${SESSION_ID}.jsonl"
    if [[ -f "$FILE" ]]; then
        # Codex caps SessionEnd at 3s. Background the flush so it
        # survives the timeout; orphan sweep catches it if this fails.
        KB_CONTENT_DIR="${KB_CONTENT_DIR:-}" "$KB/scripts/session-flush" "$FILE" </dev/null &>/dev/null &
        disown 2>/dev/null || true
    fi
fi

echo '{}'
