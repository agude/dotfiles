#!/usr/bin/env bash
# hook-matcher: Bash
#
# Block git commands that bypass hooks or commit signing.
#
# Caught patterns:
#   --no-verify / -n          skip pre-commit/commit-msg hooks
#   --no-gpg-sign             skip commit signing
#   -c commit.gpgsign=false   disable signing via config override
#
# Exits 2 (abort) when a bypass is detected.

set -uo pipefail

COMMAND=$(jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Only inspect git commands
[[ "$COMMAND" =~ ^[[:space:]]*(git[[:space:]]) ]] || exit 0

# Patterns that bypass safety checks
if [[ "$COMMAND" =~ (^|[[:space:]])(--no-verify|-n)([[:space:]]|$) ]] ||
   [[ "$COMMAND" =~ (^|[[:space:]])--no-gpg-sign([[:space:]]|$) ]] ||
   [[ "$COMMAND" =~ -c[[:space:]]+commit\.gpgsign=false ]]; then
    echo "Don't bypass git hooks." >&2
    exit 2
fi
