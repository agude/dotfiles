#!/usr/bin/env bash
# hook-matcher: Bash
# Deny destructive GitHub operations and confirm unmatched mutations.

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec python3 "${SCRIPT_DIR}/../command_guard.py" gh
