#!/usr/bin/env bash
# Preserve the shell entrypoint; parse YAML with the Python helper.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec uv run "$SCRIPT_DIR/validate.py" "$@"
