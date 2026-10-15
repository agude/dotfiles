#!/usr/bin/env bash
# Exercise bootstrapped library and CLI projects in owned temporary directories.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(mktemp -d)"
trap 'rm -rf "$ROOT"' EXIT

bash "$SKILL_ROOT/scripts/scaffold.sh" "$ROOT/library" integration_library --bootstrap
(cd "$ROOT/library" && just check)

bash "$SKILL_ROOT/scripts/scaffold.sh" "$ROOT/cli" integration_cli \
    --kind cli --distribution-name integration-cli --command-name integration-tool \
    --bootstrap
(cd "$ROOT/cli" && just check)

echo "project-standards integration: generated library and CLI checks passed"
