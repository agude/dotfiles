#!/usr/bin/env bash
# Exercise bootstrapped library and CLI projects in owned temporary directories.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=../scripts/policy.sh
# shellcheck disable=SC1091
. "$SKILL_ROOT/scripts/policy.sh"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

python_latest="$(policy_value "$SKILL_ROOT/policy.toml" python latest)"
export UV_PYTHON_INSTALL_DIR="$ROOT/python"
uv python install "$python_latest"

bash "$SKILL_ROOT/scripts/scaffold.sh" "$ROOT/library" integration_library --bootstrap
(cd "$ROOT/library" && git add -A)
printf 'def broken(\n' > "$ROOT/library/src/integration_library/__init__.py"
(cd "$ROOT/library" && git add src/integration_library/__init__.py)
printf '__version__: str = "0.1.0"\n' > "$ROOT/library/src/integration_library/__init__.py"
if (cd "$ROOT/library" && uv run --locked pre-commit run); then
    echo "project-standards integration: staged invalid Python unexpectedly passed" >&2
    exit 1
fi
grep -q '__version__: str = "0.1.0"' "$ROOT/library/src/integration_library/__init__.py"
(cd "$ROOT/library" && just check)

bash "$SKILL_ROOT/scripts/scaffold.sh" "$ROOT/cli" integration_cli \
    --kind cli --distribution-name integration-cli --command-name integration-tool \
    --bootstrap
(cd "$ROOT/cli" && just check)

echo "project-standards integration: generated library and CLI checks passed"
