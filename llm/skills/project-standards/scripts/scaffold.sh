#!/usr/bin/env bash
# scaffold.sh — scaffold a new Python package repo from project-standards assets.
#
# Usage: bash scaffold.sh <dest-dir> <package-name>
#
#   dest-dir     path to create (must not exist, or be an empty directory)
#   package-name Python import name, e.g. my_package; the distribution name
#                is derived as my-package

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$SKILL_DIR/assets"

# --- Args ---
usage() {
    echo "Usage: bash scaffold.sh <dest-dir> <package-name>" >&2
    echo "" >&2
    echo "  dest-dir     directory to create (must not exist, or be empty)" >&2
    echo "  package-name Python import name, e.g. my_package" >&2
    exit 1
}

[[ $# -eq 2 ]] || usage

DEST="$(realpath "$1")"
PACKAGE="$2"
REPO="${PACKAGE//_/-}"

# Validate
if [[ ! "$PACKAGE" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    echo "Error: '$PACKAGE' is not a valid Python identifier." >&2
    exit 1
fi

if [[ -e "$DEST" ]] && [[ ! -d "$DEST" ]]; then
    echo "Error: '$DEST' exists and is not a directory." >&2
    exit 1
fi

if [[ -d "$DEST" ]] && [[ -n "$(ls -A "$DEST")" ]]; then
    echo "Error: '$DEST' exists and is not empty." >&2
    exit 1
fi

# --- Helpers ---
msg() { echo "  $*"; }

# Copy a file substituting PACKAGE and REPO placeholders
copy_sub() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    sed -e "s/PACKAGE/$PACKAGE/g" -e "s/REPO/$REPO/g" "$src" > "$dst"
}

# --- Scaffold ---
mkdir -p "$DEST"
cd "$DEST"

echo "Scaffolding $REPO ($PACKAGE) in $DEST"
echo ""

msg "src/$PACKAGE/__init__.py"
mkdir -p "src/$PACKAGE"
printf '__version__ = "0.1.0"\n' > "src/$PACKAGE/__init__.py"

msg "tests/"
mkdir -p tests
touch "tests/__init__.py"

msg "bin/pre-commit.sh"
mkdir -p bin
copy_sub "$ASSETS/pre-commit.sh" "bin/pre-commit.sh"
chmod +x "bin/pre-commit.sh"

msg ".github/workflows/{ci,tests,release}.yml"
mkdir -p .github/workflows
copy_sub "$ASSETS/workflows/ci.yml"      ".github/workflows/ci.yml"
copy_sub "$ASSETS/workflows/tests.yml"   ".github/workflows/tests.yml"
copy_sub "$ASSETS/workflows/release.yml" ".github/workflows/release.yml"

msg "justfile"
copy_sub "$ASSETS/justfile" "justfile"

msg "pyproject.toml"
{
    cat <<TOML
[project]
name = "$REPO"
dynamic = ["version"]
description = ""
requires-python = ">=3.10"
readme = "README.md"
license = {file = "LICENSE.md"}

TOML
    # Append tooling blocks, dropping the leading instruction comment
    awk '/^\[/{found=1} found{print}' "$ASSETS/pyproject-tooling.toml" \
        | sed -e "s/PACKAGE/$PACKAGE/g" -e "s/REPO/$REPO/g"
} > pyproject.toml

msg ".python-version"
echo "3.13" > .python-version

msg ".gitignore"
cat > .gitignore <<'GITIGNORE'
# Python
__pycache__/
*.py[cod]
.pytest_cache/
.ruff_cache/
.mypy_cache/
dist/
build/
*.egg-info/

# uv — .venv is local; uv.lock is committed (do not add it here)
.venv/
GITIGNORE

msg "AGENTS.md (CLAUDE.md + GEMINI.md symlinked)"
cat > AGENTS.md <<AGENTS
# AGENTS.md

Instructions for AI coding assistants working in this repo.

## Project

$REPO is a Python package that …

## Archetype

Python package (see the project-standards skill, \`references/python-package.md\`).

## Tooling

| Verb | Does |
|---|---|
| \`just lint\` | ruff check + format check (read-only) |
| \`just format\` | ruff format + fix |
| \`just type-check\` | mypy strict |
| \`just test\` | pytest with coverage |
| \`just check\` | full gate: lint + type-check + test |
| \`just hooks-install\` | install the pre-commit hook once per clone |

## Known exceptions

None.
AGENTS
ln -sf AGENTS.md CLAUDE.md
ln -sf AGENTS.md GEMINI.md

msg "README.md"
printf '# %s\n' "$REPO" > README.md

msg "LICENSE.md"
cat > LICENSE.md <<'LICENSE'
# License

This work is dedicated to the public domain under
[CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/).

To the extent possible under law, the author has waived all copyright and
related or neighboring rights to this work.
LICENSE

if [[ ! -d .git ]]; then
    msg "git init"
    git init -q
fi

echo ""
echo "Running just sync && just hooks-install …"
just sync
just hooks-install

echo ""
echo "Done. Fill in AGENTS.md and README.md, then run 'just check'."
