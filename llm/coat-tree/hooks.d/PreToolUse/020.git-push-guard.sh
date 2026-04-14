#!/usr/bin/env bash
# hook-matcher: Bash
#
# Smart git push guard. Replaces the blanket deny rule with judgment:
#   - Block: force push (--force, -f, --force-with-lease)
#   - Block: push to main/master
#   - Allow: regular pushes to feature branches

set -uo pipefail

INPUT=$(cat)
COMMAND=$(printf '%s\n' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Only inspect git push commands
[[ "$COMMAND" =~ ^[[:space:]]*(git[[:space:]]+push) ]] || exit 0

# Block force push
if [[ "$COMMAND" =~ (^|[[:space:]])(--force|-f|--force-with-lease)([[:space:]]|$) ]]; then
    cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Force push is blocked."}}
EOF
    exit 0
fi

# Parse the refspec from the command. Strip flags first.
# Patterns: git push, git push origin, git push origin branch
cleaned=$(printf '%s\n' "$COMMAND" | sed 's/git push//' | sed 's/-[[:alpha:]][[:space:]]*[^[:space:]]*//g' | sed 's/--[[:alpha:]-]*//g' | xargs)
refspec=$(echo "$cleaned" | awk '{print $2}')

# Determine which branch is being pushed
if [[ -n "$refspec" ]]; then
    # Explicit refspec: extract the destination (after : if present, otherwise the whole thing)
    branch="${refspec##*:}"
    [[ -z "$branch" ]] && branch="${refspec%%:*}"
else
    # No refspec — pushing current branch
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
fi

# Block push to main/master
if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Don't push directly to main/master."}}
EOF
    exit 0
fi

# Allow regular pushes to feature branches
cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"Push to feature branch."}}
EOF
