#!/usr/bin/env bash
# Validate policy syntax and the tracked consumers that expose its defaults.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=policy.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/policy.sh"
python3 "$SCRIPT_DIR/validate-policy.py" "$SKILL_DIR/policy.toml"

for required_file in "$SKILL_DIR/SKILL.md" "$SKILL_DIR/assets/justfile" \
                     "$SKILL_DIR/assets/workflows/ci.yml" \
                     "$SKILL_DIR/assets/renovate.json5"; do
    [ -f "$required_file" ] || { echo "policy: missing consumer $required_file" >&2; exit 1; }
done

jq empty "$SKILL_DIR/assets/renovate.json5" >/dev/null

floor="$(policy_value "$SKILL_DIR/policy.toml" python floor)"
latest="$(policy_value "$SKILL_DIR/policy.toml" python latest)"
ruff_target="$(policy_value "$SKILL_DIR/policy.toml" python ruff_target)"
mypy_target="$(policy_value "$SKILL_DIR/policy.toml" python mypy_target)"
coverage_floor="$(policy_value "$SKILL_DIR/policy.toml" python coverage_floor)"
matrix="$(policy_array "$SKILL_DIR/policy.toml" python matrix | awk 'BEGIN { printf "[" } { if (count++) printf ", "; printf "\"%s\"", $0 } END { print "]" }')"

for action in checkout setup_uv setup_just upload_artifact download_artifact setup_python pypi_publish; do
    ref="$(policy_action "$SKILL_DIR/policy.toml" "$action")"
    version="$(policy_action_version "$SKILL_DIR/policy.toml" "$action")"
    case "$action" in
        checkout) name="actions/checkout" ;;
        setup_uv) name="astral-sh/setup-uv" ;;
        setup_just) name="extractions/setup-just" ;;
        upload_artifact) name="actions/upload-artifact" ;;
        download_artifact) name="actions/download-artifact" ;;
        setup_python) name="actions/setup-python" ;;
        pypi_publish) name="pypa/gh-action-pypi-publish" ;;
    esac
    grep -Fq "| \`$name\` | \`$version\`" "$SKILL_DIR/SKILL.md" || {
        echo "policy: SKILL.md is stale for $name@$version" >&2
        exit 1
    }
done
grep -Fq "policy currently tests $floor through $latest" "$SKILL_DIR/SKILL.md" || {
    echo "policy: SKILL.md is stale for the Python support range" >&2
    exit 1
}
grep -Fq -- "--cov-fail-under=$coverage_floor" "$SKILL_DIR/SKILL.md" || {
    echo "policy: SKILL.md is stale for the coverage floor" >&2
    exit 1
}

render_root="$(mktemp -d)"
cleanup() { rm -rf "$render_root"; }
trap cleanup EXIT
bash "$SCRIPT_DIR/scaffold.sh" "$render_root/generated" policy_check_fixture >/dev/null

grep -Fq "requires-python = \">=$floor\"" "$render_root/generated/pyproject.toml" || {
    echo "policy: generated requires-python does not match the floor" >&2
    exit 1
}
grep -Fq "target-version = \"$ruff_target\"" "$render_root/generated/pyproject.toml" || {
    echo "policy: generated Ruff target does not match policy" >&2
    exit 1
}
grep -Fq "python_version = \"$mypy_target\"" "$render_root/generated/pyproject.toml" || {
    echo "policy: generated mypy target does not match policy" >&2
    exit 1
}
grep -Fq -- "--cov-fail-under=$coverage_floor" "$render_root/generated/pyproject.toml" || {
    echo "policy: generated coverage floor does not match policy" >&2
    exit 1
}
[ "$(cat "$render_root/generated/.python-version")" = "$latest" ] || {
    echo "policy: generated .python-version does not match policy" >&2
    exit 1
}
grep -Fq "python-version: $matrix" "$render_root/generated/.github/workflows/ci.yml" || {
    echo "policy: generated CI matrix does not match policy" >&2
    exit 1
}
grep -Fq "uv tool install zizmor==$(policy_value "$SKILL_DIR/policy.toml" tools.zizmor version)" \
    "$render_root/generated/.github/workflows/ci.yml" || {
    echo "policy: generated zizmor version does not match policy" >&2
    exit 1
}
actionlint_version="$(policy_value "$SKILL_DIR/policy.toml" tools.actionlint version)"
grep -Fq "actionlint_${actionlint_version}_linux_amd64.tar.gz" \
    "$render_root/generated/.github/workflows/ci.yml" || {
    echo "policy: generated actionlint version does not match policy" >&2
    exit 1
}
for action in checkout setup_uv setup_just upload_artifact download_artifact; do
    ref="$(policy_action "$SKILL_DIR/policy.toml" "$action")"
    version="$(policy_action_version "$SKILL_DIR/policy.toml" "$action")"
    case "$action" in
        checkout) name="actions/checkout" ;;
        setup_uv) name="astral-sh/setup-uv" ;;
        setup_just) name="extractions/setup-just" ;;
        upload_artifact) name="actions/upload-artifact" ;;
        download_artifact) name="actions/download-artifact" ;;
    esac
    grep -Fq "$name@$ref # $version" "$render_root/generated/.github/workflows/ci.yml" || {
        echo "policy: generated workflow is stale for $name@$version" >&2
        exit 1
    }
done
publish_ref="$(policy_action "$SKILL_DIR/policy.toml" pypi_publish)"
publish_version="$(policy_action_version "$SKILL_DIR/policy.toml" pypi_publish)"
bash "$SCRIPT_DIR/scaffold.sh" "$render_root/published" policy_check_fixture --publish >/dev/null
grep -Fq "pypa/gh-action-pypi-publish@$publish_ref # $publish_version" \
    "$render_root/published/.github/workflows/release.yml" || {
    echo "policy: generated release workflow is stale for the PyPI publisher" >&2
    exit 1
}
if grep -R -E 'PACKAGE|REPO|PYTHON_|PROJECT_COMMAND_NAME|CHECKOUT_VERSION|SETUP_UV_VERSION|SETUP_JUST_VERSION|UPLOAD_ARTIFACT_VERSION|DOWNLOAD_ARTIFACT_VERSION|PYPI_PUBLISH_VERSION|ACTIONLINT_VERSION|ZIZMOR_VERSION' \
    "$render_root/generated" >/dev/null; then
    echo "policy: generated fixture contains unresolved placeholders" >&2
    exit 1
fi

echo "policy: consumers and generated values are consistent"
