#!/usr/bin/env bash
# Validate policy syntax and the tracked consumers that expose its defaults.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
python3 "$SCRIPT_DIR/validate-policy.py" "$SKILL_DIR/policy.toml"

for required_file in "$SKILL_DIR/SKILL.md" "$SKILL_DIR/assets/justfile" \
                     "$SKILL_DIR/assets/workflows/ci.yml" \
                     "$SKILL_DIR/assets/renovate.json5"; do
    [ -f "$required_file" ] || { echo "policy: missing consumer $required_file" >&2; exit 1; }
done

jq empty "$SKILL_DIR/assets/renovate.json5" >/dev/null

echo "policy: consumers present"
