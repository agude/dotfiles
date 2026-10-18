#!/usr/bin/env bash
# shellcheck shell=bash
# Compatibility entry point; the portable implementation is in jd.py.
set -euo pipefail
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
    SCRIPT_DIRECTORY="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_TARGET="$(readlink "$SCRIPT_PATH")"
    if [[ "$SCRIPT_TARGET" = /* ]]; then
        SCRIPT_PATH="$SCRIPT_TARGET"
    else
        SCRIPT_PATH="${SCRIPT_DIRECTORY}/${SCRIPT_TARGET}"
    fi
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
if command -v python3 >/dev/null 2>&1; then
    PYTHON=(python3)
else
    PYTHON=(uv run --no-project)
fi
exec "${PYTHON[@]}" "${SCRIPT_DIR}/jd.py" tree "$@"
