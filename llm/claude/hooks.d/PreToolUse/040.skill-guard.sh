#!/usr/bin/env bash
# hook-matcher: Skill
#
# Block Skill(artifact-design) — write markdown output directly instead.

set -uo pipefail

INPUT=$(cat)

SKILL=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null)
[[ "$SKILL" == "artifact-design" ]] || exit 0

cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Write markdown instead."}}
EOF
exit 0
