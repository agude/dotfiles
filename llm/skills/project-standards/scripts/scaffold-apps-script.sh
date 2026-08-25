#!/usr/bin/env bash
# scaffold-apps-script.sh — scaffold a Google Apps Script repository.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ASSETS="$SKILL_DIR/assets"

usage() {
    echo "Usage: bash scaffold-apps-script.sh <dest-dir> <project-name>" >&2
    echo "" >&2
    echo "  dest-dir      directory to create (must not exist, or be empty)" >&2
    echo "  project-name  human-readable Apps Script project name" >&2
    exit 1
}

[[ $# -eq 2 ]] || usage

DEST="$(realpath "$1")"
PROJECT_NAME="$2"

if [[ -z "$PROJECT_NAME" ]]; then
    echo "Error: project-name must not be empty." >&2
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

msg() { echo "  $*"; }

mkdir -p "$DEST"
cd "$DEST"

echo "Scaffolding $PROJECT_NAME in $DEST"
echo ""

msg "src/"
mkdir -p src
cat > src/appsscript.json <<'MANIFEST'
{
  "exceptionLogging": "STACKDRIVER",
  "runtimeVersion": "V8"
}
MANIFEST

cat > src/main.js <<'SOURCE'
function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu("Project")
    .addItem("Run", "runProject")
    .addToUi();
}

function runProject() {
  SpreadsheetApp.getActiveSpreadsheet().toast("Implement project behavior.");
}
SOURCE

cat > src/main_test.js <<'TEST'
function runProjectTests() {
  return "No project tests are defined yet.";
}
TEST

msg "fixtures/README.md"
mkdir -p fixtures
cat > fixtures/README.md <<'FIXTURES'
# Fixtures

Commit only anonymized input and output examples. Do not commit live Google
Form exports, customer records, generated receipts, or email addresses.
FIXTURES

msg ".gitignore"
cat > .gitignore <<'GITIGNORE'
# Apps Script credentials
.clasp.json
.clasprc.json

# Generated output
output.csv
GITIGNORE

msg "AGENTS.md (CLAUDE.md symlinked)"
cat > AGENTS.md <<'AGENTS'
# Repository Guidelines

## Project Structure

- `src/` contains Apps Script source and `appsscript.json`.
- `fixtures/` contains anonymized examples only.

## Validation

Run `runProjectTests()` in the bound Apps Script project before deploying.
This project has no local runner or CI until a real clasp workflow exists.

## Security

Do not commit Google Form exports, generated receipts, `.clasp.json`, or
`.clasprc.json`.
AGENTS
ln -sf AGENTS.md CLAUDE.md

msg "README.md"
{
    printf '# %s\n\n' "$PROJECT_NAME"
    cat <<'README'

Google Apps Script project.

## Install

1. Open the target Google Workspace file.
2. Select **Extensions → Apps Script**.
3. Copy the JavaScript files from `src/` into the bound project.
4. Save the project and run `runProjectTests()`.

## Development

Keep Apps Script source in `src/`. Keep only anonymized fixtures in
`fixtures/`. Do not add clasp, a justfile, or CI until they execute real
checks against a configured Apps Script project.
README
} > README.md

msg "LICENSE"
cp "$ASSETS/LICENSE-CC0-1.0" LICENSE

if [[ ! -d .git ]]; then
    msg "git init"
    git init -q
fi

echo ""
echo "Done. Fill in the source files, then run runProjectTests() in Apps Script."
