#!/usr/bin/env bash
# hook-matcher: Bash
#
# Block git commands that bypass hooks or commit signing.
#
# Caught patterns:
#   --no-verify               skip pre-commit/commit-msg hooks (any subcommand)
#   -n                        short for --no-verify (commit/merge/revert/cherry-pick/am only)
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
if [[ "$COMMAND" =~ (^|[[:space:]])--no-verify([[:space:]]|$) ]] ||
   [[ "$COMMAND" =~ (^|[[:space:]])--no-gpg-sign([[:space:]]|$) ]] ||
   [[ "$COMMAND" =~ -c[[:space:]]+commit\.gpgsign=false ]]; then
    echo "Don't bypass git hooks." >&2
    exit 2
fi

# -n means --no-verify only for commit, merge, revert, cherry-pick, and am.
# Other subcommands use -n for unrelated purposes (e.g., git log -n 5,
# git clean -n for dry-run).
if [[ "$COMMAND" =~ (^|[[:space:]])-n([[:space:]]|$) ]] &&
   [[ "$COMMAND" =~ (^|[[:space:]])(commit|merge|revert|cherry-pick|am)([[:space:]]|$) ]]; then
    echo "Don't bypass git hooks." >&2
    exit 2
fi
