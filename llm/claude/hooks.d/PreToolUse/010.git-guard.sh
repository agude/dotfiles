#!/usr/bin/env bash
# hook-matcher: Bash
# Block Git commands that bypass hooks or commit signing.

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec python3 "${SCRIPT_DIR}/../command_guard.py" git-bypass
