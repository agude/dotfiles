#!/usr/bin/env bash
# Scaffold a Python package without contacting dependency services.
# shellcheck disable=SC1091,SC2006,SC2215

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$SKILL_DIR/assets"
POLICY="$SKILL_DIR/policy.toml"
# shellcheck source=policy.sh
. "$SKILL_DIR/scripts/policy.sh"

usage() {
    cat >&2 <<'EOF'
Usage: bash scaffold.sh <dest-dir> <package-name> [options]

Options:
  --kind library|cli       Generate a library (default) or console application.
  --distribution-name NAME Distribution metadata name (default: package-name with -).
  --command-name NAME      Console command for --kind cli (default: distribution name).
  --publish                Include the tag-triggered PyPI workflow.
  --bootstrap               Create uv.lock, sync dependencies, and install hooks.
  -h, --help               Show this help.

Generation is offline and refuses non-empty or symbolic-link destinations.
--bootstrap is the only option that contacts dependency services.
EOF
    exit 2
}

[ $# -ge 2 ] || usage
DEST_INPUT="$1"
PACKAGE="$2"
shift 2
KIND="library"
REPO="${PACKAGE//_/-}"
COMMAND_NAME=""
PUBLISH="false"
BOOTSTRAP="false"

while [ $# -gt 0 ]; do
    case "$1" in
        --kind)
            [ $# -ge 2 ] || usage
            KIND="$2"
            shift 2
            ;;
        --kind=*) KIND="${1#--kind=}"; shift ;;
        --distribution-name)
            [ $# -ge 2 ] || usage
            REPO="$2"
            shift 2
            ;;
        --distribution-name=*) REPO="${1#--distribution-name=}"; shift ;;
        --command-name)
            [ $# -ge 2 ] || usage
            COMMAND_NAME="$2"
            shift 2
            ;;
        --command-name=*) COMMAND_NAME="${1#--command-name=}"; shift ;;
        --publish) PUBLISH="true"; shift ;;
        --bootstrap) BOOTSTRAP="true"; shift ;;
        -h|--help) usage ;;
        *) echo "scaffold.sh: unknown option: $1" >&2; usage ;;
    esac
done

if [[ ! "$PACKAGE" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    echo "scaffold.sh: '$PACKAGE' is not a valid Python identifier" >&2
    exit 1
fi
case "$KIND" in
    library|cli) ;;
    *) echo "scaffold.sh: --kind must be library or cli" >&2; exit 1 ;;
esac
if [[ ! "$REPO" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
    echo "scaffold.sh: '$REPO' is not a valid distribution name" >&2
    exit 1
fi
if [ "$KIND" = "cli" ] && [ -z "$COMMAND_NAME" ]; then
    COMMAND_NAME="$REPO"
fi
if [ -n "$COMMAND_NAME" ] && [[ ! "$COMMAND_NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
    echo "scaffold.sh: '$COMMAND_NAME' is not a valid command name" >&2
    exit 1
fi
if [ "$KIND" = "library" ] && [ -n "$COMMAND_NAME" ]; then
    echo "scaffold.sh: --command-name requires --kind cli" >&2
    exit 1
fi

case "$DEST_INPUT" in
    /*) DEST="$DEST_INPUT" ;;
    *) DEST="$PWD/$DEST_INPUT" ;;
esac
DEST_PARENT="$(dirname "$DEST")"
DEST_BASE="$(basename "$DEST")"
if [ ! -d "$DEST_PARENT" ]; then
    echo "scaffold.sh: destination parent does not exist: $DEST_PARENT" >&2
    exit 1
fi
DEST_PARENT="$(cd "$DEST_PARENT" && pwd)"
DEST="$DEST_PARENT/$DEST_BASE"
if [ -e "$DEST" ] && [ ! -d "$DEST" ]; then
    echo "scaffold.sh: destination exists and is not a directory: $DEST" >&2
    exit 1
fi
if [ -L "$DEST" ]; then
    echo "scaffold.sh: destination must not be a symbolic link: $DEST" >&2
    exit 1
fi
if [ -d "$DEST" ] && [ -n "$(ls -A "$DEST")" ]; then
    echo "scaffold.sh: destination is not empty: $DEST" >&2
    exit 1
fi

for asset in justfile pre-commit.sh pre-commit-config.yaml package-check.sh \
             read-distribution-metadata.py check-wheel-path.py check-archive-path.py release.sh \
             hooks-install.sh pyproject-tooling.toml workflows/ci.yml \
             workflows/tests.yml LICENSE-CC0-1.0 renovate.json5; do
    [ -f "$ASSETS/$asset" ] || { echo "scaffold.sh: missing asset $asset" >&2; exit 1; }
done
[ -f "$POLICY" ] || { echo "scaffold.sh: missing policy $POLICY" >&2; exit 1; }
if [ "$PUBLISH" = "true" ] && [ ! -f "$ASSETS/workflows/release.yml" ]; then
    echo "scaffold.sh: missing asset workflows/release.yml" >&2
    exit 1
fi
if [ "$BOOTSTRAP" = "true" ]; then
    command -v uv >/dev/null 2>&1 || { echo "scaffold.sh: --bootstrap requires uv" >&2; exit 1; }
    command -v just >/dev/null 2>&1 || { echo "scaffold.sh: --bootstrap requires just" >&2; exit 1; }
fi

python_floor="$(policy_value "$POLICY" python floor)"
python_latest="$(policy_value "$POLICY" python latest)"
ruff_target="$(policy_value "$POLICY" python ruff_target)"
mypy_target="$(policy_value "$POLICY" python mypy_target)"
coverage_floor="$(policy_value "$POLICY" python coverage_floor)"
python_matrix="$(policy_array "$POLICY" python matrix | awk 'BEGIN { printf "[" } { if (count++) printf ", "; printf "\"%s\"", $0 } END { print "]" }')"
checkout_action="$(policy_action "$POLICY" checkout)"
checkout_version="$(policy_action_version "$POLICY" checkout)"
setup_uv_action="$(policy_action "$POLICY" setup_uv)"
setup_uv_version="$(policy_action_version "$POLICY" setup_uv)"
setup_just_action="$(policy_action "$POLICY" setup_just)"
setup_just_version="$(policy_action_version "$POLICY" setup_just)"
upload_artifact_action="$(policy_action "$POLICY" upload_artifact)"
upload_artifact_version="$(policy_action_version "$POLICY" upload_artifact)"
download_artifact_action="$(policy_action "$POLICY" download_artifact)"
download_artifact_version="$(policy_action_version "$POLICY" download_artifact)"
pypi_publish_action="$(policy_action "$POLICY" pypi_publish)"
pypi_publish_version="$(policy_action_version "$POLICY" pypi_publish)"
actionlint_version="$(policy_value "$POLICY" tools.actionlint version)"
zizmor_version="$(policy_value "$POLICY" tools.zizmor version)"

mkdir -p "$DEST"
cd "$DEST"
echo "Scaffolding $REPO ($PACKAGE) in $DEST"

replace_asset() {
    local source="$1" target="$2"
    mkdir -p "$(dirname "$target")"
    sed \
        -e "s/PACKAGE/$PACKAGE/g" \
        -e "s/REPO/$REPO/g" \
        -e "s/PYTHON_FLOOR/$python_floor/g" \
        -e "s/PYTHON_LATEST/$python_latest/g" \
        -e "s/PYTHON_RUFF_TARGET/$ruff_target/g" \
        -e "s/PYTHON_MYPY_TARGET/$mypy_target/g" \
        -e "s/PYTHON_COVERAGE_FLOOR/$coverage_floor/g" \
        -e "s/PROJECT_COMMAND_NAME/$COMMAND_NAME/g" \
        -e "s/PYTHON_MATRIX/$python_matrix/g" \
        -e "s/CHECKOUT_ACTION/$checkout_action/g" \
        -e "s/CHECKOUT_VERSION/$checkout_version/g" \
        -e "s/SETUP_UV_ACTION/$setup_uv_action/g" \
        -e "s/SETUP_UV_VERSION/$setup_uv_version/g" \
        -e "s/SETUP_JUST_ACTION/$setup_just_action/g" \
        -e "s/SETUP_JUST_VERSION/$setup_just_version/g" \
        -e "s/UPLOAD_ARTIFACT_ACTION/$upload_artifact_action/g" \
        -e "s/UPLOAD_ARTIFACT_VERSION/$upload_artifact_version/g" \
        -e "s/DOWNLOAD_ARTIFACT_ACTION/$download_artifact_action/g" \
        -e "s/DOWNLOAD_ARTIFACT_VERSION/$download_artifact_version/g" \
        -e "s|PYPI_PUBLISH_ACTION|$pypi_publish_action|g" \
        -e "s|PYPI_PUBLISH_VERSION|$pypi_publish_version|g" \
        -e "s/ACTIONLINT_VERSION/$actionlint_version/g" \
        -e "s/ZIZMOR_VERSION/$zizmor_version/g" \
        "$source" > "$target"
}

mkdir -p "src/$PACKAGE" tests bin scripts .github/workflows
printf '__version__: str = "0.1.0"\n' > "src/$PACKAGE/__init__.py"
touch "src/$PACKAGE/py.typed"
if [ "$KIND" = "cli" ]; then
    cat > "tests/test_package.py" <<TEST
import sys
from unittest.mock import patch

from $PACKAGE import __version__
from $PACKAGE.cli import main


def test_version_is_available() -> None:
    assert __version__ == "0.1.0"


def test_cli_main() -> None:
    with patch.object(sys, "argv", ["$COMMAND_NAME"]):
        assert main() == 0
TEST
else
    cat > "tests/test_package.py" <<TEST
from $PACKAGE import __version__


def test_version_is_available() -> None:
    assert __version__ == "0.1.0"
TEST
fi
if [ "$KIND" = "cli" ]; then
    cat > "src/$PACKAGE/cli.py" <<'SOURCE'
from __future__ import annotations

import argparse

from . import __version__


def main() -> int:
    parser = argparse.ArgumentParser(description="Generated project command")
    parser.add_argument("--version", action="version", version=__version__)
    parser.parse_args()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
SOURCE
fi

replace_asset "$ASSETS/pre-commit.sh" bin/pre-commit.sh
replace_asset "$ASSETS/pre-commit-config.yaml" .pre-commit-config.yaml
for asset in package-check.sh read-distribution-metadata.py check-wheel-path.py check-archive-path.py \
             hooks-install.sh release.sh validate-release.sh; do
    replace_asset "$ASSETS/$asset" "scripts/$asset"
done
chmod +x bin/pre-commit.sh scripts/*.sh scripts/*.py
replace_asset "$ASSETS/justfile" justfile
replace_asset "$ASSETS/workflows/ci.yml" .github/workflows/ci.yml
replace_asset "$ASSETS/workflows/tests.yml" .github/workflows/tests.yml
replace_asset "$ASSETS/renovate.json5" .github/renovate.json5
if [ "$PUBLISH" = "true" ]; then
    replace_asset "$ASSETS/workflows/release.yml" .github/workflows/release.yml
fi

{
    cat <<TOML
[project]
name = "$REPO"
dynamic = ["version"]
description = ""
requires-python = ">=$python_floor"
readme = "README.md"
license = {file = "LICENSE.md"}
TOML
    if [ "$KIND" = "cli" ]; then
        printf '\n[project.scripts]\n%s = "%s.cli:main"\n' "$COMMAND_NAME" "$PACKAGE"
    fi
    awk '/^\[/{found=1} found{print}' "$ASSETS/pyproject-tooling.toml" |
        sed \
            -e "s/PACKAGE/$PACKAGE/g" \
            -e "s/REPO/$REPO/g" \
            -e "s/PYTHON_RUFF_TARGET/$ruff_target/g" \
            -e "s/PYTHON_MYPY_TARGET/$mypy_target/g" \
            -e "s/PYTHON_COVERAGE_FLOOR/$coverage_floor/g"
} > pyproject.toml
printf '%s\n' "$python_latest" > .python-version
cat > .gitignore <<'GITIGNORE'
__pycache__/
*.py[cod]
.pytest_cache/
.ruff_cache/
.mypy_cache/
.venv/
dist/
build/
*.egg-info/
GITIGNORE
cat <<'AGENTS' | sed "s/PYTHON_KIND/$KIND/g" > AGENTS.md
# AGENTS.md

This is a generated Python PYTHON_KIND project. Use the task runner for all checks.

## Commands

- `just lock` creates or deliberately updates `uv.lock`.
- `just sync` consumes the committed lock with `--locked`.
- `just check` runs lint, strict typing, tests, and package validation.
- `just hooks-install` installs the staged-content pre-commit hook.

Generation is offline. `--bootstrap` is the explicit dependency and hook
setup path and may contact package services.
AGENTS
printf '# %s\n' "$REPO" > README.md
cp "$ASSETS/LICENSE-CC0-1.0" LICENSE.md

git init -q
if [ "$BOOTSTRAP" = "true" ]; then
    just lock
    just sync
    just hooks-install
    echo "Bootstrap complete. Run 'just check' before the first commit."
else
    echo "Generated offline. Run 'just lock && just sync && just hooks-install' to bootstrap."
fi
