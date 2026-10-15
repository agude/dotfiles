#!/usr/bin/env bash
# Install pre-commit through Git's effective hooks path.

set -euo pipefail

uv run --locked pre-commit --version >/dev/null
hook_path="$(git rev-parse --git-path hooks/pre-commit)"
mkdir -p "$(dirname "$hook_path")"

# pre-commit's installer refuses core.hooksPath. Its public runner still
# isolates staged content when invoked from a hook at Git's effective path.
hook_content='#!/usr/bin/env bash
# project-standards pre-commit framework hook
set -euo pipefail
exec uv run --locked pre-commit run --hook-stage pre-commit'

if [ -f "$hook_path" ] && cmp -s "$hook_path" <(printf '%s\n' "$hook_content"); then
    chmod +x "$hook_path"
    echo "hooks-install: already installed at $hook_path"
    exit 0
fi
if [ -e "$hook_path" ] || [ -L "$hook_path" ]; then
    [ ! -d "$hook_path" ] || { echo "hooks-install: hook path is a directory: $hook_path" >&2; exit 1; }
    backup="$(mktemp "${hook_path}.project-standards-backup.XXXXXX")"
    mv "$hook_path" "$backup"
    echo "hooks-install: preserved existing hook at $backup"
fi

printf '%s\n' "$hook_content" > "$hook_path"
chmod +x "$hook_path"
echo "hooks-install: installed at $hook_path"
