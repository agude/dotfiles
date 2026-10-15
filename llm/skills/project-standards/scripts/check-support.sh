#!/usr/bin/env bash
# Report policy support state without silently changing the support claim.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=policy.sh
# shellcheck disable=SC1091
. "$SKILL_DIR/scripts/policy.sh"

candidate=""
if [ "${1:-}" = "--candidate" ]; then
    [ $# -eq 2 ] || { echo "Usage: check-support.sh [--candidate 3.x]" >&2; exit 2; }
    candidate="$2"
elif [ $# -gt 0 ]; then
    echo "Usage: check-support.sh [--candidate 3.x]" >&2
    exit 2
fi

latest="$(policy_value "$SKILL_DIR/policy.toml" python latest)"
floor="$(policy_value "$SKILL_DIR/policy.toml" python floor)"
matrix="$(policy_array "$SKILL_DIR/policy.toml" python matrix | tr '\n' ' ')"
case " $matrix " in
    *" $floor "*|*" $latest "*);;
    *) echo "support: policy matrix omits floor or latest" >&2; exit 1 ;;
esac

if [ -n "$candidate" ]; then
    case " $matrix " in
        *" $candidate "*) echo "support: candidate $candidate is already declared; run its suite before changing policy" ;;
        *) echo "support: candidate $candidate requires a reviewed policy change and matrix validation"; exit 1 ;;
    esac
else
    echo "support: floor=$floor latest=$latest matrix=$matrix"
    echo "support: upstream EOL and release checks are review inputs, not automatic support changes"
fi
