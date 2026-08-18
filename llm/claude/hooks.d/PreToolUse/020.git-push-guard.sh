#!/usr/bin/env bash
# hook-matcher: Bash
# Block force pushes and direct pushes to protected branches.

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec python3 "${SCRIPT_DIR}/../command_guard.py" git-push
