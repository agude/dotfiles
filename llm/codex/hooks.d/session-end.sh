#!/usr/bin/env bash
# Codex SessionEnd shim — delegates to the knowledge-base adapter.
#
# The adapter owns all capture logic. Without one, consume the hook input
# and return Codex's required empty response so the session is unaffected.
set -euo pipefail

adapter="${KNOWLEDGE_BASE:-}/scripts/adapters/codex/session-end"
if [[ -n "${KNOWLEDGE_BASE:-}" && -x "$adapter" ]]; then
    exec "$adapter"
fi

cat > /dev/null
echo '{}'
