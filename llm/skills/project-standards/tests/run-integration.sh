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
(cd "$ROOT/library" && just check)

bash "$SKILL_ROOT/scripts/scaffold.sh" "$ROOT/cli" integration_cli \
    --kind cli --distribution-name integration-cli --command-name integration-tool \
    --bootstrap
(cd "$ROOT/cli" && just check)

echo "project-standards integration: generated library and CLI checks passed"
