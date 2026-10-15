#!/usr/bin/env bash
# Install pre-commit through Git's effective hooks path.

set -euo pipefail

hook_path="$(git rev-parse --git-path hooks/pre-commit)"
mkdir -p "$(dirname "$hook_path")"
if [ -f "$hook_path" ] && ! grep -q 'pre-commit framework' "$hook_path" 2>/dev/null; then
    backup="${hook_path}.project-standards-backup"
    if [ ! -e "$backup" ]; then
        cp "$hook_path" "$backup"
        echo "hooks-install: preserved existing hook at $backup"
    fi
fi

uv run --locked pre-commit install --hook-type pre-commit
